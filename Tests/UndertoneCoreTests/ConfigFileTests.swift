import Foundation
import Testing
@testable import UndertoneCore

@Suite(.timeLimit(.minutes(1)))
struct ConfigFileTests {
    @Test func theDefaultsRoundTrip() {
        let (settings, warnings) = ConfigFile.parse(ConfigFile.render(Settings()))
        #expect(warnings.isEmpty)
        #expect(settings == Settings())
    }

    @Test func everySettingRoundTrips() {
        var settings = Settings()
        settings.style = .locked(.bauhaus)
        settings.tonality = .locked(.glacier)
        settings.effect = .random
        settings.spaces = .same
        settings.grain = 0.06
        settings.interval = .threeHours
        settings.shuffleOnWake = true
        settings.hideNotch = true
        settings.roundCorners = true
        settings.showText = true
        settings.title = #"My "Mac" \ # not a comment"#
        settings.subtitle = "line\tone"
        settings.lockScreenMotion = true
        settings.motionSpeed = .calm
        settings.motionMovement = .strong
        settings.settleSeconds = 4.5
        settings.settleEasing = .spring
        let (read, warnings) = ConfigFile.parse(ConfigFile.render(settings))
        #expect(warnings.isEmpty)
        #expect(read == settings)
    }

    @Test(arguments: [Choice<Effect>.locked(.none), .locked(.halftone), .random])
    func effectsRoundTrip(effect: Choice<Effect>) {
        var settings = Settings()
        settings.effect = effect
        #expect(ConfigFile.parse(ConfigFile.render(settings)).settings.effect == effect)
    }

    @Test func aPartialFileKeepsTheDefaultsForTheRest() {
        let (settings, warnings) = ConfigFile.parse("""
        # only what I care about
        [screen]
        hide_notch = true   # yes

        [shuffle]
        every = "daily"
        """)
        #expect(warnings.isEmpty)
        var expected = Settings()
        expected.hideNotch = true
        expected.interval = .daily
        #expect(settings == expected)
    }

    @Test func mistakesFallBackToTheirDefaultAndAreReportedByLine() {
        let (settings, warnings) = ConfigFile.parse("""
        [picture]
        style = "wavez"
        grain = 0.5
        tonality = "dusk"
        [shuffle]
        on_wake = yes
        nonsense
        [colours]
        x = 1
        """)
        #expect(settings.style == .random)
        #expect(settings.grain == Settings().grain)
        #expect(settings.tonality == .locked(.dusk), "the rest still applies")
        #expect(warnings.map(\.line) == [2, 3, 6, 7, 8, 9])
        #expect(warnings[0].message.contains("no wavez"))
    }

    @Test func theFileFollowsXDGConfigHome() {
        let home = URL(fileURLWithPath: "/Users/someone")
        #expect(ConfigFile.url(environment: [:], home: home).path == "/Users/someone/.config/undertone/config.toml")
        #expect(
            ConfigFile.url(environment: ["XDG_CONFIG_HOME": "/tmp/xdg"], home: home).path
                == "/tmp/xdg/undertone/config.toml"
        )
        #expect(ConfigFile.url(environment: ["XDG_CONFIG_HOME": ""], home: home).path.hasPrefix("/Users/someone/"))
    }

    @Test func pauseIsNotPartOfTheFile() {
        var settings = Settings()
        settings.paused = true
        #expect(!ConfigFile.render(settings).contains("pause"))
    }
}
