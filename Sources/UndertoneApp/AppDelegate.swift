import AppKit
import UndertoneCore

/// The status item and its menu: what is showing, Shuffle and Pause, the two screen toggles, and the way to Settings.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let build = BuildInfo(info: Bundle.main.infoDictionary ?? [:])
    private let desktop = Desktop.shared

    func applicationDidFinishLaunching(_: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: "Undertone")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        desktop.start()
        // A new version of the app brings a new screen saver.
        if desktop.settings.lockScreenMotion { MotionStudio.installSaver() }
        Updater.shared.start()
    }

    /// Built each time it opens, so the check marks say how things are now. Quick toggles and commands only;
    /// everything else is in Settings.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let settings = desktop.settings
        let recipe = desktop.pick.recipe(space: "menu", settings: settings, appearance: desktop.appearance)

        let extras = Effect.selectable.filter(recipe.effects.isOn).map(\.title)
        menu.addItem(.label(
            "\(recipe.style.rawValue.capitalized) in \(recipe.tonality.rawValue.capitalized)"
                + (extras.isEmpty ? "" : ", \(extras.joined(separator: ", "))")
        ))
        menu.addItem(.separator())
        menu.addItem(.action("Shuffle", key: "s") { Desktop.shared.shuffle() })
        menu.addItem(.action("Pause", on: settings.paused) { Desktop.shared.update { $0.paused.toggle() } })
        menu.addItem(.separator())
        menu.addItem(.action("Hide the Notch", on: settings.hideNotch) {
            Desktop.shared.update { $0.hideNotch.toggle() }
        })
        menu.addItem(.action("Round Corners", on: settings.roundCorners) {
            Desktop.shared.update { $0.roundCorners.toggle() }
        })
        menu.addItem(.separator())
        menu.addItem(.action("Settings…", key: ",") { SettingsWindow.show() })
        menu.addItem(.action("Open Config File") { AppDelegate.openConfigFile() })
        if let first = Preferences.warnings.first {
            let more = Preferences.warnings.count > 1 ? " (and \(Preferences.warnings.count - 1) more)" : ""
            let item = NSMenuItem.label("config.toml \(first)\(more)")
            item.toolTip = Preferences.warnings.map(\.description).joined(separator: "\n")
            menu.addItem(item)
        }
        menu.addItem(.action("Check for Updates…") { Updater.shared.checkForUpdates() })
        menu.addItem(.separator())
        menu.addItem(.label(build.label))
        menu.addItem(NSMenuItem(
            title: "Quit Undertone",
            action: #selector(NSApplication.terminate),
            keyEquivalent: "q"
        ))
    }
}

extension AppDelegate {
    /// Opens the config file in the editor for .toml files (or TextEdit), or shows it in Finder, writing it first
    /// when there is none.
    static func openConfigFile(reveal: Bool = false) {
        if !FileManager.default.fileExists(atPath: Preferences.resolvedConfigURL.path) {
            Preferences.settings = Desktop.shared.settings
        }
        let url = Preferences.resolvedConfigURL
        if reveal {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }
        if NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(
                [url], withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"),
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }
}

/// A menu item that runs a closure.
@MainActor
private final class ClosureItem: NSMenuItem {
    private let run: @MainActor () -> Void

    init(_ title: String, key: String, run: @escaping @MainActor () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(runClosure), keyEquivalent: key)
        target = self
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("not from a nib")
    }

    @MainActor @objc private func runClosure() {
        run()
    }
}

extension NSMenuItem {
    @MainActor static func action(
        _ title: String, key: String = "", on: Bool = false, run: @escaping @MainActor () -> Void
    ) -> NSMenuItem {
        let item = ClosureItem(title, key: key, run: run)
        item.state = on ? .on : .off
        return item
    }

    @MainActor static func label(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @MainActor static func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)
        items.forEach(menu.addItem)
        item.submenu = menu
        return item
    }
}
