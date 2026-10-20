import Foundation
import simd

/// A treatment over the whole picture, on top of any style. Some read the picture somewhere else (glass, halftone),
/// one reads its neighbourhood (bloom), the rest change each pixel's colour.
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

    /// Effects that sample the picture elsewhere wrap the style's shader.
    func wrap(_ shader: @escaping Shader, palette: Palette, frame: Frame) -> Shader {
        switch self {
        case .glass: Self.glass(shader, frame: frame)
        case .halftone: Self.halftone(shader, palette: palette, frame: frame)
        default: shader
        }
    }

    /// Reeded glass: vertical flutes about 36 points wide, each showing a magnified slice of what is behind it, with
    /// a soft highlight along one edge and shade along the other.
    private static func glass(_ shader: @escaping Shader, frame: Frame) -> Shader {
        let flute = 36 * frame.scale * frame.pixel // in v units, which ux shares
        let aspect = frame.aspect
        return { px in
            let f = px.ux / flute
            let k = f.rounded(.down), t = f - k
            let ux = (k + 0.5 + (t - 0.5) * 0.45) * flute
            var c = shader(Pixel(u: ux / aspect, v: px.v, ux: ux))
            c *= 0.9 + 0.12 * cos((t - 0.35) * .pi)
            let highlight = exp(-((t - 0.12) / 0.05) * ((t - 0.12) / 0.05)) * 0.1
            return c + RGB(repeating: highlight)
        }
    }

    /// Halftone: a grid at 45° of dots about 8 points apart, each the colour of the picture at its centre, bigger the
    /// further that colour is from the base, on the base.
    private static func halftone(_ shader: @escaping Shader, palette: Palette, frame: Frame) -> Shader {
        let cell = 8 * frame.scale * frame.pixel
        let edge = frame.pixel * 1.2
        let base = palette.base, aspect = frame.aspect
        let (s, c) = (sin(Float.pi / 4), cos(Float.pi / 4))
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

    /// Per-pixel effects, after the vignette and before grain.
    struct Finish {
        let effect: Effect
        let isDark: Bool
        let cell: Float
        let leaks: [(cx: Float, cy: Float, rx: Float, ry: Float, color: RGB)]
        let fibres: FBM

        init(_ effect: Effect, seed: UInt64, frame: Frame, isDark: Bool) {
            self.effect = effect
            self.isDark = isDark
            cell = max(frame.scale, 1)
            // A generator of its own, so adding an effect leaves the style's picture as it was.
            var rng = RNG(seed: seed ^ 0x5EED_E77E_C700_0000)
            let fromLeft = rng.unit() < 0.5
            let edgeX: Float = fromLeft ? -0.05 : frame.aspect + 0.05
            leaks = [
                (edgeX, rng.uniform(0.15, 0.85), 0.55, 0.7, RGB(1, 0.45, 0.15)),
                (edgeX, rng.uniform(0.1, 0.9), 0.25, 0.35, RGB(1, 0.75, 0.35)),
            ]
            fibres = FBM(freq: 48, octaves: 3, rng: &rng)
        }

        /// Grain over dithering would undo it.
        var allowsGrain: Bool {
            effect != .dither
        }

        @inline(__always) func callAsFunction(_ color: RGB, x: Int, y: Int, ux: Float, v: Float) -> RGB {
            switch effect {
            case .leak:
                var light = RGB(repeating: 0)
                for l in leaks {
                    let dx = (ux - l.cx) / l.rx, dy = (v - l.cy) / l.ry
                    light += l.color * exp(-(dx * dx + dy * dy)) * (isDark ? 0.55 : 0.35)
                }
                // Screen on a dark picture; on a light one, which screen would barely touch, a warm tint.
                return isDark
                    ? .white - (.white - color.clamped) * (.white - simd_min(light, .white))
                    : mix(color, color * RGB(1, 0.72, 0.5), min(simd_reduce_max(light) * 1.4, 1))
            case .paper:
                let fibre = fibres(ux * 0.5, v * 0.5) - 0.5
                let speck = UndertoneCore
                    .hash(Int32(Float(x) / cell), Int32(Float(y) / cell), 77) > 0.99 ? 1 : 0 as Float
                return color * (1 - 0.12 * fibre - 0.06 * speck)
            case .posterize:
                // Light pictures live in the top of the range, so they get narrower bands.
                var lab = OkLab.from(color.clamped)
                let band: Float = isDark ? 1 / 7 : 1 / 28
                lab.x = ((lab.x / band).rounded(.down) + 0.5) * band
                return OkLab.to(lab)
            case .dither:
                let bx = Int(Float(x) / cell) & 7, by = Int(Float(y) / cell) & 7
                let threshold = (Float(Self.bayer[by * 8 + bx]) + 0.5) / 64
                let levels: Float = 4
                return ((color.clamped * (levels - 1)) + RGB(repeating: threshold)).rounded(.down) / (levels - 1)
            default:
                return color
            }
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
    static func bloom(_ buffer: UnsafeMutablePointer<RGB>, width: Int, height: Int, isDark: Bool) {
        let step = max(height / 200, 1)
        let w = (width + step - 1) / step, h = (height + step - 1) / step
        var small = [RGB](repeating: .black, count: w * h)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let c = buffer[y * width + x]
                let bright = isDark ? simd_max(c - RGB(repeating: 0.45), RGB(repeating: 0)) * 1.8 : c
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
                buffer[y * width + x] = isDark ? c + g * 0.6 : mix(c, simd_max(c, g), 0.6)
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
