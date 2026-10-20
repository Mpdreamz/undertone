import Foundation

/// The settings as a file people can keep in their dotfiles: `~/.config/undertone/config.toml` (or under
/// `$XDG_CONFIG_HOME`). Only settings go in it; what is showing now, and pause, stay in the app's own defaults, so a
/// shuffle never changes the file.
///
/// The file is a small part of TOML: `[sections]`, `key = value`, strings in double quotes, numbers, `true` and
/// `false`, and `#` comments. Anything it cannot read falls back to that setting's default and is reported as a
/// warning; the rest still applies.
public enum ConfigFile {
    /// Where the file lives for `environment` (the process's, by default) and `home`.
    public static func url(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        let base = environment["XDG_CONFIG_HOME"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
            ?? home.appendingPathComponent(".config")
        return base.appendingPathComponent("undertone/config.toml")
    }

    /// A problem in the file, by line.
    public struct Warning: Hashable, Sendable, CustomStringConvertible {
        public let line: Int
        public let message: String

        public var description: String {
            "line \(line): \(message)"
        }
    }

    // MARK: Reading

    public static func parse(_ text: String) -> (settings: Settings, warnings: [Warning]) {
        var settings = Settings()
        var warnings: [Warning] = []
        var section = ""
        for (index, raw) in text.components(separatedBy: .newlines).enumerated() {
            let number = index + 1
            let line = stripComment(raw).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("[") {
                guard line.hasSuffix("]") else {
                    warnings.append(Warning(line: number, message: "a section needs a closing ]"))
                    continue
                }
                section = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                if !keys.keys.contains(section) {
                    warnings.append(Warning(line: number, message: "no section [\(section)]"))
                }
                continue
            }
            guard let equals = line.firstIndex(of: "=") else {
                warnings.append(Warning(line: number, message: "expected key = value"))
                continue
            }
            let key = line[..<equals].trimmingCharacters(in: .whitespaces)
            let text = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            guard let value = Value(text) else {
                warnings.append(Warning(line: number, message: "\(key): cannot read \(text)"))
                continue
            }
            guard let set = keys[section]?[key] else {
                let name = section.isEmpty ? key : "\(section).\(key)"
                warnings.append(Warning(line: number, message: "no setting \(name)"))
                continue
            }
            if let problem = set(&settings, value) {
                warnings.append(Warning(line: number, message: "\(key): \(problem); using the default"))
            }
        }
        return (settings, warnings)
    }

    /// A value as written: a string, a number or a boolean.
    enum Value: Sendable {
        case string(String), number(Double), bool(Bool)

        init?(_ text: String) {
            if text == "true" { self = .bool(true) } else if text == "false" { self = .bool(false) } else if text
                .hasPrefix("\"")
            {
                guard let string = Self.unquote(text) else { return nil }
                self = .string(string)
            } else if let number = Double(text.replacingOccurrences(of: "_", with: "")) {
                self = .number(number)
            } else {
                return nil
            }
        }

        private static func unquote(_ text: String) -> String? {
            guard text.count >= 2, text.hasSuffix("\"") else { return nil }
            var out = ""
            var escaped = false
            for character in text.dropFirst().dropLast() {
                if escaped {
                    switch character {
                    case "n": out.append("\n")
                    case "t": out.append("\t")
                    case "\"", "\\": out.append(character)
                    default: return nil
                    }
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    return nil
                } else {
                    out.append(character)
                }
            }
            return escaped ? nil : out
        }
    }

    /// A `#` ends the line, unless it is inside a string.
    private static func stripComment(_ line: String) -> String {
        var inString = false, escaped = false
        for (offset, character) in line.enumerated() {
            if escaped { escaped = false; continue }
            if character == "\\", inString { escaped = true; continue }
            if character == "\"" { inString.toggle() }
            if character == "#", !inString { return String(line.prefix(offset)) }
        }
        return line
    }

    // MARK: The keys

    /// Each key's reader: it sets the setting, or says what was wrong with the value.
    private typealias Setter = @Sendable (inout Settings, Value) -> String?

    private static func choice<T: RawRepresentable & CaseIterable>(
        _ assign: @escaping @Sendable (inout Settings, Choice<T>) -> Void, allowsNone _: Bool = true
    ) -> Setter where T.RawValue == String {
        { settings, value in
            guard case let .string(name) = value else { return "expected a name in quotes" }
            if name == "random" {
                assign(&settings, .random)
            } else if let locked = T(rawValue: name) {
                assign(&settings, .locked(locked))
            } else {
                return "no \(name) (random, or \(T.allCases.map(\.rawValue).joined(separator: ", ")))"
            }
            return nil
        }
    }

    private static func name<T: Sendable>(
        _ names: [String: T],
        _ assign: @escaping @Sendable (inout Settings, T) -> Void
    ) -> Setter {
        { settings, value in
            guard case let .string(name) = value, let chosen = names[name] else {
                return "expected one of \(names.keys.sorted().joined(separator: ", "))"
            }
            assign(&settings, chosen)
            return nil
        }
    }

    private static func bool(_ assign: @escaping @Sendable (inout Settings, Bool) -> Void) -> Setter {
        { settings, value in
            guard case let .bool(on) = value else { return "expected true or false" }
            assign(&settings, on)
            return nil
        }
    }

    private static func number(
        _ range: ClosedRange<Double>, _ assign: @escaping @Sendable (inout Settings, Float) -> Void
    ) -> Setter {
        { settings, value in
            guard case let .number(number) = value else { return "expected a number" }
            guard range.contains(number) else { return "expected \(range.lowerBound) to \(range.upperBound)" }
            assign(&settings, Float(number))
            return nil
        }
    }

    private static func string(_ assign: @escaping @Sendable (inout Settings, String) -> Void) -> Setter {
        { settings, value in
            guard case let .string(text) = value else { return "expected text in quotes" }
            assign(&settings, text)
            return nil
        }
    }

    static let intervals: [String: ShuffleInterval] = [
        "never": .never,
        "hourly": .hourly,
        "3h": .threeHours,
        "daily": .daily,
    ]
    static let easings: [String: Movie.Easing] = ["glide": .glide, "ease-out": .easeOut, "spring": .spring]

    private static let keys: [String: [String: Setter]] = [
        "picture": [
            "style": choice { (s: inout Settings, c: Choice<Style>) in s.style = c },
            "tonality": choice { (s: inout Settings, c: Choice<Tonality>) in s.tonality = c },
            "effect": choice { (s: inout Settings, c: Choice<Effect>) in s.effect = c },
            "spaces": name(["same": SpacesMode.same, "different": .different]) { $0.spaces = $1 },
            "grain": number(0 ... 0.2) { $0.grain = $1 },
        ],
        "shuffle": [
            "every": name(intervals) { $0.interval = $1 },
            "on_wake": bool { $0.shuffleOnWake = $1 },
        ],
        "screen": [
            "hide_notch": bool { $0.hideNotch = $1 },
            "round_corners": bool { $0.roundCorners = $1 },
        ],
        "title": [
            "show": bool { $0.showText = $1 },
            "title": string { $0.title = $1 },
            "subtitle": string { $0.subtitle = $1 },
        ],
        "motion": [
            "lock_screen": bool { $0.lockScreenMotion = $1 },
            "speed": name(Dictionary(uniqueKeysWithValues: MotionSpeed.allCases.map { ($0.rawValue, $0) })) {
                $0.motionSpeed = $1
            },
            "movement": name(Dictionary(uniqueKeysWithValues: MotionMovement.allCases.map { ($0.rawValue, $0) })) {
                $0.motionMovement = $1
            },
            "settle": number(0.5 ... 8) { $0.settleSeconds = $1 },
            "easing": name(easings) { $0.settleEasing = $1 },
        ],
    ]

    // MARK: Writing

    /// The whole file for `settings`, every key with a line saying what it takes. Undertone writes it this way
    /// whenever a setting changes from the menu or the settings window.
    public static func render(_ settings: Settings) -> String {
        func choice<T: RawRepresentable>(_ choice: Choice<T>) -> String where T.RawValue == String {
            switch choice {
            case .random: "random"
            case let .locked(value): value.rawValue
            }
        }
        func quote(_ text: String) -> String {
            "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\t", with: "\\t") + "\""
        }
        func number(_ value: Float) -> String {
            let text = String(format: "%.3f", value)
            var trimmed = text
            while trimmed.hasSuffix("0") {
                trimmed.removeLast()
            }
            return trimmed.hasSuffix(".") ? trimmed + "0" : trimmed
        }
        let interval = intervals.first { $0.value == settings.interval }?.key ?? "never"
        let easing = easings.first { $0.value == settings.settleEasing }?.key ?? "ease-out"
        let styles = Style.allCases.map(\.rawValue).joined(separator: ", ")
        let tonalities = Tonality.allCases.map(\.rawValue).joined(separator: ", ")
        let effects = Effect.allCases.filter { $0 != .none }.map(\.rawValue).joined(separator: ", ")
        return """
        # Undertone's settings. Undertone reads this file when it changes, and writes it (in this layout, without
        # comments of your own) when you change a setting from its menu or settings window.
        # https://mpdreamz.github.io/undertone/reference/configuration/

        [picture]
        style = \(quote(choice(settings.style)))  # random, or \(styles)
        tonality = \(quote(choice(settings.tonality)))  # random, or \(tonalities)
        effect = \(quote(choice(settings.effect)))  # none, random, or \(effects)
        spaces = \(quote(settings.spaces.rawValue))  # different (a picture per space) or same
        grain = \(number(settings.grain))  # 0 for none, 0.035 subtle, 0.06 strong

        [shuffle]
        every = \(quote(interval))  # never, hourly, 3h or daily
        on_wake = \(settings.shuffleOnWake)  # a new picture on login and wake

        [screen]
        hide_notch = \(settings.hideNotch)  # a black menu bar strip on displays with a notch
        round_corners = \(settings.roundCorners)  # black corners, curved like macOS's windows

        [title]
        show = \(settings.showText)
        title = \(quote(settings.title))  # {computer}, {user}, {os} and {host} are filled in
        subtitle = \(quote(settings.subtitle))

        [motion]
        lock_screen = \(settings.lockScreenMotion)  # needs Undertone chosen as the screen saver
        speed = \(quote(settings.motionSpeed.rawValue))  # calm, normal or lively
        movement = \(quote(settings.motionMovement.rawValue))  # subtle, normal or strong
        settle = \(number(settings.settleSeconds))  # seconds the slow-down on unlock takes, 1 to 5
        easing = \(quote(easing))  # glide, ease-out or spring

        """
    }
}
