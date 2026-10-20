import AppKit
import AVFoundation
import os
import UndertoneCore

/// The pictures in motion, for the lock screen. For each display's current picture it renders, in the background
/// and one at a time, a seamless loop that Undertone's screen saver plays, and a settle that slows it onto the still
/// picture, which plays over the desktop for a moment when the Mac is unlocked from that screen saver.
@MainActor
final class MotionStudio {
    static let shared = MotionStudio()

    private let log = Logger(subsystem: "io.github.mpdreamz.undertone", category: "motion")
    /// What each display should have, newest wins.
    private var wanted: [String: (target: Desktop.Target, timing: Timing)] = [:]

    /// Speed, movement and settle, from the settings; part of each movie's name, so a change draws new ones.
    struct Timing: Hashable, Sendable {
        var loopSeconds: Double
        var movement: Float
        var settleSeconds: Double
        var easing: Movie.Easing

        init(_ settings: Settings) {
            loopSeconds = settings.motionSpeed.seconds
            movement = settings.motionMovement.amount
            settleSeconds = Double(min(max(settings.settleSeconds, 0.5), 8))
            easing = settings.settleEasing
        }

        var loopKey: String {
            "\(Int(loopSeconds))s-\(Int(movement * 100))"
        }

        var settleKey: String {
            "\(loopKey)-\(Int(settleSeconds * 10))-\(easing.rawValue)"
        }
    }

    private var rendering: Task<Void, Never>?
    private var pending: DispatchWorkItem?
    private var screenSaverRan = false
    private var settleWindows: [NSWindow] = []

    nonisolated static let fps = 24
    /// A quarter of the cores, at least two: a few minutes in the background rather than a minute at full tilt.
    nonisolated static let threads = max(ProcessInfo.processInfo.activeProcessorCount / 4, 2)

    func start() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: .init("com.apple.screensaver.didstart"), object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.screenSaverRan = true }
        }
        center.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.unlocked() }
        }
    }

    // MARK: Rendering

    /// The movies `target` needs on `display`. Rendering waits for things to settle (a burst of space switches asks
    /// for many pictures), then works through what is still wanted.
    func want(_ target: Desktop.Target, display: String) {
        wanted[display] = (target, Timing(Desktop.shared.settings))
        pending?.cancel()
        let work = DispatchWorkItem { MainActor.assumeIsolated { self.renderWanted() } }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
    }

    private func renderWanted() {
        guard rendering == nil else { return }
        let jobs = wanted
        wanted = [:]
        rendering = Task.detached(priority: .utility) { [log] in
            var manifest = MotionManifest.load()
            for (display, job) in jobs.sorted(by: { $0.key < $1.key }) {
                do {
                    let entry = try Self.render(job.target, timing: job.timing)
                    manifest.displays[display] = entry
                    try manifest.save()
                    log.info("motion ready for \(display, privacy: .public): \(entry.loop, privacy: .public)")
                } catch {
                    log.error("motion failed: \(String(describing: error), privacy: .public)")
                }
            }
            Self.prune(keeping: manifest)
            await MainActor.run {
                self.rendering = nil
                if !self.wanted.isEmpty { self.renderWanted() }
            }
        }
    }

    /// Renders at the display's size in points: motion hides the difference, and it is a quarter of the work.
    private nonisolated static func render(
        _ target: Desktop.Target, timing: Timing
    ) throws -> MotionManifest.Entry {
        let scale = max(target.overlay.scale, 1)
        let width = Int((Float(target.width) / scale).rounded()) & ~1
        let height = Int((Float(target.height) / scale).rounded()) & ~1
        var overlay = target.overlay
        overlay.strip = Int((Float(overlay.strip) / scale).rounded())
        overlay.cornerRadius = Int((Float(overlay.cornerRadius) / scale).rounded())
        overlay.scale = 1
        let name = Fingerprint.of(target.recipe, overlay, width: width, height: height)
        let entry = MotionManifest.Entry(
            loop: "\(name)-\(timing.loopKey)-loop.mov", settle: "\(name)-\(timing.settleKey)-settle.mov"
        )
        let folder = MotionManifest.folder
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (file, motions) in [
            (entry.loop, Movie.loop(seconds: timing.loopSeconds, fps: fps, movement: timing.movement)),
            (entry.settle, Movie.settle(
                from: 0, loopSeconds: timing.loopSeconds, seconds: timing.settleSeconds, fps: fps,
                movement: timing.movement, easing: timing.easing
            )),
        ] {
            let url = folder.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: url.path) { continue }
            // Written under another name and moved, so the screen saver never opens half a movie.
            let partial = folder.appendingPathComponent(".\(file).partial.mov")
            try Movie.write(
                target.recipe, width: width, height: height, scale: 1, overlay: overlay, motions: motions, fps: fps,
                threads: threads, to: partial, cancelled: { Task.isCancelled }
            )
            try? FileManager.default.removeItem(at: url)
            try FileManager.default.moveItem(at: partial, to: url)
        }
        return entry
    }

    /// Movies no display uses and that have not been used for two days go.
    private nonisolated static func prune(keeping manifest: MotionManifest) {
        let keep = Set(manifest.displays.values.flatMap { [$0.loop, $0.settle] } + ["motion.json"])
        let old = Date().addingTimeInterval(-2 * 24 * 3600)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: MotionManifest.folder, includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        for file in files where !keep.contains(file.lastPathComponent) {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < old { try? FileManager.default.removeItem(at: file) }
        }
    }

    func stop() {
        rendering?.cancel()
        rendering = nil
        wanted = [:]
        pending?.cancel()
    }

    // MARK: Unlocking

    /// Unlocked from the screen saver: the picture keeps moving over the desktop a moment longer, slows, and stops
    /// on the still picture underneath, then the movie fades away.
    private func unlocked() {
        defer { screenSaverRan = false }
        guard screenSaverRan, Desktop.shared.settings.lockScreenMotion, !Desktop.shared.settings.paused else { return }
        let manifest = MotionManifest.load()
        for screen in NSScreen.screens {
            guard let entry = manifest.displays[Spaces.displayUUID(screen)] else { continue }
            let url = MotionManifest.folder.appendingPathComponent(entry.settle)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            settle(url, on: screen)
        }
    }

    private func settle(_ url: URL, on screen: NSScreen) {
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        // Just above the desktop picture, below the icons and every window.
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isOpaque = true
        window.backgroundColor = .black
        let player = AVPlayer(url: url)
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        view.layer = layer
        window.contentView = view
        window.setFrame(screen.frame, display: true)
        window.orderFront(nil)
        settleWindows.append(window)
        player.play()
        NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: player.currentItem, queue: .main
        ) { [weak window] _ in
            MainActor.assumeIsolated {
                guard let window else { return }
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.4
                    window.animator().alphaValue = 0
                } completionHandler: {
                    MainActor.assumeIsolated {
                        window.orderOut(nil)
                        self.settleWindows.removeAll { $0 === window }
                    }
                }
            }
        }
    }

    // MARK: The screen saver

    /// `~/Library/Screen Savers/Undertone.saver`, copied from the app so it updates with it.
    static var installedSaver: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Screen Savers/Undertone.saver")
    }

    static var bundledSaver: URL? {
        Bundle.main.url(forResource: "Undertone", withExtension: "saver")
    }

    /// Puts this version's screen saver in place, if the app carries one and the installed one differs.
    @discardableResult
    static func installSaver() -> Bool {
        guard let bundled = bundledSaver else { return false }
        let installed = installedSaver
        let version = { (url: URL) in Bundle(url: url)?.infoDictionary?["CFBundleVersion"] as? String }
        if version(installed) == version(bundled),
           FileManager.default.fileExists(atPath: installed.path) { return true }
        do {
            try FileManager.default.createDirectory(
                at: installed.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try? FileManager.default.removeItem(at: installed)
            try FileManager.default.copyItem(at: bundled, to: installed)
            return true
        } catch {
            return false
        }
    }

    static func openScreenSaverSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
