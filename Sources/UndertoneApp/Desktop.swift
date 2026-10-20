import AppKit
import os
import UndertoneCore

/// Keeps every screen's desktop picture Undertone's. Works out the picture each screen's space should show, draws it
/// once (off the main actor, into Application Support), sets it, and looks again whenever something could have
/// changed it: a space switch, waking, a display change, the appearance, the system's wallpaper store, or a slow timer.
@MainActor
final class Desktop {
    static let shared = Desktop()

    private let log = Logger(subsystem: "io.github.mpdreamz.undertone", category: "desktop")
    private(set) var settings = Preferences.settings
    private(set) var pick: Pick
    private var drawing: Set<String> = []
    private var timers: [Timer] = []
    private var watchers: [DispatchSourceFileSystemObject] = []
    private var appearanceObservation: NSKeyValueObservation?
    private var pendingCheck: DispatchWorkItem?

    /// Where the pictures go: `~/Library/Application Support/Undertone/Pictures`.
    let folder: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Undertone/Pictures")

    private init() {
        var rng = SystemRandomNumberGenerator()
        pick = Preferences.pick ?? Pick.next(after: nil, settings: Preferences.settings, rng: &rng)
        Preferences.pick = pick
    }

    var appearance: Appearance {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
    }

    func start() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.apply() }
        }
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.woke() }
        }
        workspace.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.apply() }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { self.apply() }
        }
        // `undertone shuffle`.
        DistributedNotificationCenter.default().addObserver(
            forName: .init("io.github.mpdreamz.undertone.shuffle"), object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { self.shuffle() }
        }
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { _, _ in
            Task { @MainActor in self.apply() }
        }
        MotionStudio.shared.start()
        watchWallpaperStore()
        // The backstop: whatever reset the picture without any of the above noticing is caught within half a minute.
        timers.append(Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            MainActor.assumeIsolated { self.apply() }
        })
        // Checked every minute against the last shuffle, so the interval holds across sleep and restarts.
        timers.append(Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            MainActor.assumeIsolated { self.shuffleIfDue() }
        })
        if settings.shuffleOnWake { shuffle() } else { apply() }
    }

    // MARK: Choosing

    func update(_ change: (inout Settings) -> Void) {
        var next = settings
        change(&next)
        guard next != settings else { return }
        settings = next
        Preferences.settings = next
        pick = pick.applying(next)
        Preferences.pick = pick
        apply()
    }

    func shuffle() {
        var rng = SystemRandomNumberGenerator()
        pick = Pick.next(after: pick, settings: settings, rng: &rng)
        Preferences.pick = pick
        Preferences.lastShuffle = Date()
        apply()
    }

    private func shuffleIfDue() {
        guard let every = settings.interval.seconds else { return }
        guard let last = Preferences.lastShuffle else {
            Preferences.lastShuffle = Date()
            return
        }
        if Date().timeIntervalSince(last) >= every { shuffle() }
    }

    private func woke() {
        if settings.shuffleOnWake { shuffle() } else { shuffleIfDue() }
        apply()
    }

    // MARK: Applying

    /// Every screen gets the picture for the space it shows; one already set is left alone, one not drawn yet is
    /// drawn first.
    func apply() {
        guard !settings.paused else { return }
        for screen in NSScreen.screens {
            let target = target(for: screen)
            if settings.lockScreenMotion { MotionStudio.shared.want(target, display: Spaces.displayUUID(screen)) }
            let url = folder.appendingPathComponent(target.name)
            if FileManager.default.fileExists(atPath: url.path) {
                set(url, on: screen)
            } else {
                draw(target, then: url)
            }
        }
    }

    struct Target: Sendable {
        let recipe: Recipe
        let overlay: Overlay
        let width: Int
        let height: Int
        let space: String

        var name: String {
            Fingerprint.of(recipe, overlay, width: width, height: height) + ".png"
        }
    }

    private func target(for screen: NSScreen) -> Target {
        let scale = Float(screen.backingScaleFactor)
        let width = Int((screen.frame.width * screen.backingScaleFactor).rounded())
        let height = Int((screen.frame.height * screen.backingScaleFactor).rounded())
        let space = Spaces.current(on: screen)
        var overlay = Overlay(scale: scale)
        let notch = screen.safeAreaInsets.top
        if settings.hideNotch, notch > 0 { overlay.strip = Int((notch * screen.backingScaleFactor).rounded()) }
        if settings.roundCorners { overlay.cornerRadius = Int((Overlay.windowCorner * scale).rounded()) }
        if settings.showText {
            overlay.title = Placeholders.expand(settings.title, Self.placeholders)
            overlay.subtitle = Placeholders.expand(settings.subtitle, Self.placeholders)
        }
        let recipe = pick.recipe(space: space, settings: settings, appearance: appearance)
        return Target(recipe: recipe, overlay: overlay, width: width, height: height, space: space)
    }

    private func draw(_ target: Target, then url: URL) {
        guard drawing.insert(target.name).inserted else { return }
        let appearance = target.recipe.appearance
        Task.detached(priority: .utility) {
            let picture = Renderer.render(
                target.recipe, width: target.width, height: target.height, scale: target.overlay.scale
            )
            let data = Composer.compose(picture, target.overlay, appearance: appearance).flatMap(Composer.png)
            let written = (try? data?.write(to: url, options: .atomic)) != nil
            await MainActor.run {
                self.drawing.remove(target.name)
                if written { self.apply() } else { self.log.error("could not write \(url.path, privacy: .public)") }
                self.prune()
            }
        }
    }

    private func set(_ url: URL, on screen: NSScreen) {
        let workspace = NSWorkspace.shared
        guard workspace.desktopImageURL(for: screen)?.standardizedFileURL != url.standardizedFileURL else { return }
        do {
            try workspace.setDesktopImageURL(url, for: screen, options: [
                .imageScaling: NSImageScaling.scaleAxesIndependently.rawValue,
                .allowClipping: true,
                .fillColor: NSColor.black,
            ])
            log.info("set \(url.lastPathComponent, privacy: .public) on \(screen.localizedName, privacy: .public)")
        } catch {
            log.error("could not set the picture: \(String(describing: error), privacy: .public)")
        }
    }

    /// Pictures not set anywhere for two days go; a space not visited since keeps its picture until then.
    private func prune() {
        let inUse = Set(NSScreen.screens.compactMap { NSWorkspace.shared.desktopImageURL(for: $0)?.lastPathComponent })
        let old = Date().addingTimeInterval(-2 * 24 * 3600)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        for file in files where !inUse.contains(file.lastPathComponent) {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < old { try? FileManager.default.removeItem(at: file) }
        }
    }

    /// The system's own record of the desktop pictures: a write there is likely a reset, so look again shortly after.
    private func watchWallpaperStore() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.apple.wallpaper")
        for folder in [base, base.appendingPathComponent("Store")] {
            let fd = open(folder.path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main
            )
            source.setEventHandler { MainActor.assumeIsolated { self.checkSoon() } }
            source.setCancelHandler { close(fd) }
            source.resume()
            watchers.append(source)
        }
    }

    /// Our own change writes the store too; waiting a moment lets it settle, and the check finds ours in place.
    private func checkSoon() {
        pendingCheck?.cancel()
        let work = DispatchWorkItem { MainActor.assumeIsolated { self.apply() } }
        pendingCheck = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    static let placeholders: [String: String] = {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return [
            "computer": Host.current().localizedName ?? ProcessInfo.processInfo.hostName,
            "user": NSFullUserName().isEmpty ? NSUserName() : NSFullUserName(),
            "os": "\(version.majorVersion).\(version.minorVersion)",
            "host": ProcessInfo.processInfo.hostName,
        ]
    }()
}
