import Foundation

/// The settings as a file people can keep in their dotfiles: `~/.config/undertone/config.toml` (or under
/// `$XDG_CONFIG_HOME`). Only settings go in it; what is showing now, and pause, stay in the app's own defaults, so a
/// shuffle never changes the file.
///
/// The file is a small part of TOML: `[sections]` (dotted for an effect's own: `[effects.grain]`), `key = value`,
/// strings in double quotes, numbers, `true` and `false`, lists of strings in square brackets, and `#` comments.
/// Anything it cannot read falls back to that setting's default and is reported as a warning; the rest still applies.
/// A file written by Undertone 0.4 (its `[picture]` section) is read too, and should be written again in today's
/// layout (`ParseResult.isOldLayout`).
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

    public struct ParseResult: Sendable {
        public var settings: Settings
        public var warnings: [Warning]
        /// Written by Undertone 0.4: worth writing again in today's layout.
        public var isOldLayout: Bool
    }

    // MARK: Reading

    public static func parse(_ text: String) -> ParseResult {
        var settings = Settings()
        var warnings: [Warning] = []
        var legacy = LegacySettings()
        var isOldLayout = false
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
                if section == "picture" {
                    isOldLayout = true
                } else if !keys.keys.contains(section) {
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
            if section == "picture" {
                if let problem = readOld(key, value, into: &legacy) {
                    warnings.append(Warning(line: number, message: "\(key): \(problem)"))
                }
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
        if isOldLayout {
            // 0.4's [picture] held what is now [style], [tonality], [effects] and the spaces.
            let old = legacy.settings
            settings.style = old.style
            settings.tonality = old.tonality
            settings.effects = old.effects
            settings.randomEffect = old.randomEffect
            settings.spaces = legacy.spaces ?? settings.spaces
        }
        return ParseResult(settings: settings, warnings: warnings, isOldLayout: isOldLayout)
    }

    /// A value as written: a string, a number, a boolean, or a list of strings.
    enum Value: Sendable {
        case string(String), number(Double), bool(Bool), list([String])

        init?(_ text: String) {
            if text == "true" {
                self = .bool(true)
            } else if text == "false" {
                self = .bool(false)
            } else if text.hasPrefix("\"") {
                guard let string = Self.unquote(text) else { return nil }
                self = .string(string)
            } else if text.hasPrefix("[") {
                guard text.hasSuffix("]") else { return nil }
                let inside = text.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
                var items: [String] = []
                for part in Self.splitList(inside) {
                    let part = part.trimmingCharacters(in: .whitespaces)
                    if part.isEmpty { continue } // an empty list, or a trailing comma
                    guard let item = Self.unquote(part) else { return nil }
                    items.append(item)
                }
                self = .list(items)
            } else if let number = Double(text.replacingOccurrences(of: "_", with: "")) {
                self = .number(number)
            } else {
                return nil
            }
        }

        /// Commas outside quotes.
        private static func splitList(_ text: String) -> [String] {
            var parts: [String] = [], current = "", inString = false, escaped = false
            for character in text {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString.toggle()
                } else if character == ",", !inString {
                    parts.append(current)
                    current = ""
                    continue
                }
                current.append(character)
            }
            parts.append(current)
            return parts
        }

        static func unquote(_ text: String) -> String? {
            guard text.count >= 2, text.hasPrefix("\""), text.hasSuffix("\"") else { return nil }
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
            if escaped {
                escaped = false
                continue
            }
            if character == "\\", inString {
                escaped = true
                continue
            }
            if character == "\"" { inString.toggle() }
            if character == "#", !inString { return String(line.prefix(offset)) }
        }
        return line
    }

    // MARK: The keys

    /// Each key's reader: it sets the setting, or says what was wrong with the value.
    private typealias Setter = @Sendable (inout Settings, Value) -> String?

    private static func named<T: RawRepresentable & CaseIterable & Sendable>(
        _ assign: @escaping @Sendable (inout Settings, T) -> Void
    ) -> Setter where T.RawValue == String {
        { settings, value in
            guard case let .string(name) = value, let chosen = T(rawValue: name) else {
                return "expected one of \(T.allCases.map(\.rawValue).joined(separator: ", "))"
            }
            assign(&settings, chosen)
            return nil
        }
    }

    private static func names<T: RawRepresentable & CaseIterable & Hashable & Sendable>(
        _ assign: @escaping @Sendable (inout Settings, Set<T>) -> Void
    ) -> Setter where T.RawValue == String {
        { settings, value in
            guard case let .list(items) = value else { return "expected a list, like [\"a\", \"b\"]" }
            let unknown = items.filter { T(rawValue: $0) == nil }
            guard unknown.isEmpty else {
                return "no \(unknown.joined(separator: ", ")) (\(T.allCases.map(\.rawValue).joined(separator: ", ")))"
            }
            assign(&settings, Set(items.compactMap(T.init(rawValue:))))
            return nil
        }
    }

    private static func name<T: Sendable>(
        _ names: [String: T], _ assign: @escaping @Sendable (inout Settings, T) -> Void
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

    private static func whole(
        _ range: ClosedRange<Int>, _ assign: @escaping @Sendable (inout Settings, Int) -> Void
    ) -> Setter {
        { settings, value in
            guard case let .number(number) = value, number == number.rounded() else {
                return "expected a whole number"
            }
            guard range.contains(Int(number)) else { return "expected \(range.lowerBound) to \(range.upperBound)" }
            assign(&settings, Int(number))
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

    /// `on = true | false` for an effect: on keeps its settings (or takes its defaults), off drops them. `on` comes
    /// first in each section, so the settings after it land on an effect that exists.
    private static func toggle(_ effect: Effect) -> Setter {
        bool { $0.effects.set(effect, on: $1) }
    }

    static let intervals: [String: ShuffleInterval] = [
        "never": .never, "hourly": .hourly, "3h": .threeHours, "daily": .daily,
    ]
    static let easings: [String: Movie.Easing] = ["glide": .glide, "ease-out": .easeOut, "spring": .spring]

    private static let keys: [String: [String: Setter]] = [
        "style": [
            "mode": name(["shuffle": Selection<Style>.Mode.shuffle, "always": .always]) { $0.style.mode = $1 },
            "always": named { (s: inout Settings, v: Style) in s.style.always = v },
            "never": names { (s: inout Settings, v: Set<Style>) in s.style.never = v },
        ],
        "tonality": [
            "mode": named { (s: inout Settings, v: Selection<Tonality>.Mode) in s.tonality.mode = v },
            "always": named { (s: inout Settings, v: Tonality) in s.tonality.always = v },
            "never": names { (s: inout Settings, v: Set<Tonality>) in s.tonality.never = v },
            "hemisphere": named { (s: inout Settings, v: Hemisphere) in s.hemisphere = v },
        ],
        "effects": [
            "random": bool { $0.randomEffect = $1 },
            "random_never": names { (s: inout Settings, v: Set<Effect>) in
                s.randomEffectNever = v.subtracting([.none])
            },
        ],
        "effects.vignette": [
            "on": bool { $0.effects.vignette = $1 ? $0.effects.vignette ?? 1 : nil },
            "strength": number(0 ... 3) { if $0.effects.vignette != nil { $0.effects.vignette = $1 } },
        ],
        "effects.grain": [
            "on": bool { $0.effects.grain = $1 ? $0.effects.grain ?? 0.035 : nil },
            "amount": number(0 ... 0.2) { if $0.effects.grain != nil { $0.effects.grain = $1 } },
        ],
        "effects.dither": [
            "on": toggle(.dither),
            "levels": whole(2 ... 16) { $0.effects.dither?.levels = $1 },
            "cell": number(1 ... 4) { $0.effects.dither?.cell = $1 },
        ],
        "effects.halftone": [
            "on": toggle(.halftone),
            "spacing": number(4 ... 24) { $0.effects.halftone?.spacing = $1 },
            "angle": number(0 ... 90) { $0.effects.halftone?.angle = $1 },
        ],
        "effects.glass": [
            "on": toggle(.glass),
            "width": number(12 ... 96) { $0.effects.glass?.width = $1 },
            "strength": number(0 ... 0.9) { $0.effects.glass?.strength = $1 },
        ],
        "effects.bloom": [
            "on": toggle(.bloom),
            "threshold": number(0 ... 1) { $0.effects.bloom?.threshold = $1 },
            "strength": number(0 ... 1.5) { $0.effects.bloom?.strength = $1 },
        ],
        "effects.leak": [
            "on": toggle(.leak),
            "strength": number(0 ... 2) { $0.effects.leak?.strength = $1 },
            "warmth": number(0 ... 1) { $0.effects.leak?.warmth = $1 },
        ],
        "effects.paper": [
            "on": toggle(.paper),
            "strength": number(0 ... 2) { $0.effects.paper?.strength = $1 },
        ],
        "effects.posterize": [
            "on": toggle(.posterize),
            "bands": whole(3 ... 16) { $0.effects.posterize?.bands = $1 },
        ],
        "shuffle": [
            "every": name(intervals) { $0.interval = $1 },
            "on_wake": bool { $0.shuffleOnWake = $1 },
        ],
        "screen": [
            "spaces": named { (s: inout Settings, v: SpacesMode) in s.spaces = v },
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
            "speed": named { (s: inout Settings, v: MotionSpeed) in s.motionSpeed = v },
            "movement": named { (s: inout Settings, v: MotionMovement) in s.motionMovement = v },
            "settle": number(0.5 ... 8) { $0.settleSeconds = $1 },
            "easing": name(easings) { $0.settleEasing = $1 },
        ],
    ]

    /// Undertone 0.4's `[picture]` keys.
    private static func readOld(_ key: String, _ value: Value, into legacy: inout LegacySettings) -> String? {
        func choice<T: RawRepresentable & Hashable & Codable & Sendable>(_ name: String) -> Choice<T>?
            where T.RawValue == String
        {
            name == "random" ? .random : T(rawValue: name).map { .locked($0) }
        }
        switch (key, value) {
        case let ("style", .string(name)): legacy.style = choice(name)
        case let ("tonality", .string(name)): legacy.tonality = choice(name)
        case let ("effect", .string(name)): legacy.effect = choice(name)
        case let ("spaces", .string(name)): legacy.spaces = SpacesMode(rawValue: name)
        case let ("grain", .number(amount)): legacy.grain = Float(amount)
        default: return "not understood"
        }
        return nil
    }

    // MARK: Writing

    /// The whole file for `settings`, every key with a line saying what it takes, and every effect's section, on or
    /// off. Undertone writes it this way whenever a setting changes from its settings window or menu.
    public static func render(_ settings: Settings) -> String {
        func quote(_ text: String) -> String {
            "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\t", with: "\\t") + "\""
        }
        func list<T: RawRepresentable & Hashable>(_ items: Set<T>, order: [T]) -> String where T.RawValue == String {
            "[" + order.filter { items.contains($0) }.map { quote($0.rawValue) }.joined(separator: ", ") + "]"
        }
        func number(_ value: Float) -> String {
            var text = String(format: "%.3f", value)
            while text.hasSuffix("0") {
                text.removeLast()
            }
            return text.hasSuffix(".") ? text + "0" : text
        }
        let effects = settings.effects
        let interval = intervals.first { $0.value == settings.interval }?.key ?? "never"
        let easing = easings.first { $0.value == settings.settleEasing }?.key ?? "ease-out"
        let styles = Style.allCases.map(\.rawValue).joined(separator: ", ")
        let tonalities = Tonality.allCases.map(\.rawValue).joined(separator: ", ")
        let selectable = Effect.selectable.map(\.rawValue).joined(separator: ", ")
        let dither = effects.dither ?? .init(), halftone = effects.halftone ?? .init()
        let glass = effects.glass ?? .init(), bloom = effects.bloom ?? .init(), leak = effects.leak ?? .init()
        let paper = effects.paper ?? .init(), posterize = effects.posterize ?? .init()
        return """
        # Undertone's settings. Undertone reads this file when it changes, and writes it (in this layout, without
        # comments of your own) when you change a setting from its settings window or menu.
        # https://mpdreamz.github.io/undertone/reference/configuration/

        [style]
        mode = \(quote(settings.style.mode.rawValue))  # shuffle (a new style each shuffle) or always
        always = \(quote(settings.style.always.rawValue))  # the style when mode = "always"
        never = \(list(settings.style.never, order: Style.allCases))  # left out of shuffles: \(styles)

        [tonality]
        mode = \(quote(settings.tonality.mode
                .rawValue))  # shuffle, season (suits the time of year, never mono) or always
        always = \(quote(settings.tonality.always.rawValue))  # the tonality when mode = "always"
        never = \(list(settings.tonality.never, order: Tonality.allCases))  # left out of shuffles: \(tonalities)
        hemisphere = \(quote(settings.hemisphere
                .rawValue))  # whose seasons: auto (from the Mac's region), north or south

        # Effects go over every picture, in a fixed order: glass, halftone, vignette, bloom, posterize, paper, leak,
        # dither, grain. Each has its own section; on = false turns it off and keeps its settings here.
        [effects]
        random = \(settings.randomEffect)  # one more effect on each shuffle, chosen at random
        random_never = \(list(settings.randomEffectNever, order: Effect.selectable))  # left out: \(selectable)

        [effects.vignette]
        on = \(effects.vignette != nil)
        strength = \(number(effects.vignette ?? 1))  # 0 to 3; 1 is the usual

        [effects.grain]
        on = \(effects.grain != nil)
        amount = \(number(effects.grain ?? 0.035))  # 0 to 0.2; 0.035 subtle, 0.06 strong

        [effects.dither]
        on = \(effects.dither != nil)
        levels = \(dither.levels)  # levels per colour, 2 to 16
        cell = \(number(dither.cell))  # points per cell, 1 to 4

        [effects.halftone]
        on = \(effects.halftone != nil)
        spacing = \(number(halftone.spacing))  # points between dots, 4 to 24
        angle = \(number(halftone.angle))  # degrees, 0 to 90

        [effects.glass]
        on = \(effects.glass != nil)
        width = \(number(glass.width))  # points per flute, 12 to 96
        strength = \(number(glass.strength))  # how much each flute magnifies, 0 to 0.9

        [effects.bloom]
        on = \(effects.bloom != nil)
        threshold = \(number(bloom.threshold))  # how bright a part must be to glow, 0 to 1
        strength = \(number(bloom.strength))  # 0 to 1.5

        [effects.leak]
        on = \(effects.leak != nil)
        strength = \(number(leak.strength))  # 0 to 2
        warmth = \(number(leak.warmth))  # 0 rose to 1 amber

        [effects.paper]
        on = \(effects.paper != nil)
        strength = \(number(paper.strength))  # 0 to 2

        [effects.posterize]
        on = \(effects.posterize != nil)
        bands = \(posterize.bands)  # bands of lightness, 3 to 16

        [shuffle]
        every = \(quote(interval))  # never, hourly, 3h or daily
        on_wake = \(settings.shuffleOnWake)  # a new picture on login and wake

        [screen]
        spaces = \(quote(settings.spaces.rawValue))  # same (one picture on every space) or different
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
