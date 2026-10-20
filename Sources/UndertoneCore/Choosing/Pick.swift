import Foundation

/// What is showing now: a style, a tonality and a seed, kept between launches so a restart shows the same picture.
/// The appearance is not part of it: light and dark draw the same pick from their own half of the tonality.
public struct Pick: Hashable, Codable, Sendable {
    public var style: Style
    public var tonality: Tonality
    public var seed: UInt64
    public var effect: Effect

    public init(style: Style, tonality: Tonality, seed: UInt64, effect: Effect = .none) {
        self.style = style
        self.tonality = tonality
        self.seed = seed
        self.effect = effect
    }

    /// A pick saved before effects existed has none.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        style = try c.decode(Style.self, forKey: .style)
        tonality = try c.decode(Tonality.self, forKey: .tonality)
        seed = try c.decode(UInt64.self, forKey: .seed)
        effect = (try? c.decode(Effect.self, forKey: .effect)) ?? .none
    }

    /// The first pick, or the next one: a style or tonality set to always stays; a shuffled one changes to another
    /// it is allowed (never the same, so a shuffle always looks like one); the seed is always new; and the random
    /// effect, when it is on, is a different one each time.
    public static func next(after current: Pick?, settings: Settings, rng: inout some RandomNumberGenerator) -> Pick {
        Pick(
            style: choose(settings.style, current: current?.style, rng: &rng),
            tonality: choose(settings.tonality, current: current?.tonality, rng: &rng),
            seed: rng.next(),
            effect: randomEffect(settings, current: current?.effect, rng: &rng)
        )
    }

    /// The pick under changed settings, keeping what it can: a style newly set to always, or newly excluded, changes;
    /// the random effect appears or goes with its switch. The seed stays, so the picture is recoloured, not redrawn.
    public func applying(_ settings: Settings) -> Pick {
        var pick = self
        var rng = SystemRandomNumberGenerator()
        if !settings.style.allows(style) { pick.style = Self.choose(settings.style, current: style, rng: &rng) }
        if !settings.tonality.allows(tonality) {
            pick.tonality = Self.choose(settings.tonality, current: tonality, rng: &rng)
        }
        let choices = settings.randomEffectChoices
        if !settings.randomEffect {
            pick.effect = .none
        } else if pick.effect == .none || !choices.contains(pick.effect) {
            pick.effect = Self.randomEffect(settings, current: nil, rng: &rng)
        }
        return pick
    }

    private static func choose<T>(
        _ selection: Selection<T>, current: T?, rng: inout some RandomNumberGenerator
    ) -> T {
        if selection.mode == .always { return selection.always }
        let allowed = selection.allowed
        let others = allowed.filter { $0 != current }
        return (others.isEmpty ? allowed : others).randomElement(using: &rng)!
    }

    private static func randomEffect(
        _ settings: Settings, current: Effect?, rng: inout some RandomNumberGenerator
    ) -> Effect {
        guard settings.randomEffect else { return .none }
        let choices = settings.randomEffectChoices
        let others = choices.filter { $0 != current }
        return (others.isEmpty ? choices : others).randomElement(using: &rng) ?? .none
    }

    /// The recipe for one space: with different pictures per space, the seed is mixed with the space's key, so each
    /// space keeps its own picture until the next shuffle. The random effect joins the chosen ones at its defaults.
    public func recipe(space: String, settings: Settings, appearance: Appearance) -> Recipe {
        let spaceSeed = settings.spaces == .same ? seed : seed ^ Self.fnv1a(space)
        let effects = effect == .none ? settings.effects : settings.effects.with(effect)
        return Recipe(style: style, tonality: tonality, appearance: appearance, seed: spaceSeed, effects: effects)
    }

    /// FNV-1a: a stable hash of a string (Swift's own `hashValue` changes on every launch).
    static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100_0000_01B3
        }
        return hash
    }
}
