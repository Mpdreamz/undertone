import AppKit

// One Undertone at a time; a second one leaves before it touches the desktop picture.
guard SingleInstance.acquire() else {
    FileHandle.standardError.write(Data("Undertone is already running.\n".utf8))
    exit(0)
}

// A menu bar app (LSUIElement): no Dock icon and no windows of its own, only the status item.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
