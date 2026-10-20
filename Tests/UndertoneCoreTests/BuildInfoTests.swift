import Testing
@testable import UndertoneCore

@Suite(.timeLimit(.minutes(1)))
struct BuildInfoTests {
    @Test func readsTheBundle() {
        let info = BuildInfo(info: [
            "CFBundleShortVersionString": "0.2.0", "CFBundleVersion": "12", "UndertoneCommit": "1a2b3c4",
        ])
        #expect(info.label == "Undertone 0.2.0 (12, 1a2b3c4)")
        #expect(!info.isDev)
    }

    @Test func aLocalBuildIsDev() {
        #expect(BuildInfo(info: ["CFBundleShortVersionString": "0.1.0-dev"]).isDev)
    }

    @Test func missingKeysDoNotCrash() {
        #expect(BuildInfo(info: [:]).label == "Undertone ? (?, ?)")
    }
}
