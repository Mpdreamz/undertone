import Foundation

/// Which movies show each display's picture in motion: written by the app, read by the screen saver (which runs in
/// a sandbox that may read any file but write none of ours). Keyed by the display's UUID.
public struct MotionManifest: Codable, Hashable, Sendable {
    public struct Entry: Codable, Hashable, Sendable {
        /// File names in the motion folder.
        public var loop: String
        public var settle: String

        public init(loop: String, settle: String) {
            self.loop = loop
            self.settle = settle
        }
    }

    public var displays: [String: Entry]

    public init(displays: [String: Entry] = [:]) {
        self.displays = displays
    }

    /// `~/Library/Application Support/Undertone/Motion` of the user, from the real home folder: inside the screen
    /// saver's sandbox `NSHomeDirectory()` is its container instead.
    public static var folder: URL {
        let home = getpwuid(getuid()).flatMap { String(validatingCString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home).appendingPathComponent("Library/Application Support/Undertone/Motion")
    }

    public static var url: URL {
        folder.appendingPathComponent("motion.json")
    }

    public static func load() -> MotionManifest {
        (try? JSONDecoder().decode(MotionManifest.self, from: Data(contentsOf: url))) ?? MotionManifest()
    }

    public func save() throws {
        try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: Self.url, options: .atomic)
    }

    /// The display's movies, or any display's when it has none of its own (a display connected since).
    public func entry(for display: String) -> Entry? {
        displays[display] ?? displays.values.sorted { $0.loop < $1.loop }.first
    }
}
