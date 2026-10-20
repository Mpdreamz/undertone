import Foundation
import os
import UndertoneCore

/// Where the settings and the state live. Settings go in the config file (`ConfigFile`), which people can keep in
/// their dotfiles; what is showing now, the last shuffle and pause stay in the app's defaults, so neither a shuffle
/// nor a pause changes the file.
@MainActor
enum Preferences {
    private static let defaults = UserDefaults.standard
    private static let log = Logger(subsystem: "io.github.mpdreamz.undertone", category: "config")

    /// What the file said when it was last read or written, so a change we made ourselves is not read back as news.
    private(set) static var lastText: String?
    /// What was wrong with the file when it was last read.
    private(set) static var warnings: [ConfigFile.Warning] = []

    static var configURL: URL {
        ConfigFile.url()
    }

    /// The file's own path, through a symlink (a dotfiles manager may link it): written there, the link stays.
    static var resolvedConfigURL: URL {
        configURL.resolvingSymlinksInPath()
    }

    static var settings: Settings {
        get {
            var settings = readFile() ?? migrated() ?? Settings()
            settings.paused = defaults.bool(forKey: "paused")
            return settings
        }
        set {
            defaults.set(newValue.paused, forKey: "paused")
            write(newValue)
        }
    }

    /// The file's settings, or nil when there is no file.
    static func readFile() -> Settings? {
        guard let text = try? String(contentsOf: resolvedConfigURL, encoding: .utf8) else { return nil }
        lastText = text
        let (settings, warnings) = ConfigFile.parse(text)
        self.warnings = warnings
        for warning in warnings {
            log.warning("\(configURL.path, privacy: .public) \(warning.description, privacy: .public)")
        }
        return settings
    }

    /// Settings kept in the defaults before the config file: moved into the file once.
    private static func migrated() -> Settings? {
        guard let data = defaults.data(forKey: "settings"),
              let settings = try? JSONDecoder().decode(Settings.self, from: data)
        else { return nil }
        write(settings)
        defaults.set(settings.paused, forKey: "paused")
        defaults.removeObject(forKey: "settings")
        log.info("moved the settings into \(configURL.path, privacy: .public)")
        return settings
    }

    private static func write(_ settings: Settings) {
        let text = ConfigFile.render(settings)
        guard text != lastText else { return }
        let url = resolvedConfigURL
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try text.write(to: url, atomically: true, encoding: .utf8)
            lastText = text
            warnings = []
        } catch {
            log.error("could not write \(url.path, privacy: .public): \(String(describing: error), privacy: .public)")
        }
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

    /// Watches the file: an edit, a `chezmoi apply` or a `git pull` reaches `changed` within a second. Polled, so
    /// it works whether the file is edited in place, replaced, linked, or appears for the first time.
    static func watch(_ changed: @escaping @MainActor (Settings) -> Void) -> Timer {
        var seen = fingerprint()
        return Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated {
                let now = fingerprint()
                guard now != seen else { return }
                seen = now
                guard let text = try? String(contentsOf: resolvedConfigURL, encoding: .utf8), text != lastText,
                      var settings = readFile()
                else { return }
                settings.paused = defaults.bool(forKey: "paused")
                log.info("read \(configURL.path, privacy: .public)")
                changed(settings)
            }
        }
    }

    private static func fingerprint() -> [String] {
        let url = resolvedConfigURL
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return [
            url.path,
            (attributes?[.modificationDate] as? Date).map { "\($0.timeIntervalSince1970)" } ?? "-",
            (attributes?[.size] as? NSNumber).map { "\($0)" } ?? "-",
            (attributes?[.systemFileNumber] as? NSNumber).map { "\($0)" } ?? "-",
        ]
    }
}
