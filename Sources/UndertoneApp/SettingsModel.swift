import AppKit
import Observation
import UndertoneCore

/// What the settings window shows and edits: the settings and the pick, kept in step with the desktop both ways. A
/// change in the window applies at once (and writes the config file); a change from anywhere else (the menu, the
/// file, a shuffle) shows in the window.
@MainActor
@Observable
final class SettingsModel {
    static let shared = SettingsModel(settings: Desktop.shared.settings, pick: Desktop.shared.pick, live: true)

    var settings: Settings {
        didSet {
            guard live, !syncing, settings != oldValue else { return }
            push(from: oldValue)
        }
    }

    private(set) var pick: Pick
    let appearance: Appearance
    private let live: Bool
    @ObservationIgnored private var syncing = false

    /// `live` false: a model of its own, for drawing the window in the docs, that changes nothing.
    init(settings: Settings, pick: Pick, live: Bool, appearance: Appearance? = nil) {
        self.settings = settings
        self.pick = pick
        self.live = live
        self.appearance = appearance ?? (live ? Desktop.shared.appearance : .dark)
    }

    /// The desktop changed: show it.
    func sync() {
        guard live else { return }
        syncing = true
        settings = Desktop.shared.settings
        pick = Desktop.shared.pick
        syncing = false
    }

    private func push(from old: Settings) {
        let next = settings
        if next.lockScreenMotion != old.lockScreenMotion {
            // Turning it on installs the screen saver and asks to choose it; that flow sets the setting itself.
            LockScreenMotion.set(next.lockScreenMotion)
        }
        Desktop.shared.update { current in
            let motion = current.lockScreenMotion
            current = next
            current.lockScreenMotion = motion
            current.paused = Desktop.shared.settings.paused
        }
        sync()
    }

    func shuffle() {
        guard live else { return }
        Desktop.shared.shuffle()
        sync()
    }

    /// The picture showing now, under the window's settings, for one space.
    func recipe(effects: Effects? = nil) -> Recipe {
        var recipe = pick.applying(settings).recipe(space: "preview", settings: settings, appearance: appearance)
        if let effects { recipe.effects = effects }
        return recipe
    }
}

/// Small renders for the settings window, cached: the same recipe at the same size is drawn once.
final class Thumbnails: @unchecked Sendable {
    static let shared = Thumbnails()

    struct Key: Hashable, Sendable {
        let recipe: Recipe
        /// In points; drawn at twice that.
        let width: Int
        let height: Int
        var overlay = Overlay()
    }

    /// For drawing the window in the docs, offscreen: every picture is drawn as the view is made, not later.
    nonisolated(unsafe) static var drawImmediately = false

    private var cache: [Key: CGImage] = [:]
    private let lock = NSLock()

    func cached(_ key: Key) -> CGImage? {
        lock.withLock { cache[key] }
    }

    /// Draws it (on the calling thread) unless it is cached.
    func image(_ key: Key) -> CGImage? {
        if let image = cached(key) { return image }
        let picture = Renderer.render(key.recipe, width: key.width * 2, height: key.height * 2, scale: 2)
        guard let image = Composer.compose(picture, key.overlay, appearance: key.recipe.appearance) else { return nil }
        lock.withLock {
            if cache.count > 400 { cache.removeAll() }
            cache[key] = image
        }
        return image
    }
}
