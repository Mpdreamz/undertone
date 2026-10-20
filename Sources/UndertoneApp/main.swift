import AppKit

// UNDERTONE_SHOTS=<folder>: draw the docs' app images there and quit, without touching the desktop or the settings.
if let folder = ProcessInfo.processInfo.environment["UNDERTONE_SHOTS"] {
    _ = NSApplication.shared
    MainActor.assumeIsolated { Shots.run(into: URL(fileURLWithPath: folder)) }
    exit(0)
}

// One Undertone at a time; a second one leaves before it touches the desktop picture.
guard SingleInstance.acquire() else {
    FileHandle.standardError.write(Data("Undertone is already running.\n".utf8))
    exit(0)
}

// Whether this is a new install, before Undertone writes anything of its own.
_ = MainActor.assumeIsolated { LaunchAtLogin.isFirstRun }

// A menu bar app (LSUIElement): no Dock icon and no windows of its own, only the status item.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
