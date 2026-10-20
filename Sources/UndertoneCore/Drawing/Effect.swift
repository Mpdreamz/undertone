import Foundation
import simd

/// A treatment over the whole picture, on top of any style, that a random pick can choose: the effects other than
/// grain and the vignette. Which are on, and their settings, are `Effects`.
public enum Effect: String, CaseIterable, Codable, Sendable {
    case none, dither, halftone, glass, bloom, leak, paper, posterize

    public var title: String {
        switch self {
        case .none: "None"
        case .leak: "Light Leak"
        default: rawValue.capitalized
        }
    }

    public var summary: String {
        switch self {
        case .none: "None"
        case .dither: "Ordered dithering to a few levels, like an old screen"
        case .halftone: "Dots sized by colour, like print"
        case .glass: "Reeded glass in front of the picture"
        case .bloom: "Bright parts glow"
        case .leak: "A warm film light leak from one edge"
        case .paper: "Paper fibres under the colour"
        case .posterize: "Hard bands of lightness"
        }
    }

    /// The effects a random pick chooses from, and that the settings list after grain and the vignette.
    public static var selectable: [Effect] {
        allCases.filter { $0 != .none }
    }

    /// Reeded glass: vertical flutes, each showing a magnified slice of what is behind it, with a soft highlight along
    /// one edge and shade along the other.
    static func glass(_ shader: @escaping Shader, _ glass: Effects.Glass, frame: Frame) -> Shader {
        let flute = max(glass.width, 4) * frame.scale * frame.pixel // in v units, which ux shares
        let squeeze = 1 - min(max(glass.strength, 0), 0.95)
        let aspect = frame.aspect
        return { px in
            let f = px.ux / flute
            let k = f.rounded(.down), t = f - k
            let ux = (k + 0.5 + (t - 0.5) * squeeze) * flute
            var c = shader(Pixel(u: ux / aspect, v: px.v, ux: ux))
            c *= 0.9 + 0.12 * cos((t - 0.35) * .pi)
            let highlight = exp(-((t - 0.12) / 0.05) * ((t - 0.12) / 0.05)) * 0.1
            return c + RGB(repeating: highlight)
        }
    }

    /// Halftone: a rotated grid of dots, each the colour of the picture at its centre, bigger the further that colour
    /// is from the base, on the base.
    static func halftone(_ shader: @escaping Shader, _ halftone: Effects.Halftone, palette: Palette, frame: Frame)
        -> Shader
    {
        let cell = max(halftone.spacing, 2) * frame.scale * frame.pixel
        let edge = frame.pixel * 1.2
        let base = palette.base, aspect = frame.aspect
        let angle = halftone.angle * .pi / 180
        let (s, c) = (sin(angle), cos(angle))
        return { px in
            // Into the rotated grid, to the cell's centre, and back.
            let rx = px.ux * c + px.v * s, ry = -px.ux * s + px.v * c
            let cx = ((rx / cell).rounded(.down) + 0.5) * cell, cy = ((ry / cell).rounded(.down) + 0.5) * cell
            let ux = cx * c - cy * s, v = cx * s + cy * c
            let color = shader(Pixel(u: ux / aspect, v: v, ux: ux))
            let strength = min(simd_length(color - base) / 0.9, 1)
            let radius = cell * 0.62 * sqrt(strength)
            let d = hypot(rx - cx, ry - cy)
            let ink = base + (color - base) * 1.25
            return mix(base, ink.clamped, smooth(radius + edge, radius - edge, d))
        }
    }

    /// The per-pixel effects that are on, after the vignette and bloom and before grain, in a fixed order: posterize,
    /// paper, light leak, dither.
    struct Finish {
        let effects: Effects
        let isDark: Bool
        let cell: Float
        let leaks: [(cx: Float, cy: Float, rx: Float, ry: Float, color: RGB)]
        let fibres: FBM

        init(_ effects: Effects, seed: UInt64, frame: Frame, isDark: Bool) {
            self.effects = effects
            self.isDark = isDark
            cell = max(frame.scale, 1)
            // A generator of its own, so adding an effect leaves the style's picture as it was.
            var rng = RNG(seed: seed ^ 0x5EED_E77E_C700_0000)
            let fromLeft = rng.unit() < 0.5
            let edgeX: Float = fromLeft ? -0.05 : frame.aspect + 0.05
            // Warmth 1 is amber, 0 is rose.
            let warmth = min(max(effects.leak?.warmth ?? 1, 0), 1)
            leaks = [
                (edgeX, rng.uniform(0.15, 0.85), 0.55, 0.7, mix(RGB(1, 0.35, 0.5), RGB(1, 0.45, 0.15), warmth)),
                (edgeX, rng.uniform(0.1, 0.9), 0.25, 0.35, mix(RGB(1, 0.62, 0.75), RGB(1, 0.75, 0.35), warmth)),
            ]
            fibres = FBM(freq: 48, octaves: 3, rng: &rng)
        }

        /// Grain over dithering would undo it.
        var allowsGrain: Bool {
            effects.dither == nil
        }

        var isEmpty: Bool {
            effects.posterize == nil && effects.paper == nil && effects.leak == nil && effects.dither == nil
        }

        @inline(__always) func callAsFunction(_ color: RGB, x: Int, y: Int, ux: Float, v: Float) -> RGB {
            var color = color
            if let posterize = effects.posterize {
                // Light pictures live in the top of the range, so they get bands four times as narrow.
                var lab = OkLab.from(color.clamped)
                let band: Float = 1 / Float(max(posterize.bands, 2) * (isDark ? 1 : 4))
                lab.x = ((lab.x / band).rounded(.down) + 0.5) * band
                color = OkLab.to(lab)
            }
            if let paper = effects.paper {
                let fibre = fibres(ux * 0.5, v * 0.5) - 0.5
                let speck = UndertoneCore
                    .hash(Int32(Float(x) / cell), Int32(Float(y) / cell), 77) > 0.99 ? 1 : 0 as Float
                color *= 1 - paper.strength * (0.12 * fibre + 0.06 * speck)
            }
            if let leak = effects.leak {
                var light = RGB(repeating: 0)
                for l in leaks {
                    let dx = (ux - l.cx) / l.rx, dy = (v - l.cy) / l.ry
                    light += l.color * exp(-(dx * dx + dy * dy)) * (isDark ? 0.55 : 0.35) * leak.strength
                }
                // Screen on a dark picture; on a light one, which screen would barely touch, a warm tint.
                color = isDark
                    ? .white - (.white - color.clamped) * (.white - simd_min(light, .white))
                    : mix(color, color * RGB(1, 0.72, 0.5), min(simd_reduce_max(light) * 1.4, 1))
            }
            if let dither = effects.dither {
                let size = cell * max(dither.cell, 1)
                let bx = Int(Float(x) / size) & 7, by = Int(Float(y) / size) & 7
                let threshold = (Float(Self.bayer[by * 8 + bx]) + 0.5) / 64
                let levels = Float(min(max(dither.levels, 2), 16))
                color = ((color.clamped * (levels - 1)) + RGB(repeating: threshold)).rounded(.down) / (levels - 1)
            }
            return color
        }

        private static let bayer: [UInt8] = [
            0, 32, 8, 40, 2, 34, 10, 42, 48, 16, 56, 24, 50, 18, 58, 26,
            12, 44, 4, 36, 14, 46, 6, 38, 60, 28, 52, 20, 62, 30, 54, 22,
            3, 35, 11, 43, 1, 33, 9, 41, 51, 19, 59, 27, 49, 17, 57, 25,
            15, 47, 7, 39, 13, 45, 5, 37, 63, 31, 55, 23, 61, 29, 53, 21,
        ]
    }

    /// Bloom, over the whole buffer: the bright parts (on a dark picture) or the picture itself (on a light one),
    /// blurred wide on a small copy and laid back on top.
    static func bloom(
        _ buffer: UnsafeMutablePointer<RGB>, width: Int, height: Int, isDark: Bool, _ bloom: Effects.Bloom
    ) {
        let step = max(height / 200, 1)
        let w = (width + step - 1) / step, h = (height + step - 1) / step
        var small = [RGB](repeating: .black, count: w * h)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let c = buffer[y * width + x]
                let bright = isDark ? simd_max(c - RGB(repeating: bloom.threshold), RGB(repeating: 0)) * 1.8 : c
                small[(y / step) * w + x / step] += bright / Float(step * step)
            }
        }
        // Three box blurs each way: close to a Gaussian about a tenth of the height across.
        let radius = max(h / 28, 1)
        for _ in 0 ..< 3 {
            small = boxBlur(small, w, h, radius, horizontal: true)
            small = boxBlur(small, w, h, radius, horizontal: false)
        }
        for y in 0 ..< height {
            for x in 0 ..< width {
                let g = sample(small, w, h, (Float(x) + 0.5) / Float(step) - 0.5, (Float(y) + 0.5) / Float(step) - 0.5)
                let c = buffer[y * width + x]
                buffer[y * width + x] = isDark
                    ? c + g * bloom.strength
                    : mix(c, simd_max(c, g), min(bloom.strength, 1))
            }
        }
    }

    private static func boxBlur(_ src: [RGB], _ w: Int, _ h: Int, _ r: Int, horizontal: Bool) -> [RGB] {
        var out = src
        let (lines, length) = horizontal ? (h, w) : (w, h)
        for line in 0 ..< lines {
            func at(_ i: Int) -> Int {
                let i = min(max(i, 0), length - 1)
                return horizontal ? line * w + i : i * w + line
            }
            var sum = RGB(repeating: 0)
            for i in -r ... r {
                sum += src[at(i)]
            }
            for i in 0 ..< length {
                out[at(i)] = sum / Float(2 * r + 1)
                sum += src[at(i + r + 1)] - src[at(i - r)]
            }
        }
        return out
    }

    private static func sample(_ s: [RGB], _ w: Int, _ h: Int, _ x: Float, _ y: Float) -> RGB {
        let x = min(max(x, 0), Float(w - 1)), y = min(max(y, 0), Float(h - 1))
        let x0 = Int(x), y0 = Int(y), x1 = min(x0 + 1, w - 1), y1 = min(y0 + 1, h - 1)
        let tx = x - Float(x0), ty = y - Float(y0)
        let top = mix(s[y0 * w + x0], s[y0 * w + x1], tx), bottom = mix(s[y1 * w + x0], s[y1 * w + x1], tx)
        return mix(top, bottom, ty)
    }
}
