/// The effects that are on, each with its own settings; nil is off. They apply in a fixed order, so no effect
/// undoes another: glass, then halftone (both read the picture elsewhere), the vignette, bloom, posterize, paper,
/// the light leak, dither, and grain last.
///
/// `standard` is what a new install draws: the vignette and a subtle grain.
public struct Effects: Hashable, Codable, Sendable {
    /// How far the corners darken, as a multiple of the usual (which is stronger on dark pictures than light ones).
    public var vignette: Float?
    /// Film grain's strength: 0.035 is subtle, 0.06 plainly there.
    public var grain: Float?
    public var dither: Dither?
    public var halftone: Halftone?
    public var glass: Glass?
    public var bloom: Bloom?
    public var leak: Leak?
    public var paper: Paper?
    public var posterize: Posterize?

    public struct Dither: Hashable, Codable, Sendable {
        /// Levels per colour channel, 2 to 16.
        public var levels = 4
        /// Points per dither cell, 1 to 4.
        public var cell: Float = 1
        public init() {}
    }

    public struct Halftone: Hashable, Codable, Sendable {
        /// Points between dots, 4 to 24.
        public var spacing: Float = 8
        /// The grid's angle in degrees.
        public var angle: Float = 45
        public init() {}
    }

    public struct Glass: Hashable, Codable, Sendable {
        /// Points per flute, 12 to 96.
        public var width: Float = 36
        /// How much each flute magnifies, 0 to 0.9.
        public var strength: Float = 0.55
        public init() {}
    }

    public struct Bloom: Hashable, Codable, Sendable {
        /// How bright a part must be to glow, 0 to 1 (dark pictures).
        public var threshold: Float = 0.45
        public var strength: Float = 0.6
        public init() {}
    }

    public struct Leak: Hashable, Codable, Sendable {
        public var strength: Float = 1
        /// 1 is amber, 0 is rose.
        public var warmth: Float = 1
        public init() {}
    }

    public struct Paper: Hashable, Codable, Sendable {
        public var strength: Float = 1
        public init() {}
    }

    public struct Posterize: Hashable, Codable, Sendable {
        /// Bands of lightness on a dark picture; a light one gets four times as many, narrower ones.
        public var bands = 7
        public init() {}
    }

    public init(
        vignette: Float? = 1, grain: Float? = 0.035, dither: Dither? = nil, halftone: Halftone? = nil,
        glass: Glass? = nil, bloom: Bloom? = nil, leak: Leak? = nil, paper: Paper? = nil, posterize: Posterize? = nil
    ) {
        self.vignette = vignette
        self.grain = grain
        self.dither = dither
        self.halftone = halftone
        self.glass = glass
        self.bloom = bloom
        self.leak = leak
        self.paper = paper
        self.posterize = posterize
    }

    /// A new install's: the vignette and a subtle grain.
    public static let standard = Effects()
    /// Nothing at all over the style.
    public static let none = Effects(vignette: nil, grain: nil)

    public func isOn(_ effect: Effect) -> Bool {
        switch effect {
        case .none: false
        case .dither: dither != nil
        case .halftone: halftone != nil
        case .glass: glass != nil
        case .bloom: bloom != nil
        case .leak: leak != nil
        case .paper: paper != nil
        case .posterize: posterize != nil
        }
    }

    /// With `effect` on: as it is when it already is, at its defaults when it was off.
    public func with(_ effect: Effect) -> Effects {
        var effects = self
        effects.set(effect, on: true)
        return effects
    }

    public mutating func set(_ effect: Effect, on: Bool) {
        switch effect {
        case .none: break
        case .dither: dither = on ? dither ?? Dither() : nil
        case .halftone: halftone = on ? halftone ?? Halftone() : nil
        case .glass: glass = on ? glass ?? Glass() : nil
        case .bloom: bloom = on ? bloom ?? Bloom() : nil
        case .leak: leak = on ? leak ?? Leak() : nil
        case .paper: paper = on ? paper ?? Paper() : nil
        case .posterize: posterize = on ? posterize ?? Posterize() : nil
        }
    }
}
