import AppKit
import UndertoneCore

/// The status item and its menu. For now: which build this is, updates, launch at login and quit.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let build = BuildInfo(info: Bundle.main.infoDictionary ?? [:])

    func applicationDidFinishLaunching(_: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: "Undertone")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        Updater.shared.start()
    }

    /// Built each time it opens, so the check marks say how things are now.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let label = NSMenuItem(title: build.label, action: nil, keyEquivalent: "")
        label.isEnabled = false
        menu.addItem(label)
        menu.addItem(.separator())

        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(login)
        let updates = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Undertone",
            action: #selector(NSApplication.terminate),
            keyEquivalent: "q"
        ))
    }

    @objc private func toggleLogin() {
        LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
    }

    @objc private func checkForUpdates() {
        Updater.shared.checkForUpdates()
    }
}
