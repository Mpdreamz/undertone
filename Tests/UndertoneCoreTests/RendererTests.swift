import Foundation
import simd
import Testing
@testable import UndertoneCore

@Suite(.timeLimit(.minutes(1)))
struct RendererTests {
    /// Small enough to draw every style quickly in a debug build, wide like a laptop display.
    static let width = 96, height = 62

    static func draw(_ recipe: Recipe) -> Picture {
        Renderer.render(recipe, width: width, height: height)
    }

    /// Mean Rec. 709 luma, 0…1.
    static func luma(_ picture: Picture) -> Double {
        var sum = 0.0
        for i in stride(from: 0, to: picture.pixels.count, by: 4) {
            sum += 0.2126 * Double(picture.pixels[i]) + 0.7152 * Double(picture.pixels[i + 1])
                + 0.0722 * Double(picture.pixels[i + 2])
        }
        return sum / Double(picture.pixels.count / 4) / 255
    }

    static func spread(_ picture: Picture) -> Int {
        let greens = stride(from: 1, to: picture.pixels.count, by: 4).map { Int(picture.pixels[$0]) }
        return greens.max()! - greens.min()!
    }

    @Test func theSameRecipeDrawsTheSamePixels() {
        let recipe = Recipe(style: .flow, tonality: .dusk, appearance: .dark, seed: 7)
        #expect(Self.draw(recipe).pixels == Self.draw(recipe).pixels)
    }

    @Test func anotherSeedDrawsAnotherPicture() {
        let recipe = Recipe(style: .waves, tonality: .tide, appearance: .dark, seed: 1)
        var other = recipe
        other.seed = 2
        #expect(Self.draw(recipe).pixels != Self.draw(other).pixels)
    }

    @Test(arguments: Style.allCases)
    func everyStyleDrawsSomethingInBothAppearances(style: Style) {
        let dark = Self.draw(Recipe(style: style, tonality: .ember, appearance: .dark, seed: 3, grain: 0))
        let light = Self.draw(Recipe(style: style, tonality: .ember, appearance: .light, seed: 3, grain: 0))
        #expect(dark.pixels.count == Self.width * Self.height * 4)
        // Not one flat colour: the style drew shapes or a gradient.
        #expect(Self.spread(dark) > 12, "\(style) dark is flat")
        #expect(Self.spread(light) > 12, "\(style) light is flat")
        #expect(Self.luma(dark) < Self.luma(light), "\(style): dark is not darker than light")
        #expect(Self.luma(dark) < 0.5, "\(style): dark is too bright")
        #expect(Self.luma(light) > 0.55, "\(style): light is too dim")
    }

    @Test(arguments: Tonality.allCases)
    func everyTonalityHasFiveColoursForBothAppearances(tonality: Tonality) {
        for appearance in Appearance.allCases {
            let palette = tonality.palette(appearance)
            #expect(palette.colors.count == 5)
            #expect(palette.isDark == (appearance == .dark))
        }
        let dark = Self.draw(Recipe(style: .mesh, tonality: tonality, appearance: .dark, seed: 5))
        let light = Self.draw(Recipe(style: .mesh, tonality: tonality, appearance: .light, seed: 5))
        #expect(Self.luma(dark) < Self.luma(light))
    }

    @Test func grainOnlyAddsNoise() {
        let clean = Self.draw(Recipe(style: .mesh, tonality: .glacier, appearance: .dark, seed: 9, grain: 0))
        let grainy = Self.draw(Recipe(style: .mesh, tonality: .glacier, appearance: .dark, seed: 9, grain: 0.06))
        #expect(clean.pixels != grainy.pixels)
        #expect(abs(Self.luma(clean) - Self.luma(grainy)) < 0.02)
    }

    @Test func theAlphaChannelIsOpaque() {
        let picture = Self.draw(Recipe(style: .orbs, tonality: .aurora, appearance: .light, seed: 4))
        #expect(stride(from: 3, to: picture.pixels.count, by: 4).allSatisfy { picture.pixels[$0] == 255 })
    }

    @Test func aPictureEncodesAsPNG() throws {
        let png = try #require(Self.draw(Recipe(style: .rings, tonality: .citrus, appearance: .dark, seed: 1)).png())
        #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    @Test func recipesRoundTripThroughJSON() throws {
        let recipe = Recipe(style: .silk, tonality: .moss, appearance: .light, seed: .max, grain: 0.05)
        let decoded = try JSONDecoder().decode(Recipe.self, from: JSONEncoder().encode(recipe))
        #expect(decoded == recipe)
    }
}

@Suite(.timeLimit(.minutes(1)))
struct ColorTests {
    @Test func okLabRoundTrips() {
        for hex in ["#08090B", "#FFB03D", "#A96BFF", "#FFFFFF", "#1F6FEB"] {
            let color = RGB(hex: hex)
            let back = OkLab.to(OkLab.from(color))
            #expect(simd_reduce_max(abs(back - color)) < 0.002, "\(hex)")
        }
    }

    @Test func aRampStartsAndEndsOnItsColours() {
        let a = RGB(hex: "#FF5E7E"), b = RGB(hex: "#2B1650")
        let ramp = Ramp([a, b])
        #expect(simd_reduce_max(abs(ramp(0) - a)) < 0.002)
        #expect(simd_reduce_max(abs(ramp(1) - b)) < 0.002)
        #expect(simd_reduce_max(abs(ramp(-3) - a)) < 0.002)
    }

    @Test func smoothRunsEitherWay() {
        #expect(smooth(0, 1, -1) == 0)
        #expect(smooth(0, 1, 2) == 1)
        #expect(smooth(1, 0, 2) == 0)
        #expect(smooth(0, 1, 0.5) == 0.5)
    }

    @Test func theRandomSequenceIsFixedBySeed() {
        var a = RNG(seed: 42), b = RNG(seed: 42)
        #expect((0 ..< 8).map { _ in a.next() } == (0 ..< 8).map { _ in b.next() })
        var c = RNG(seed: 1)
        #expect((0 ..< 1000).allSatisfy { _ in (0 ..< 1).contains(c.unit()) })
    }
}
