import Foundation

/// SplitMix64: small, fast, and the same sequence for the same seed on every machine, which is what makes a recipe
/// draw the same picture every time.
struct RNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0 ..< 1.
    mutating func unit() -> Float {
        Float(next() >> 40) / Float(1 << 24)
    }

    mutating func uniform(_ low: Float, _ high: Float) -> Float {
        low + (high - low) * unit()
    }

    /// low ..< high.
    mutating func int(_ low: Int, _ high: Int) -> Int {
        low + Int(next() % UInt64(high - low))
    }
}

/// Value noise on a `freq` × `freq` grid that wraps, read with Catmull-Rom between grid points: smooth, and as
/// contrasty as the grid it is read from.
struct ValueNoise: Sendable {
    private let freq: Int
    private let grid: [Float]

    init(freq: Int, rng: inout RNG) {
        self.freq = freq
        grid = (0 ..< freq * freq).map { _ in rng.unit() }
    }

    @inline(__always) func callAsFunction(_ x: Float, _ y: Float) -> Float {
        let fx = x * Float(freq), fy = y * Float(freq)
        let ix = Int(fx.rounded(.down)), iy = Int(fy.rounded(.down))
        let tx = fx - Float(ix), ty = fy - Float(iy)
        var rows = SIMD4<Float>()
        for j in 0 ..< 4 {
            let row = wrap(iy + j - 1) * freq
            rows[j] = Self.catmullRom(
                grid[row + wrap(ix - 1)], grid[row + wrap(ix)], grid[row + wrap(ix + 1)], grid[row + wrap(ix + 2)], tx
            )
        }
        return Self.catmullRom(rows[0], rows[1], rows[2], rows[3], ty)
    }

    @inline(__always) private func wrap(_ i: Int) -> Int {
        let m = i % freq
        return m < 0 ? m + freq : m
    }

    @inline(__always) private static func catmullRom(
        _ p0: Float, _ p1: Float, _ p2: Float, _ p3: Float, _ t: Float
    ) -> Float {
        let a = -0.5 * p0 + 1.5 * p1 - 1.5 * p2 + 0.5 * p3
        let b = p0 - 2.5 * p1 + 2 * p2 - 0.5 * p3
        let c = -0.5 * p0 + 0.5 * p2
        return ((a * t + b) * t + c) * t + p1
    }
}

/// Octaves of value noise, each twice the frequency and half the weight of the one before, normalised to 0…1.
struct FBM: Sendable {
    private let octaves: [ValueNoise]
    private let total: Float

    init(freq: Int, octaves count: Int, rng: inout RNG) {
        var octaves: [ValueNoise] = []
        for i in 0 ..< count {
            octaves.append(ValueNoise(freq: freq << i, rng: &rng))
        }
        self.octaves = octaves
        total = (0 ..< count).reduce(0) { sum, i in sum + pow(0.5, Float(i)) }
    }

    @inline(__always) func callAsFunction(_ x: Float, _ y: Float) -> Float {
        var value: Float = 0, amp: Float = 1
        for octave in octaves {
            value += amp * octave(x, y)
            amp *= 0.5
        }
        return value / total
    }
}

/// A hash of a grid cell and a seed to 0 ..< 1, for grain: no state, so any pixel can be drawn on any thread.
@inline(__always) func hash(_ x: Int32, _ y: Int32, _ seed: UInt32) -> Float {
    var h = UInt32(bitPattern: x) &* 0x8DA6_B343 ^ UInt32(bitPattern: y) &* 0xD816_3841 ^ seed &* 0xCB1A_B31F
    h ^= h >> 15
    h &*= 0x2C1B_3C6D
    h ^= h >> 12
    h &*= 0x297A_2D39
    h ^= h >> 15
    return Float(h >> 8) / Float(1 << 24)
}
