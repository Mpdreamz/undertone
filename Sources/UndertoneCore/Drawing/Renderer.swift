import CoreGraphics
import Foundation
import simd

/// Everything that decides what a picture looks like. The same recipe at the same size draws the same pixels.
public struct Recipe: Hashable, Codable, Sendable {
    public var style: Style
    public var tonality: Tonality
    public var appearance: Appearance
    public var seed: UInt64
    /// Strength of the film grain, 0 for none; 0.035 is subtle, 0.06 is plainly there.
    public var grain: Float

    public init(style: Style, tonality: Tonality, appearance: Appearance, seed: UInt64, grain: Float = 0.035) {
        self.style = style
        self.tonality = tonality
        self.appearance = appearance
        self.seed = seed
        self.grain = grain
    }
}

/// A drawn picture: 8-bit RGBA rows, opaque.
public struct Picture: Sendable {
    public let width: Int
    public let height: Int
    public let pixels: [UInt8]

    public func cgImage() -> CGImage? {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    public func png() -> Data? {
        cgImage().flatMap(Composer.png)
    }
}

public enum Renderer {
    /// Draw `recipe` at `width` × `height` pixels, `scale` pixels to the point (2 on a Retina display): the shapes
    /// follow the picture's size, grain and lines follow points, so a picture looks the same on any display.
    public static func render(_ recipe: Recipe, width: Int, height: Int, scale: Float = 1) -> Picture {
        precondition(width > 0 && height > 0, "a picture needs pixels")
        let frame = Frame(aspect: Float(width) / Float(height), pixel: 1 / Float(height), scale: scale)
        let palette = recipe.tonality.palette(recipe.appearance)
        var rng = RNG(seed: recipe.seed)
        let shader = recipe.style.shader(palette, &rng, frame)
        let finish = Finish(recipe: recipe, frame: frame, isDark: palette.isDark)

        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        pixels.withUnsafeMutableBufferPointer { buffer in
            let out = Output(base: buffer.baseAddress!)
            // Bands of rows, more than there are cores, so a slow band does not hold the rest up.
            let bands = min(height, ProcessInfo.processInfo.activeProcessorCount * 8)
            DispatchQueue.concurrentPerform(iterations: bands) { band in
                let rows = height * band / bands ..< height * (band + 1) / bands
                for y in rows {
                    let v = (Float(y) + 0.5) / Float(height)
                    for x in 0 ..< width {
                        let u = (Float(x) + 0.5) / Float(width)
                        let c = finish(shader(Pixel(u: u, v: v, ux: u * frame.aspect)), x: x, y: y, u: u, v: v)
                        let i = (y * width + x) * 4
                        out.base[i] = UInt8(c.x * 255 + 0.5)
                        out.base[i + 1] = UInt8(c.y * 255 + 0.5)
                        out.base[i + 2] = UInt8(c.z * 255 + 0.5)
                    }
                }
            }
        }
        return Picture(width: width, height: height, pixels: pixels)
    }
}

/// The buffer, shared by the bands: each writes only its own rows.
private struct Output: @unchecked Sendable {
    let base: UnsafeMutablePointer<UInt8>
}

/// What every style gets on top: a vignette, then grain, then clamped to 0…1.
private struct Finish {
    let grain: Float
    let seed: UInt32
    let vignette: Float
    /// Pixels to one grain cell: a point.
    let cell: Float

    init(recipe: Recipe, frame: Frame, isDark: Bool) {
        grain = recipe.grain
        seed = UInt32(truncatingIfNeeded: recipe.seed ^ (recipe.seed >> 32))
        vignette = isDark ? 0.35 : 0.08
        cell = max(frame.scale, 1)
    }

    @inline(__always) func callAsFunction(_ color: RGB, x: Int, y: Int, u: Float, v: Float) -> RGB {
        let d = hypot((u - 0.5) * 1.2, v - 0.5)
        var c = mix(color, .black, smooth(0.4, 1.0, d) * vignette)
        if grain > 0 {
            c += RGB(repeating: noise(Float(x) / cell, Float(y) / cell) * grain)
        }
        return c.clamped
    }

    /// Monochrome grain about one point across: hashed per point and blended between neighbours, centred on 0 with a
    /// spread near 0.5, like the prototype's softened Gaussian.
    @inline(__always) private func noise(_ x: Float, _ y: Float) -> Float {
        let ix = Int32(x.rounded(.down)), iy = Int32(y.rounded(.down))
        let tx = x - Float(ix), ty = y - Float(iy)
        func at(_ i: Int32, _ j: Int32) -> Float {
            hash(i, j, seed) + hash(i, j, seed &+ 1) + hash(i, j, seed &+ 2) - 1.5
        }
        let top = at(ix, iy) + (at(ix + 1, iy) - at(ix, iy)) * tx
        let bottom = at(ix, iy + 1) + (at(ix + 1, iy + 1) - at(ix, iy + 1)) * tx
        return (top + (bottom - top) * ty) * (cell > 1 ? 1.4 : 1)
    }
}
