import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// What goes over a drawn picture for one screen, in that screen's pixels.
public struct Overlay: Hashable, Codable, Sendable {
    /// A black strip across the top, the menu bar's height on a display with a notch; 0 for none.
    public var strip: Int = 0
    /// Black outside a rectangle with these rounded corners (below the strip); 0 for square.
    public var cornerRadius: Int = 0
    /// Centred text, and a smaller line under it; empty for none.
    public var title = ""
    public var subtitle = ""
    /// Pixels to a point, for the text's size.
    public var scale: Float = 1

    public init(strip: Int = 0, cornerRadius: Int = 0, title: String = "", subtitle: String = "", scale: Float = 1) {
        self.strip = strip
        self.cornerRadius = cornerRadius
        self.title = title
        self.subtitle = subtitle
        self.scale = scale
    }

    public var isEmpty: Bool {
        strip == 0 && cornerRadius == 0 && title.isEmpty && subtitle.isEmpty
    }
}

/// A picture with its overlay drawn on, ready to be written out.
public enum Composer {
    public static func compose(_ picture: Picture, _ overlay: Overlay, appearance: Appearance) -> CGImage? {
        guard let base = picture.cgImage() else { return nil }
        if overlay.isEmpty { return base }
        let width = picture.width, height = picture.height
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(base, in: bounds)

        // CoreGraphics counts from the bottom: the strip is at the top of the rectangle.
        if overlay.strip > 0 || overlay.cornerRadius > 0 {
            let visible = CGRect(x: 0, y: 0, width: width, height: height - max(overlay.strip, 0))
            let radius = CGFloat(min(overlay.cornerRadius, Int(min(visible.width, visible.height) / 2)))
            let path = CGMutablePath()
            path.addRect(bounds)
            path.addRoundedRect(in: visible, cornerWidth: radius, cornerHeight: radius)
            context.addPath(path)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fillPath(using: .evenOdd)
        }

        let dark = appearance == .dark
        let points = CGFloat(width) / CGFloat(max(overlay.scale, 1))
        let scale = CGFloat(max(overlay.scale, 1))
        let baseline = CGFloat(height) * 0.54
        if !overlay.title.isEmpty {
            let size = min(max(points * 0.05, 40), 120) * scale
            let line = Self.line(
                overlay.title, size: size, weight: 0.3, kern: 0, alpha: dark ? 0.92 : 0.88, dark: dark
            )
            Self.draw(line, centredAt: CGFloat(width) / 2, baseline: baseline, in: context)
        }
        if !overlay.subtitle.isEmpty {
            let size = min(max(points * 0.0146, 13), 32) * scale
            let line = Self.line(
                overlay.subtitle.uppercased(), size: size, weight: 0.23, kern: size * 0.08,
                alpha: dark ? 0.6 : 0.55, dark: dark
            )
            let gap = min(max(points * 0.029, 26), 64) * scale
            Self.draw(line, centredAt: CGFloat(width) / 2, baseline: baseline - gap, in: context)
        }
        return context.makeImage()
    }

    public static func png(_ image: CGImage) -> Data? {
        encode(image, as: .png)
    }

    /// For the docs and the landing page, where a grainy PNG would weigh megabytes.
    public static func jpeg(_ image: CGImage, quality: Double = 0.8) -> Data? {
        encode(image, as: .jpeg, properties: [kCGImageDestinationLossyCompressionQuality: quality])
    }

    private static func encode(_ image: CGImage, as type: UTType, properties: [CFString: Any] = [:]) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// The system font (SF Pro) at a weight between -1 and 1 (0.3 semibold, 0.23 medium).
    private static func line(
        _ text: String, size: CGFloat, weight: CGFloat, kern: CGFloat, alpha: CGFloat, dark: Bool
    ) -> CTLine {
        let system = CTFontCreateUIFontForLanguage(.system, size, nil) ?? CTFontCreateWithName(
            "Helvetica" as CFString,
            size,
            nil
        )
        let descriptor = CTFontDescriptorCreateCopyWithAttributes(
            CTFontCopyFontDescriptor(system),
            [kCTFontTraitsAttribute: [kCTFontWeightTrait: weight]] as CFDictionary
        )
        let font = CTFontCreateWithFontDescriptor(descriptor, size, nil)
        let color = dark ? CGColor(gray: 1, alpha: alpha) : CGColor(red: 0.08, green: 0.08, blue: 0.09, alpha: alpha)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
            NSAttributedString.Key(kCTKernAttributeName as String): kern,
        ]
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    }

    private static func draw(_ line: CTLine, centredAt x: CGFloat, baseline: CGFloat, in context: CGContext) {
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        context.textPosition = CGPoint(x: x - CGFloat(width) / 2, y: baseline)
        CTLineDraw(line, context)
    }
}

/// `{computer}`, `{user}`, `{os}` and `{host}` in a title, filled in from what the app knows about this Mac.
public enum Placeholders {
    public static func expand(_ template: String, _ values: [String: String]) -> String {
        values.reduce(template) { text, entry in text.replacingOccurrences(of: "{\(entry.key)}", with: entry.value) }
    }
}

/// A name for the file holding a recipe drawn at a size with an overlay: the same inputs, the same name, so a picture
/// already on disk is not drawn again, and a changed one gets a new name (the system caches pictures by file).
public enum Fingerprint {
    public static func of(_ recipe: Recipe, _ overlay: Overlay, width: Int, height: Int) -> String {
        struct Key: Encodable {
            let recipe: Recipe, overlay: Overlay, width: Int, height: Int
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = (try? encoder.encode(Key(recipe: recipe, overlay: overlay, width: width, height: height))) ?? Data()
        return String(format: "%016llx", Pick.fnv1a(String(decoding: data, as: UTF8.self)))
    }
}
