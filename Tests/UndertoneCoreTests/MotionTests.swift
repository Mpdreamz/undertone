import Foundation
import Testing
@testable import UndertoneCore

@Suite(.timeLimit(.minutes(1)))
struct MotionTests {
    static func draw(_ style: Style, _ motion: Motion) -> Picture {
        Renderer.render(
            Recipe(style: style, tonality: .dusk, appearance: .dark, seed: 7), width: 80, height: 52, motion: motion
        )
    }

    static func largestDifference(_ a: Picture, _ b: Picture) -> Int {
        zip(a.pixels, b.pixels).map { abs(Int($0) - Int($1)) }.max() ?? 0
    }

    @Test(arguments: Style.allCases)
    func everyStyleMovesAndLoopsBackOntoTheStill(style: Style) {
        let still = Self.draw(style, .still)
        // A loop starts on the still picture, moves away from it, and ends on it again.
        #expect(Self.draw(style, Motion(time: 0)).pixels == still.pixels, "\(style) does not start on the still")
        #expect(Self.largestDifference(Self.draw(style, Motion(time: 0.3)), still) > 8, "\(style) does not move")
        #expect(Self.largestDifference(Self.draw(style, Motion(time: 1)), still) <= 1, "\(style) is not seamless")
    }

    @Test func aSettleSlowsDownAndEndsOnTheStill() {
        let settle = Movie.settle(from: 0.2, loopSeconds: 12, seconds: 2.5, fps: 24)
        #expect(settle.count == 60)
        #expect(settle.last == .still)
        let amounts = settle.dropLast().map(\.amount)
        #expect(zip(amounts, amounts.dropFirst()).allSatisfy { $0 >= $1 }, "the reach only shrinks")
        let steps = zip(settle.dropLast().map(\.time), settle.dropLast().dropFirst().map(\.time)).map { $1 - $0 }
        #expect(zip(steps, steps.dropFirst()).allSatisfy { $0 >= $1 }, "the drift only slows")
    }

    @Test func aLoopCoversOneCycle() {
        let loop = Movie.loop(seconds: 2, fps: 10)
        #expect(loop.count == 20)
        #expect(loop.first == Motion(time: 0))
        #expect(loop.allSatisfy { $0.time < 1 && $0.amount == 1 })
    }

    @Test func aMovieIsWritten() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("undertone-test-\(UUID()).mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        try Movie.write(
            Recipe(style: .waves, tonality: .tide, appearance: .dark, seed: 1), width: 64, height: 48, scale: 1,
            overlay: Overlay(strip: 4), motions: Movie.loop(seconds: 0.5, fps: 10), fps: 10, codec: .h264, to: url
        )
        let size = try #require(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
        #expect(size > 1000)
    }

    @Test func theManifestRoundTripsAndFallsBackToAnyDisplay() throws {
        let manifest = MotionManifest(displays: ["A": .init(loop: "a-loop.mov", settle: "a-settle.mov")])
        let decoded = try JSONDecoder().decode(MotionManifest.self, from: JSONEncoder().encode(manifest))
        #expect(decoded == manifest)
        #expect(manifest.entry(for: "A")?.loop == "a-loop.mov")
        #expect(manifest.entry(for: "B")?.loop == "a-loop.mov", "a display without movies plays another's")
        #expect(MotionManifest().entry(for: "A") == nil)
        #expect(MotionManifest.folder.path.hasSuffix("Library/Application Support/Undertone/Motion"))
    }
}
