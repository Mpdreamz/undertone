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

    @Test func alwaysStaysAndShuffleChanges() {
        var settings = Settings()
        settings.style = Selection(mode: .always, always: .waves)
        var rng = Fixed()
        var pick = Pick.next(after: nil, settings: settings, rng: &rng)
        for _ in 0 ..< 50 {
            let next = Pick.next(after: pick, settings: settings, rng: &rng)
            #expect(next.style == .waves)
            #expect(next.tonality != pick.tonality, "a shuffled tonality never repeats")
            #expect(next.seed != pick.seed)
            pick = next
        }
    }

    @Test func shufflesNeverPickWhatIsLeftOut() {
        var settings = Settings()
        settings.style.never = [.bauhaus, .contour, .mesh]
        settings.tonality.never = Set(Tonality.allCases.filter { $0 != .moss && $0 != .tide })
        var rng = Fixed()
        var styles = Set<Style>(), tonalities = Set<Tonality>()
        var pick: Pick?
        for _ in 0 ..< 200 {
            let next = Pick.next(after: pick, settings: settings, rng: &rng)
            styles.insert(next.style)
            tonalities.insert(next.tonality)
            pick = next
        }
        #expect(styles == Set(Style.allCases).subtracting([.bauhaus, .contour, .mesh]))
        #expect(tonalities == [.moss, .tide])
    }

    @Test func leavingEverythingOutStillShuffles() {
        var settings = Settings()
        settings.style.never = Set(Style.allCases)
        #expect(settings.style.allowed.count == Style.allCases.count)
        var rng = Fixed()
        #expect(Style.allCases.contains(Pick.next(after: nil, settings: settings, rng: &rng).style))
    }

    @Test func changingTheSettingsKeepsWhatItCanAndTheSeed() {
        let pick = Pick(style: .mesh, tonality: .ember, seed: 7)
        var settings = Settings()
        settings.tonality = Selection(mode: .always, always: .glacier)
        #expect(pick.applying(settings) == Pick(style: .mesh, tonality: .glacier, seed: 7))
        var excluded = Settings()
        excluded.style.never = [.mesh]
        let moved = pick.applying(excluded)
        #expect(moved.style != .mesh, "leaving out the style showing changes it")
        #expect(moved.tonality == .ember && moved.seed == 7)
        #expect(pick.applying(Settings()) == pick, "nothing to change")
    }

    @Test func spacesShareASeedOrHaveTheirOwn() {
        let pick = Pick(style: .dunes, tonality: .dusk, seed: 1234)
        var settings = Settings()
        #expect(settings.spaces == .same, "one picture everywhere unless asked")
        let a = pick.recipe(space: "A", settings: settings, appearance: .dark)
        let b = pick.recipe(space: "B", settings: settings, appearance: .dark)
        #expect(a == b)
        settings.spaces = .different
        let a2 = pick.recipe(space: "A", settings: settings, appearance: .dark)
        let b2 = pick.recipe(space: "B", settings: settings, appearance: .dark)
        #expect(a2.seed != b2.seed)
        #expect(a2.tonality == b2.tonality && a2.style == b2.style)
        #expect(a2 == pick.recipe(space: "A", settings: settings, appearance: .dark))
    }

    @Test func theRandomEffectIsOffUntilAskedForThenNeverRepeats() {
        var rng = Fixed()
        let plain = Pick.next(after: nil, settings: Settings(), rng: &rng)
        #expect(plain.effect == .none)
        #expect(plain.recipe(space: "A", settings: Settings(), appearance: .dark).effects == .standard)
        var settings = Settings()
        settings.randomEffect = true
        settings.randomEffectNever = [.dither, .paper]
        settings.effects.halftone = .init()
        var pick = Pick.next(after: nil, settings: settings, rng: &rng)
        for _ in 0 ..< 40 {
            let next = Pick.next(after: pick, settings: settings, rng: &rng)
            #expect(![.none, .dither, .paper, .halftone].contains(next.effect), "never none, left out, or already on")
            #expect(next.effect != pick.effect)
            pick = next
        }
        let recipe = pick.recipe(space: "A", settings: settings, appearance: .dark)
        #expect(recipe.effects.isOn(pick.effect) && recipe.effects.isOn(.halftone))
        #expect(recipe.effects.grain == 0.035, "the random effect joins the chosen ones")
    }

    @Test func turningTheRandomEffectOnShowsOneAndOffRemovesIt() {
        let pick = Pick(style: .mesh, tonality: .ember, seed: 7)
        var settings = Settings()
        settings.randomEffect = true
        let on = pick.applying(settings)
        #expect(on.effect != .none)
        #expect(on.applying(Settings()).effect == .none)
    }

    @Test func aPickSavedBeforeEffectsStillLoads() throws {
        let old = Data(#"{"style":"waves","tonality":"tide","seed":42}"#.utf8)
        #expect(try JSONDecoder().decode(Pick.self, from: old) == Pick(style: .waves, tonality: .tide, seed: 42))
    }

    @Test func undertone03SettingsMoveOver() throws {
        let json = Data(#"""
        {"style":{"locked":{"_0":"aurora"}},"tonality":{"random":{}},"effect":{"locked":{"_0":"glass"}},
         "grain":0,"hideNotch":true,"interval":"daily"}
        """#.utf8)
        let settings = try #require(Settings.fromLegacyJSON(json))
        #expect(settings.style == Selection(mode: .always, always: .aurora))
        #expect(settings.tonality.mode == .shuffle && settings.tonality.never.isEmpty)
        #expect(settings.effects.glass != nil)
        #expect(settings.effects.grain == nil, "grain 0 is off")
        #expect(settings.effects.vignette == 1)
        #expect(settings.hideNotch && settings.interval == .daily)
        #expect(settings.spaces == .different, "0.3's default stays for those who had it")
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
        Recipe(style: .mesh, tonality: .dusk, appearance: .light, seed: 2, effects: Effects(grain: nil)), width: 200,
        height: 120
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
