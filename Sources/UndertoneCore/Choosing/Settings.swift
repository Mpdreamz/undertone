import Foundation

/// A setting that is either fixed or picked anew at every shuffle. Style and tonality each have one, independently.
public enum Choice<Value: Hashable & Codable & Sendable>: Hashable, Codable, Sendable {
    case random
    case locked(Value)
}

/// Every space shows the same picture, or each its own (from its own seed, in the same style and tonality).
public enum SpacesMode: String, CaseIterable, Codable, Sendable {
    case same, different
}

/// How often a new picture is picked on its own; a shuffle from the menu or `undertone shuffle` works regardless.
public enum ShuffleInterval: String, CaseIterable, Codable, Sendable {
    case never, hourly, threeHours, daily

    public var seconds: TimeInterval? {
        switch self {
        case .never: nil
        case .hourly: 3600
        case .threeHours: 3 * 3600
        case .daily: 24 * 3600
        }
    }

    public var title: String {
        switch self {
        case .never: "Never"
        case .hourly: "Every Hour"
        case .threeHours: "Every 3 Hours"
        case .daily: "Every Day"
        }
    }
}

/// Everything the user chooses. Decoding fills anything missing with its default, so a setting added later does not
/// throw away the rest.
public struct Settings: Hashable, Codable, Sendable {
    public var style: Choice<Style> = .random
    public var tonality: Choice<Tonality> = .random
    public var spaces: SpacesMode = .different
    public var interval: ShuffleInterval = .never
    /// A new picture when the Mac wakes or Undertone starts.
    public var shuffleOnWake = false
    public var grain: Float = 0.035
    /// A black strip the height of the menu bar on displays with a notch, so the notch disappears into it.
    public var hideNotch = false
    /// Black outside a rounded rectangle (below the strip, if there is one), so windows' corners meet black.
    public var roundCorners = false
    /// In points: 16 is a macOS 26 window's own corner, so a window tiled into a corner shows no picture behind it.
    public var cornerRadius: Float = 16
    public var showText = false
    public var title = "{computer}"
    public var subtitle = "{user} · macOS {os}"
    /// Leave the desktop picture alone: nothing is set or put back.
    public var paused = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        style = (try? c.decode(Choice<Style>.self, forKey: .style)) ?? d.style
        tonality = (try? c.decode(Choice<Tonality>.self, forKey: .tonality)) ?? d.tonality
        spaces = (try? c.decode(SpacesMode.self, forKey: .spaces)) ?? d.spaces
        interval = (try? c.decode(ShuffleInterval.self, forKey: .interval)) ?? d.interval
        shuffleOnWake = (try? c.decode(Bool.self, forKey: .shuffleOnWake)) ?? d.shuffleOnWake
        grain = (try? c.decode(Float.self, forKey: .grain)) ?? d.grain
        hideNotch = (try? c.decode(Bool.self, forKey: .hideNotch)) ?? d.hideNotch
        roundCorners = (try? c.decode(Bool.self, forKey: .roundCorners)) ?? d.roundCorners
        cornerRadius = (try? c.decode(Float.self, forKey: .cornerRadius)) ?? d.cornerRadius
        showText = (try? c.decode(Bool.self, forKey: .showText)) ?? d.showText
        title = (try? c.decode(String.self, forKey: .title)) ?? d.title
        subtitle = (try? c.decode(String.self, forKey: .subtitle)) ?? d.subtitle
        paused = (try? c.decode(Bool.self, forKey: .paused)) ?? d.paused
    }
}
