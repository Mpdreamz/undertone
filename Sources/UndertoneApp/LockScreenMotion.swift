import AppKit
import UndertoneCore

/// Turning lock screen motion on and off: on installs the screen saver, starts rendering each display's picture in
/// motion, and offers to open Screen Saver settings, where the user picks Undertone once.
@MainActor
enum LockScreenMotion {
    static func toggle() {
        set(!Desktop.shared.settings.lockScreenMotion)
    }

    static func set(_ on: Bool) {
        guard on != Desktop.shared.settings.lockScreenMotion else { return }
        if !on {
            Desktop.shared.update { $0.lockScreenMotion = false }
            MotionStudio.shared.stop()
            return
        }
        guard MotionStudio.installSaver() else {
            alert(
                "The screen saver could not be installed",
                "Undertone could not copy its screen saver to ~/Library/Screen Savers."
            )
            return
        }
        Desktop.shared.update { $0.lockScreenMotion = true }
        Desktop.shared.apply()
        let alert = NSAlert()
        alert.messageText = "Choose Undertone as your screen saver"
        alert.informativeText = """
        Undertone is drawing your picture in motion in the background; that takes a minute or two. In Screen Saver \
        settings, choose Undertone. When the screen saver is running and you unlock, the picture slows to a stop on \
        your desktop.
        """
        alert.addButton(withTitle: "Open Screen Saver Settings")
        alert.addButton(withTitle: "Later")
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn { MotionStudio.openScreenSaverSettings() }
    }

    private static func alert(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        NSApp.activate()
        alert.runModal()
    }
}
