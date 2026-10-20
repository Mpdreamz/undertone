import Foundation
import simd

/// A colour as sRGB components in 0…1. The styles do their arithmetic on these directly, as the prototype does; only
/// ramps mix in OkLab, where a gradient between two colours stays as bright and as saturated as its ends.
public typealias RGB = SIMD3<Float>

extension RGB {
    static let black = RGB(0, 0, 0)
    static let white = RGB(1, 1, 1)

    /// `#RRGGBB`.
    init(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = UInt32(digits, radix: 16) ?? 0
        self.init(Float((value >> 16) & 0xFF) / 255, Float((value >> 8) & 0xFF) / 255, Float(value & 0xFF) / 255)
    }

    var clamped: RGB {
        simd_clamp(self, .black, .white)
    }
}

@inline(__always) func mix(_ a: RGB, _ b: RGB, _ t: Float) -> RGB {
    a + (b - a) * t
}

/// Hermite smoothstep from `e0` to `e1`; `e0 > e1` runs it backwards (1 below, 0 above).
@inline(__always) func smooth(_ e0: Float, _ e1: Float, _ x: Float) -> Float {
    let t = min(max((x - e0) / (e1 - e0), 0), 1)
    return t * t * (3 - 2 * t)
}

/// Björn Ottosson's OkLab, from and to sRGB.
enum OkLab {
    static func from(_ c: RGB) -> SIMD3<Float> {
        let r = linear(c.x), g = linear(c.y), b = linear(c.z)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return SIMD3(
            0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        )
    }

    static func to(_ lab: SIMD3<Float>) -> RGB {
        let l = pow3(lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z)
        let m = pow3(lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z)
        let s = pow3(lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z)
        return RGB(
            gamma(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
            gamma(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
            gamma(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
        )
    }

    private static func pow3(_ x: Float) -> Float {
        x * x * x
    }

    private static func linear(_ c: Float) -> Float {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private static func gamma(_ c: Float) -> Float {
        let c = min(max(c, 0), 1)
        return c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
    }
}

/// Colours spread evenly over 0…1 and mixed in OkLab, looked up from a table: a style reads a ramp for every pixel.
struct Ramp: Sendable {
    private let table: [RGB]

    init(_ colors: [RGB], steps: Int = 512) {
        let labs = colors.map(OkLab.from)
        let last = Float(labs.count - 1)
        table = (0 ..< steps).map { i in
            let t = Float(i) / Float(steps - 1) * last
            let k = min(Int(t), labs.count - 2)
            let f = t - Float(k)
            return OkLab.to(labs[k] + (labs[k + 1] - labs[k]) * f)
        }
    }

    @inline(__always) func callAsFunction(_ t: Float) -> RGB {
        let x = min(max(t, 0), 1) * Float(table.count - 1)
        let i = min(Int(x), table.count - 2)
        return mix(table[i], table[i + 1], x - Float(i))
    }
}
