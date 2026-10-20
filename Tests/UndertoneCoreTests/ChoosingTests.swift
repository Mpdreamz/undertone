import CoreGraphics
import Foundation
import Testing
@testable import UndertoneCore

@Suite(.timeLimit(.minutes(1)))
struct ChoosingTests {
    /// The same "random" sequence every run.
    struct Fixed: RandomNumberGenerator {
        var rng = RNG(seed: 99)
        mutating func next() -> UInt64 {
            rng.next()
        }
    }

    @Test func lockedChoicesStayAndRandomOnesChange() {
        var settings = Settings()
        settings.style = .locked(.waves)
        var rng = Fixed()
        var pick = Pick.next(after: nil, settings: settings, rng: &rng)
        for _ in 0 ..< 50 {
            let next = Pick.next(after: pick, settings: settings, rng: &rng)
            #expect(next.style == .waves)
            #expect(next.tonality != pick.tonality, "a random tonality never repeats on a shuffle")
            #expect(next.seed != pick.seed)
            pick = next
        }
    }

    @Test func randomStyleAndRandomTonalityAreIndependent() {
        var settings = Settings()
        settings.tonality = .locked(.moss)
        var rng = Fixed()
        let styles = Set((0 ..< 40).map { _ in Pick.next(after: nil, settings: settings, rng: &rng).style })
        #expect(styles.count > 5)
        #expect((0 ..< 10).allSatisfy { _ in Pick.next(after: nil, settings: settings, rng: &rng).tonality == .moss })
    }

    @Test func lockingAChoiceChangesThePickButNotItsSeed() {
        let pick = Pick(style: .mesh, tonality: .ember, seed: 7)
        var settings = Settings()
        settings.tonality = .locked(.glacier)
        let applied = pick.applying(settings)
        #expect(applied == Pick(style: .mesh, tonality: .glacier, seed: 7))
    }

    @Test func spacesShareASeedOrHaveTheirOwn() {
        let pick = Pick(style: .dunes, tonality: .dusk, seed: 1234)
        var settings = Settings()
        settings.spaces = .same
        let a = pick.recipe(space: "A", settings: settings, appearance: .dark)
        let b = pick.recipe(space: "B", settings: settings, appearance: .dark)
        #expect(a == b)
        settings.spaces = .different
        let a2 = pick.recipe(space: "A", settings: settings, appearance: .dark)
        let b2 = pick.recipe(space: "B", settings: settings, appearance: .dark)
        #expect(a2.seed != b2.seed)
        #expect(a2.tonality == b2.tonality && a2.style == b2.style)
        // The same space keeps its picture.
        #expect(a2 == pick.recipe(space: "A", settings: settings, appearance: .dark))
    }

    @Test func aRandomEffectIsNeverNoneAndNeverRepeats() {
        var settings = Settings()
        settings.effect = .random
        var rng = Fixed()
        var pick = Pick.next(after: nil, settings: settings, rng: &rng)
        for _ in 0 ..< 40 {
            let next = Pick.next(after: pick, settings: settings, rng: &rng)
            #expect(next.effect != .none)
            #expect(next.effect != pick.effect)
            pick = next
        }
    }

    @Test func effectsAreOffUntilChosen() {
        var rng = Fixed()
        #expect(Pick.next(after: nil, settings: Settings(), rng: &rng).effect == .none)
        var settings = Settings()
        settings.effect = .locked(.halftone)
        let pick = Pick(style: .mesh, tonality: .ember, seed: 1)
        #expect(pick.applying(settings).effect == .halftone)
        #expect(pick.applying(settings).recipe(space: "A", settings: settings, appearance: .dark).effect == .halftone)
        settings.effect = .random
        #expect(pick.applying(settings).effect != .none, "choosing random shows an effect straight away")
    }

    @Test func aPickSavedBeforeEffectsStillLoads() throws {
        let old = Data(#"{"style":"waves","tonality":"tide","seed":42}"#.utf8)
        #expect(try JSONDecoder().decode(Pick.self, from: old) == Pick(style: .waves, tonality: .tide, seed: 42))
    }

    @Test func settingsMissingKeysTakeTheirDefaults() throws {
        let decoded = try JSONDecoder().decode(Settings.self, from: Data(#"{"hideNotch":true}"#.utf8))
        var expected = Settings()
        expected.hideNotch = true
        #expect(decoded == expected)
        #expect(Settings().showText == false, "the title is off until asked for")
    }

    @Test func settingsRoundTrip() throws {
        var settings = Settings()
        settings.style = .locked(.bauhaus)
        settings.interval = .daily
        settings.title = "{computer}!"
        #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings)) == settings)
    }

    @Test func placeholdersAreFilledIn() {
        let text = Placeholders.expand("{computer} · {user} · {nope}", ["computer": "studio", "user": "Ann"])
        #expect(text == "studio · Ann · {nope}")
    }

    @Test func fingerprintsFollowEveryInput() {
        let recipe = Recipe(style: .orbs, tonality: .tide, appearance: .dark, seed: 3)
        let base = Fingerprint.of(recipe, Overlay(), width: 100, height: 60)
        #expect(base == Fingerprint.of(recipe, Overlay(), width: 100, height: 60))
        var light = recipe
        light.appearance = .light
        #expect(base != Fingerprint.of(light, Overlay(), width: 100, height: 60))
        #expect(base != Fingerprint.of(recipe, Overlay(strip: 74), width: 100, height: 60))
        #expect(base != Fingerprint.of(recipe, Overlay(), width: 101, height: 60))
    }
}

@Suite(.timeLimit(.minutes(1)))
struct ComposerTests {
    static let picture = Renderer.render(
        Recipe(style: .mesh, tonality: .dusk, appearance: .light, seed: 2, grain: 0), width: 200, height: 120
    )

    static func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> [UInt8] {
        let data = image.dataProvider!.data! as Data
        let i = y * image.bytesPerRow + x * 4
        return Array(data[i ..< i + 3])
    }

    @Test func anEmptyOverlayLeavesThePictureAlone() throws {
        let image = try #require(Composer.compose(Self.picture, Overlay(), appearance: .light))
        #expect(Self.pixel(image, 0, 0) == Array(Self.picture.pixels[0 ..< 3]))
    }

    @Test func theStripIsBlackAndTheRestIsNot() throws {
        let image = try #require(Composer.compose(Self.picture, Overlay(strip: 20), appearance: .light))
        #expect(Self.pixel(image, 100, 5) == [0, 0, 0])
        #expect(Self.pixel(image, 100, 19) == [0, 0, 0])
        #expect(Self.pixel(image, 100, 21) != [0, 0, 0])
    }

    @Test func roundedCornersAreBlackBelowTheStrip() throws {
        let image = try #require(Composer.compose(
            Self.picture, Overlay(strip: 20, cornerRadius: 16), appearance: .light
        ))
        #expect(Self.pixel(image, 0, 21) == [0, 0, 0], "the corner just under the strip")
        #expect(Self.pixel(image, 199, 119) == [0, 0, 0], "the bottom right corner")
        #expect(Self.pixel(image, 100, 60) != [0, 0, 0])
    }

    @Test func continuousCornersCurveFurtherAlongTheEdgesThanACircle() {
        let rect = CGRect(x: 0, y: 0, width: 400, height: 300)
        let path = ContinuousCorners.path(rect, radius: 20)
        #expect(path.boundingBox.equalTo(rect))
        #expect(path.contains(CGPoint(x: 200, y: 150)))
        for corner in [CGPoint(x: 1, y: 1), CGPoint(x: 399, y: 1), CGPoint(x: 1, y: 299), CGPoint(x: 399, y: 299)] {
            #expect(!path.contains(corner), "the corner \(corner) is cut away")
        }
        // A circle of radius 20 is back on the edge at x = 20; the continuous curve is still 0.14 off it there, and
        // meets it only at x = 30.6.
        #expect(!path.contains(CGPoint(x: 21, y: 0.1)))
        #expect(path.contains(CGPoint(x: 21, y: 0.2)))
        #expect(path.contains(CGPoint(x: 31, y: 0.01)))
        // A radius too big for the rectangle shrinks instead of folding over itself.
        #expect(ContinuousCorners.path(CGRect(x: 0, y: 0, width: 20, height: 20), radius: 50).boundingBox
            .width <= 20.001)
    }

    @Test func aTitleIsDrawnInTheMiddle() throws {
        let plain = try #require(Composer.compose(Self.picture, Overlay(strip: 1), appearance: .light))
        let titled = try #require(Composer.compose(
            Self.picture, Overlay(strip: 1, title: "HHHHHHHH", scale: 1), appearance: .light
        ))
        let row = 50 // just above the baseline at 54% from the top
        let changed = (60 ..< 140).filter { Self.pixel(plain, $0, row) != Self.pixel(titled, $0, row) }
        #expect(!changed.isEmpty)
    }
}
