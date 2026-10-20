import Foundation
import Testing
@testable import UndertoneCore

@Suite(.timeLimit(.minutes(1)))
struct ConfigFileTests {
    @Test func theDefaultsRoundTrip() {
        let result = ConfigFile.parse(ConfigFile.render(Settings()))
        #expect(result.warnings.isEmpty)
        #expect(!result.isOldLayout)
        #expect(result.settings == Settings())
    }

    @Test func anEmptyFileIsTheDefaults() {
        let settings = ConfigFile.parse("# nothing yet\n").settings
        #expect(settings == Settings())
        #expect(settings.effects == .standard, "a subtle grain and the vignette out of the box")
        #expect(!settings.randomEffect)
        #expect(settings.spaces == .same)
    }

    @Test func everySettingRoundTrips() {
        var settings = Settings()
        settings.style = Selection(mode: .always, always: .bauhaus, never: [.mesh, .flow])
        settings.tonality = Selection(mode: .shuffle, always: .glacier, never: [.mono])
        settings.effects = Effects(vignette: 1.5, grain: 0.06)
        settings.effects.dither = .init()
        settings.effects.dither?.levels = 6
        settings.effects.halftone = .init()
        settings.effects.halftone?.angle = 15
        settings.effects.glass = .init()
        settings.effects.bloom = .init()
        settings.effects.leak = .init()
        settings.effects.leak?.warmth = 0.25
        settings.effects.paper = .init()
        settings.effects.posterize = .init()
        settings.effects.posterize?.bands = 4
        settings.randomEffect = true
        settings.randomEffectNever = [.glass, .bloom]
        settings.spaces = .different
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
        let result = ConfigFile.parse(ConfigFile.render(settings))
        #expect(result.warnings.isEmpty)
        #expect(result.settings == settings)
    }

    @Test func effectsCanBeTurnedOffAndKeepTheirSettingsInTheFile() {
        var settings = Settings()
        settings.effects.grain = nil
        settings.effects.vignette = nil
        let text = ConfigFile.render(settings)
        #expect(text.contains("[effects.grain]\non = false"))
        #expect(ConfigFile.parse(text).settings.effects == .none)
    }

    @Test func aPartialFileKeepsTheDefaultsForTheRest() {
        let result = ConfigFile.parse("""
        # only what I care about
        [style]
        never = ["bauhaus", "contour"]   # not these

        [effects.halftone]
        on = true
        spacing = 12

        [screen]
        hide_notch = true
        """)
        #expect(result.warnings.isEmpty)
        var expected = Settings()
        expected.style.never = [.bauhaus, .contour]
        expected.effects.halftone = .init()
        expected.effects.halftone?.spacing = 12
        expected.hideNotch = true
        #expect(result.settings == expected)
    }

    @Test func mistakesFallBackToTheirDefaultAndAreReportedByLine() {
        let result = ConfigFile.parse("""
        [style]
        mode = "sometimes"
        never = ["wavez"]
        [effects.grain]
        amount = 0.5
        [tonality]
        always = "dusk"
        [shuffle]
        on_wake = yes
        nonsense
        [colours]
        x = 1
        """)
        #expect(result.settings.style == Settings().style)
        #expect(result.settings.effects.grain == 0.035)
        #expect(result.settings.tonality.always == .dusk, "the rest still applies")
        #expect(result.warnings.map(\.line) == [2, 3, 5, 9, 10, 11, 12])
        #expect(result.warnings[1].message.contains("no wavez"))
    }

    @Test func undertone04FilesAreReadAndMarkedForRewriting() {
        let result = ConfigFile.parse("""
        [picture]
        style = "aurora"
        tonality = "random"
        effect = "random"
        spaces = "different"
        grain = 0.06

        [screen]
        hide_notch = true
        """)
        #expect(result.isOldLayout)
        #expect(result.warnings.isEmpty)
        #expect(result.settings.style == Selection(mode: .always, always: .aurora))
        #expect(result.settings.tonality.mode == .shuffle)
        #expect(result.settings.randomEffect)
        #expect(result.settings.effects.grain == 0.06)
        #expect(result.settings.spaces == .different)
        #expect(result.settings.hideNotch)
    }

    @Test func listsReadTheWayTOMLWritesThem() {
        let result = ConfigFile.parse("""
        [style]
        never = [ "mesh" , "flow", ]
        [tonality]
        never = []
        """)
        #expect(result.warnings.isEmpty)
        #expect(result.settings.style.never == [.mesh, .flow])
        #expect(result.settings.tonality.never.isEmpty)
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
