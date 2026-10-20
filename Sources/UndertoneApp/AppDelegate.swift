import AppKit
import UndertoneCore

/// The status item and its menu: shuffle, what is picked and how, the overlays, and the app's own business.
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
        Updater.shared.start()
    }

    /// Built each time it opens, so the check marks say how things are now.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let settings = desktop.settings
        let pick = desktop.pick

        menu.addItem(.label(build.label))
        menu.addItem(.label("\(pick.style.rawValue.capitalized) in \(pick.tonality.rawValue.capitalized)"))
        menu.addItem(.separator())
        menu.addItem(.action("Shuffle", key: "s") { Desktop.shared.shuffle() })
        menu.addItem(.separator())

        menu.addItem(.submenu("Style", [
            .action("Random", on: settings.style == .random) { Desktop.shared.update { $0.style = .random } },
            .separator(),
        ] + Style.allCases.map { style in
            let item = NSMenuItem.action(style.rawValue.capitalized, on: settings.style == .locked(style)) {
                Desktop.shared.update { $0.style = .locked(style) }
            }
            item.toolTip = style.summary
            return item
        }))
        menu.addItem(.submenu("Tonality", [
            .action("Random", on: settings.tonality == .random) { Desktop.shared.update { $0.tonality = .random } },
            .separator(),
        ] + Tonality.allCases.map { tonality in
            .action(tonality.rawValue.capitalized, on: settings.tonality == .locked(tonality)) {
                Desktop.shared.update { $0.tonality = .locked(tonality) }
            }
        }))
        menu.addItem(.submenu("Spaces", [
            .action("A Picture per Space", on: settings.spaces == .different) {
                Desktop.shared.update { $0.spaces = .different }
            },
            .action("The Same Picture Everywhere", on: settings.spaces == .same) {
                Desktop.shared.update { $0.spaces = .same }
            },
        ]))
        menu.addItem(.submenu("Shuffle Automatically", ShuffleInterval.allCases.map { interval in
            .action(interval.title, on: settings.interval == interval) {
                Desktop.shared.update { $0.interval = interval }
            }
        } + [
            .separator(),
            .action("On Login and Wake", on: settings.shuffleOnWake) {
                Desktop.shared.update { $0.shuffleOnWake.toggle() }
            },
        ]))
        menu.addItem(.submenu("Grain", [("None", 0), ("Subtle", 0.035), ("Strong", 0.06)].map { title, amount in
            .action(title, on: abs(settings.grain - Float(amount)) < 0.001) {
                Desktop.shared.update { $0.grain = Float(amount) }
            }
        }))
        menu.addItem(.separator())
        menu.addItem(.action("Hide the Notch", on: settings.hideNotch) {
            Desktop.shared.update { $0.hideNotch.toggle() }
        })
        menu.addItem(.action("Round Corners", on: settings.roundCorners) {
            Desktop.shared.update { $0.roundCorners.toggle() }
        })
        menu.addItem(.action("Show Title", on: settings.showText) {
            Desktop.shared.update { $0.showText.toggle() }
        })
        menu.addItem(.action("Settings…", key: ",") { SettingsWindow.show() })
        menu.addItem(.separator())
        menu.addItem(.action("Pause (Leave the Desktop Alone)", on: settings.paused) {
            Desktop.shared.update { $0.paused.toggle() }
        })
        menu.addItem(.action("Open at Login", on: LaunchAtLogin.isEnabled) {
            LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
        })
        menu.addItem(.action("Check for Updates…") { Updater.shared.checkForUpdates() })
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Undertone",
            action: #selector(NSApplication.terminate),
            keyEquivalent: "q"
        ))
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
