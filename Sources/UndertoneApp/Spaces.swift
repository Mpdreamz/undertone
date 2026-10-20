import AppKit

/// Which space each screen shows, through the window server's private `SLSCopyManagedDisplaySpaces` (what yabai and
/// SpaceId read). Looked up at run time: on a macOS without it every space of a screen counts as one, which only
/// loses "a different picture per space".
@MainActor
enum Spaces {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias CopyManagedDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?

    private static let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    private static func symbol<T>(_ name: String, as _: T.Type) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    /// A key for the space on `screen` now: the space's uuid, which outlives a restart (its numeric id does not).
    static func current(on screen: NSScreen) -> String {
        let display = displayUUID(screen)
        guard let connection = symbol("SLSMainConnectionID", as: MainConnection.self)?(),
              let copy = symbol("SLSCopyManagedDisplaySpaces", as: CopyManagedDisplaySpaces.self),
              let displays = copy(connection)?.takeRetainedValue() as? [[String: Any]]
        else { return "display-\(display)" }
        // "Displays have separate Spaces" off: one entry, called Main, for every screen.
        let entry = displays.first { ($0["Display Identifier"] as? String) == display }
            ?? displays.first { ($0["Display Identifier"] as? String) == "Main" }
        guard let space = entry?["Current Space"] as? [String: Any] else { return "display-\(display)" }
        if let uuid = space["uuid"] as? String, !uuid.isEmpty { return uuid }
        if let id = space["ManagedSpaceID"] as? Int { return "space-\(id)" }
        return "display-\(display)"
    }

    static func displayUUID(_ screen: NSScreen) -> String {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue()
        else { return screen.localizedName }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
