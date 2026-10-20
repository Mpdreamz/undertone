import Foundation

/// A setting that was either fixed or picked anew at every shuffle, as Undertone 0.4 and earlier stored style,
/// tonality and effect. Read only, to move old settings over.
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

/// How fast lock screen motion drifts: the length of its loop.
public enum MotionSpeed: String, CaseIterable, Codable, Sendable {
    case calm, normal, lively

    public var seconds: Double {
        switch self {
        case .calm: 20
        case .normal: 12
        case .lively: 8
        }
    }

    public var title: String {
        rawValue.capitalized
    }
}

/// How far lock screen motion moves things, as a multiple of each style's own drift.
public enum MotionMovement: String, CaseIterable, Codable, Sendable {
    case subtle, normal, strong

    public var amount: Float {
        switch self {
        case .subtle: 0.5
        case .normal: 1
        case .strong: 1.6
        }
    }

    public var title: String {
        rawValue.capitalized
    }
}

/// Shuffled among every style (or tonality) but the ones in `never`, or always the same one.
public struct Selection<Value: CaseIterable & Hashable & Sendable>: Hashable, Sendable {
    public enum Mode: String, CaseIterable, Sendable {
        /// A different one each shuffle, from all but `never`.
        case shuffle
        /// Always `always`.
        case always
        /// Tonalities only: a different one each shuffle from those that suit the time of year (never mono), less
        /// `never`. For a style it shuffles.
        case season
    }

    public var mode: Mode = .shuffle
    /// The one used while `mode` is `.always` (kept while shuffling, so switching back finds it).
    public var always: Value
    /// Left out of shuffles.
    public var never: Set<Value> = []

    public init(mode: Mode = .shuffle, always: Value, never: Set<Value> = []) {
        self.mode = mode
        self.always = always
        self.never = never
    }

    /// What a shuffle chooses from: everything not in `never`, or everything when that leaves nothing.
    public var allowed: [Value] {
        let allowed = Value.allCases.filter { !never.contains($0) }
        return allowed.isEmpty ? Array(Value.allCases) : allowed
    }

    public func allows(_ value: Value) -> Bool {
        mode == .always ? value == always : allowed.contains(value)
    }
}

public extension Selection where Value == Tonality {
    /// What a shuffle chooses from on `date`: by season, the season's tonalities not in `never` (all of them when
    /// that leaves none); otherwise as for any selection.
    func allowed(on date: Date, in hemisphere: Hemisphere) -> [Tonality] {
        guard mode == .season else { return mode == .always ? [always] : allowed }
        let season = Season.on(date, in: hemisphere).tonalities
        let left = season.filter { !never.contains($0) }
        return left.isEmpty ? season : left
    }
}

/// Everything the user chooses. A new install draws every style and tonality in turn, a picture shared by every
/// space, with the vignette and a subtle grain and no other effect.
public struct Settings: Hashable, Sendable {
    public var style = Selection<Style>(always: .mesh)
    public var tonality = Selection<Tonality>(always: .ember)
    /// Whose seasons a tonality by season follows.
    public var hemisphere: Hemisphere = .auto
    public var effects = Effects.standard
    /// On every shuffle, one more effect, chosen at random from those not in `randomEffectNever`.
    public var randomEffect = false
    public var randomEffectNever: Set<Effect> = []
    public var spaces: SpacesMode = .same
    public var interval: ShuffleInterval = .never
    /// A new picture when the Mac wakes or Undertone starts.
    public var shuffleOnWake = false
    /// A black strip the height of the menu bar on displays with a notch, so the notch disappears into it.
    public var hideNotch = false
    /// Black outside a rounded rectangle (below the strip, if there is one), so windows' corners meet black.
    public var roundCorners = false
    public var showText = false
    public var title = "{computer}"
    public var subtitle = "{user} · macOS {os}"
    /// Render each display's picture in motion for Undertone's screen saver, and settle it on unlock.
    public var lockScreenMotion = false
    public var motionSpeed: MotionSpeed = .normal
    public var motionMovement: MotionMovement = .normal
    /// How long the settle on unlock takes, in seconds.
    public var settleSeconds: Float = 2.5
    public var settleEasing: Movie.Easing = .easeOut
    /// Leave the desktop picture alone: nothing is set or put back. Kept in the app's state, not the config file.
    public var paused = false

    public init() {}

    /// The effects a random pick may add: on, not excluded, and not already in the set.
    public var randomEffectChoices: [Effect] {
        let choices = Effect.selectable.filter { !randomEffectNever.contains($0) && !effects.isOn($0) }
        return choices
    }
}

/// Settings as Undertone 0.3 stored them (JSON in its defaults) and 0.4 wrote them (`[picture]` in the config file):
/// read once, and turned into today's.
struct LegacySettings: Decodable {
    var style: Choice<Style>?
    var tonality: Choice<Tonality>?
    var effect: Choice<Effect>?
    var spaces: SpacesMode?
    var interval: ShuffleInterval?
    var shuffleOnWake: Bool?
    var grain: Float?
    var hideNotch: Bool?
    var roundCorners: Bool?
    var showText: Bool?
    var title: String?
    var subtitle: String?
    var paused: Bool?
    var lockScreenMotion: Bool?
    var motionSpeed: MotionSpeed?
    var motionMovement: MotionMovement?
    var settleSeconds: Float?
    var settleEasing: Movie.Easing?

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys) -> T? {
            try? c.decode(T.self, forKey: key)
        }
        style = value(.style)
        tonality = value(.tonality)
        effect = value(.effect)
        spaces = value(.spaces)
        interval = value(.interval)
        shuffleOnWake = value(.shuffleOnWake)
        grain = value(.grain)
        hideNotch = value(.hideNotch)
        roundCorners = value(.roundCorners)
        showText = value(.showText)
        title = value(.title)
        subtitle = value(.subtitle)
        paused = value(.paused)
        lockScreenMotion = value(.lockScreenMotion)
        motionSpeed = value(.motionSpeed)
        motionMovement = value(.motionMovement)
        settleSeconds = value(.settleSeconds)
        settleEasing = value(.settleEasing)
    }

    private enum CodingKeys: String, CodingKey {
        case style, tonality, effect, spaces, interval, shuffleOnWake, grain, hideNotch, roundCorners, showText, title
        case subtitle, paused, lockScreenMotion, motionSpeed, motionMovement, settleSeconds, settleEasing
    }

    /// Random becomes shuffle among all; a locked one becomes always that one; grain becomes the grain effect; a
    /// chosen effect is turned on, and a random one becomes the random effect. Anything unset keeps today's default
    /// (but the spaces keep 0.3's default of a picture per space).
    var settings: Settings {
        var s = Settings()
        if case let .locked(value) = style { s.style = Selection(mode: .always, always: value) }
        if case let .locked(value) = tonality { s.tonality = Selection(mode: .always, always: value) }
        if let grain { s.effects.grain = grain > 0 ? grain : nil }
        switch effect {
        case .random: s.randomEffect = true
        case let .locked(value): s.effects.set(value, on: true)
        case nil: break
        }
        s.spaces = spaces ?? .different
        if let interval { s.interval = interval }
        if let shuffleOnWake { s.shuffleOnWake = shuffleOnWake }
        if let hideNotch { s.hideNotch = hideNotch }
        if let roundCorners { s.roundCorners = roundCorners }
        if let showText { s.showText = showText }
        if let title { s.title = title }
        if let subtitle { s.subtitle = subtitle }
        if let paused { s.paused = paused }
        if let lockScreenMotion { s.lockScreenMotion = lockScreenMotion }
        if let motionSpeed { s.motionSpeed = motionSpeed }
        if let motionMovement { s.motionMovement = motionMovement }
        if let settleSeconds { s.settleSeconds = settleSeconds }
        if let settleEasing { s.settleEasing = settleEasing }
        return s
    }
}

public extension Settings {
    /// Settings Undertone 0.3 kept in its defaults, as JSON.
    static func fromLegacyJSON(_ data: Data) -> Settings? {
        (try? JSONDecoder().decode(LegacySettings.self, from: data))?.settings
    }
}
