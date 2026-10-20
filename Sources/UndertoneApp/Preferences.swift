import Foundation
import UndertoneCore

/// The settings and the current pick, as JSON in the app's defaults.
@MainActor
enum Preferences {
    private static let defaults = UserDefaults.standard

    static var settings: Settings {
        get { load("settings") ?? Settings() }
        set { save(newValue, "settings") }
    }

    static var pick: Pick? {
        get { load("pick") }
        set { save(newValue, "pick") }
    }

    /// When the last shuffle was, so "every day" counts across restarts.
    static var lastShuffle: Date? {
        get { defaults.object(forKey: "lastShuffle") as? Date }
        set { defaults.set(newValue, forKey: "lastShuffle") }
    }

    private static func load<T: Decodable>(_ key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    private static func save(_ value: (some Encodable)?, _ key: String) {
        guard let value, let data = try? JSONEncoder().encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}
