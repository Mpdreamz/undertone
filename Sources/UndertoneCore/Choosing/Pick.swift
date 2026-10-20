import Foundation

/// What is showing now: a style, a tonality and a seed, kept between launches so a restart shows the same picture.
/// The appearance is not part of it: light and dark draw the same pick from their own half of the tonality.
public struct Pick: Hashable, Codable, Sendable {
    public var style: Style
    public var tonality: Tonality
    public var seed: UInt64

    public init(style: Style, tonality: Tonality, seed: UInt64) {
        self.style = style
        self.tonality = tonality
        self.seed = seed
    }

    /// The first pick, or the next one: a locked choice stays, a random one changes (never to the same value, so a
    /// shuffle always looks like one), and the seed is always new.
    public static func next(after current: Pick?, settings: Settings, rng: inout some RandomNumberGenerator) -> Pick {
        Pick(
            style: choose(settings.style, current: current?.style, rng: &rng),
            tonality: choose(settings.tonality, current: current?.tonality, rng: &rng),
            seed: rng.next()
        )
    }

    /// The pick with the settings' locked choices applied, keeping the seed: what a change in the menu shows.
    public func applying(_ settings: Settings) -> Pick {
        var pick = self
        if case let .locked(style) = settings.style { pick.style = style }
        if case let .locked(tonality) = settings.tonality { pick.tonality = tonality }
        return pick
    }

    private static func choose<T: CaseIterable & Hashable>(
        _ choice: Choice<T>, current: T?, rng: inout some RandomNumberGenerator
    ) -> T {
        switch choice {
        case let .locked(value): return value
        case .random:
            let others = T.allCases.filter { $0 != current }
            return others.randomElement(using: &rng) ?? T.allCases.randomElement(using: &rng)!
        }
    }

    /// The recipe for one space: with different pictures per space, the seed is mixed with the space's key, so each
    /// space keeps its own picture until the next shuffle.
    public func recipe(space: String, settings: Settings, appearance: Appearance) -> Recipe {
        let spaceSeed = settings.spaces == .same ? seed : seed ^ Self.fnv1a(space)
        return Recipe(style: style, tonality: tonality, appearance: appearance, seed: spaceSeed, grain: settings.grain)
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
