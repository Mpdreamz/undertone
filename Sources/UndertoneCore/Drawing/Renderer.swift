import CoreGraphics
import Foundation
import simd

/// Everything that decides what a picture looks like. The same recipe at the same size draws the same pixels.
public struct Recipe: Hashable, Codable, Sendable {
    public var style: Style
    public var tonality: Tonality
    public var appearance: Appearance
    public var seed: UInt64
    /// What goes over the style: the vignette and grain unless told otherwise.
    public var effects: Effects

    public init(
        style: Style, tonality: Tonality, appearance: Appearance, seed: UInt64, effects: Effects = .standard
    ) {
        self.style = style
        self.tonality = tonality
        self.appearance = appearance
        self.seed = seed
        self.effects = effects
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

    /// The pixels of an image, as RGBA rows.
    public init?(_ image: CGImage) {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = pixels.withUnsafeMutableBytes { bytes in
            CGContext(
                data: bytes.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ).map { context in
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
                return true
            } ?? false
        }
        guard drawn else { return nil }
        self.init(width: image.width, height: image.height, pixels: pixels)
    }

    public init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    public func png() -> Data? {
        cgImage().flatMap(Composer.png)
    }
}

public enum Renderer {
    /// Draw `recipe` at `width` × `height` pixels, `scale` pixels to the point (2 on a Retina display): the shapes
    /// follow the picture's size, grain and lines follow points, so a picture looks the same on any display.
    ///
    /// `motion` moves it: every style has parts that drift on a loop, and the still picture is `.still`. `threads`
    /// caps how many cores it uses (nil: all of them), for work in the background.
    public static func render(
        _ recipe: Recipe, width: Int, height: Int, scale: Float = 1, motion: Motion = .still, threads: Int? = nil
    ) -> Picture {
        precondition(width > 0 && height > 0, "a picture needs pixels")
        let frame = Frame(
            aspect: Float(width) / Float(height), pixel: 1 / Float(height), scale: scale, motion: motion
        )
        let palette = recipe.tonality.palette(recipe.appearance)
        var rng = RNG(seed: recipe.seed)
        let effects = recipe.effects
        // Glass, then halftone: both read the picture somewhere else, so they wrap the style.
        var shader = recipe.style.shader(palette, &rng, frame)
        if let glass = effects.glass { shader = Effect.glass(shader, glass, frame: frame) }
        if let halftone = effects.halftone {
            shader = Effect.halftone(shader, halftone, palette: palette, frame: frame)
        }
        let finish = Finish(recipe: recipe, frame: frame, isDark: palette.isDark)
        let effect = Effect.Finish(effects, seed: recipe.seed, frame: frame, isDark: palette.isDark)
        // Bands of rows, more than there are cores, so a slow band does not hold the rest up; or, capped, one band per
        // thread.
        let bands = min(height, threads.map { max($0, 1) } ?? ProcessInfo.processInfo.activeProcessorCount * 8)

        // The picture in floating point, so bloom can read it whole before anything is rounded.
        var colors = [RGB](repeating: .black, count: width * height)
        colors.withUnsafeMutableBufferPointer { buffer in
            let out = Shared(base: buffer.baseAddress!)
            DispatchQueue.concurrentPerform(iterations: bands) { band in
                for y in height * band / bands ..< height * (band + 1) / bands {
                    let v = (Float(y) + 0.5) / Float(height)
                    for x in 0 ..< width {
                        let u = (Float(x) + 0.5) / Float(width)
                        out.base[y * width + x] = finish.vignette(
                            shader(Pixel(u: u, v: v, ux: u * frame.aspect)),
                            u: u,
                            v: v
                        )
                    }
                }
            }
            if let bloom = effects.bloom {
                Effect.bloom(buffer.baseAddress!, width: width, height: height, isDark: palette.isDark, bloom)
            }
        }

        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        pixels.withUnsafeMutableBufferPointer { buffer in
            let out = Shared(base: buffer.baseAddress!)
            colors.withUnsafeBufferPointer { colors in
                let source = SharedConstant(base: colors.baseAddress!)
                DispatchQueue.concurrentPerform(iterations: bands) { band in
                    for y in height * band / bands ..< height * (band + 1) / bands {
                        let v = (Float(y) + 0.5) / Float(height)
                        for x in 0 ..< width {
                            let ux = (Float(x) + 0.5) / Float(width) * frame.aspect
                            var c = effect(source.base[y * width + x], x: x, y: y, ux: ux, v: v)
                            if effect.allowsGrain { c = finish.grain(c, x: x, y: y) }
                            c = c.clamped
                            let i = (y * width + x) * 4
                            out.base[i] = UInt8(c.x * 255 + 0.5)
                            out.base[i + 1] = UInt8(c.y * 255 + 0.5)
                            out.base[i + 2] = UInt8(c.z * 255 + 0.5)
                        }
                    }
                }
            }
        }
        return Picture(width: width, height: height, pixels: pixels)
    }
}

/// A buffer shared by the bands: each writes only its own rows.
private struct Shared<T>: @unchecked Sendable {
    let base: UnsafeMutablePointer<T>
}

private struct SharedConstant<T>: @unchecked Sendable {
    let base: UnsafePointer<T>
}

/// What every style gets on top: a vignette, and (after any effect) grain.
private struct Finish {
    let grain: Float
    let seed: UInt32
    let vignette: Float
    /// Pixels to one grain cell: a point.
    let cell: Float

    init(recipe: Recipe, frame: Frame, isDark: Bool) {
        grain = recipe.effects.grain ?? 0
        seed = UInt32(truncatingIfNeeded: recipe.seed ^ (recipe.seed >> 32))
        vignette = (isDark ? 0.35 : 0.08) * (recipe.effects.vignette ?? 0)
        cell = max(frame.scale, 1)
    }

    @inline(__always) func vignette(_ color: RGB, u: Float, v: Float) -> RGB {
        let d = hypot((u - 0.5) * 1.2, v - 0.5)
        return mix(color, .black, smooth(0.4, 1.0, d) * vignette)
    }

    @inline(__always) func grain(_ color: RGB, x: Int, y: Int) -> RGB {
        guard grain > 0 else { return color }
        return color + RGB(repeating: noise(Float(x) / cell, Float(y) / cell) * grain)
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
