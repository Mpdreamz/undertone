import AVFoundation
import ScreenSaver
import UndertoneCore

/// Undertone's screen saver: this display's picture in motion, the loop Undertone.app rendered for it. It runs in
/// macOS's screen saver host, whose sandbox lets it read the movies but nothing else of ours; with no movie yet it
/// shows black and a line saying where to turn motion on.
@objc(UndertoneSaverView)
final class UndertoneSaverView: ScreenSaverView {
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private let playerLayer = AVPlayerLayer()
    private var hint: CATextLayer?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.black.cgColor
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.addSublayer(playerLayer)
        animationTimeInterval = 1
        // macOS 14 and later do not always stop a legacy screen saver; this notification still comes.
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(willStop), name: .init("com.apple.screensaver.willstop"), object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not from a nib")
    }

    override func startAnimation() {
        super.startAnimation()
        guard player == nil else {
            player?.play()
            return
        }
        let display = window?.screen.flatMap(Self.displayUUID) ?? ""
        guard let entry = MotionManifest.load().entry(for: display) else {
            showHint()
            return
        }
        let url = MotionManifest.folder.appendingPathComponent(entry.loop)
        guard FileManager.default.fileExists(atPath: url.path) else {
            showHint()
            return
        }
        let player = AVQueuePlayer()
        player.isMuted = true
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        playerLayer.player = player
        self.player = player
        player.play()
    }

    override func stopAnimation() {
        super.stopAnimation()
        player?.pause()
    }

    @objc private func willStop() {
        player?.pause()
    }

    override func animateOneFrame() {}

    private func showHint() {
        guard hint == nil else { return }
        let text = CATextLayer()
        text.string = "Turn on Lock Screen Motion in Undertone's menu."
        text.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        text.fontSize = isPreview ? 9 : 15
        text.foregroundColor = NSColor(white: 1, alpha: 0.55).cgColor
        text.alignmentMode = .center
        text.contentsScale = window?.backingScaleFactor ?? 2
        text.frame = CGRect(x: 0, y: bounds.midY - 12, width: bounds.width, height: 24)
        layer?.addSublayer(text)
        hint = text
    }

    private static func displayUUID(_ screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
