import Foundation
import Testing
@testable import UndertoneCore

@Suite(.timeLimit(.minutes(1)))
struct SeasonTests {
    struct Fixed: RandomNumberGenerator {
        var rng = RNG(seed: 3)
        mutating func next() -> UInt64 {
            rng.next()
        }
    }

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    static func date(month: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: 15))!
    }

    @Test func monthsMakeSeasonsAndTheSouthIsTheOtherWayRound() {
        let north = (1 ... 12).map { Season.on(Self.date(month: $0), in: .north, calendar: Self.calendar) }
        #expect(north == [
            .winter, .winter, .spring, .spring, .spring, .summer, .summer, .summer, .autumn, .autumn, .autumn, .winter,
        ])
        #expect(Season.on(Self.date(month: 1), in: .south, calendar: Self.calendar) == .summer)
        #expect(Season.on(Self.date(month: 10), in: .south, calendar: Self.calendar) == .spring)
    }

    @Test func noSeasonIsMono() {
        #expect(Season.allCases.allSatisfy { !$0.tonalities.contains(.mono) })
        #expect(Set(Season.allCases.flatMap(\.tonalities)) == Set(Tonality.allCases).subtracting([.mono]))
    }

    @Test func theHemisphereComesFromTheRegion() {
        #expect(Hemisphere.auto.resolved(region: "AU") == .south)
        #expect(Hemisphere.auto.resolved(region: "NL") == .north)
        #expect(Hemisphere.auto.resolved(region: nil) == .north)
        #expect(Hemisphere.north.resolved(region: "AU") == .north)
    }

    @Test func bySeasonShufflesOnlyTheSeasonsTonalitiesLessTheLeftOut() {
        var settings = Settings()
        settings.tonality.mode = .season
        settings.hemisphere = .north
        settings.tonality.never = [.dusk]
        var rng = Fixed()
        var seen = Set<Tonality>()
        var pick: Pick?
        for _ in 0 ..< 100 {
            let next = Pick.next(after: pick, settings: settings, on: Self.date(month: 10), rng: &rng)
            seen.insert(next.tonality)
            pick = next
        }
        #expect(seen == [.ember, .moss], "autumn, without dusk, and never mono")
    }

    @Test func leavingOutAllOfASeasonFallsBackToTheSeason() {
        var settings = Settings()
        settings.tonality = Selection(mode: .season, always: .ember, never: [.glacier, .tide, .aurora])
        settings.hemisphere = .north
        #expect(settings.tonality.allowed(on: Self.date(month: 1), in: .north) == [.glacier, .tide, .aurora])
    }

    @Test func aNewSeasonChangesTheTonalityAndKeepsTheRest() {
        var settings = Settings()
        settings.tonality.mode = .season
        settings.hemisphere = .north
        let autumn = Pick(style: .waves, tonality: .ember, seed: 7)
        #expect(autumn.applying(settings, on: Self.date(month: 10)) == autumn, "still in season")
        let winter = autumn.applying(settings, on: Self.date(month: 12))
        #expect(Season.winter.tonalities.contains(winter.tonality))
        #expect(winter.style == .waves && winter.seed == 7)
    }

    @Test func theFileTakesSeasonForTonalitiesOnly() {
        let result = ConfigFile.parse("""
        [tonality]
        mode = "season"
        hemisphere = "south"
        [style]
        mode = "season"
        """)
        #expect(result.settings.tonality.mode == .season)
        #expect(result.settings.hemisphere == .south)
        #expect(result.settings.style.mode == .shuffle)
        #expect(result.warnings.map(\.line) == [5])
        var settings = Settings()
        settings.tonality.mode = .season
        settings.hemisphere = .south
        #expect(ConfigFile.parse(ConfigFile.render(settings)).settings == settings)
    }
}
