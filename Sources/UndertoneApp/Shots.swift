import AppKit
import SwiftUI
import UndertoneCore

/// The docs' and landing page's images of the app itself: the settings window, rendered through AppKit in a window
/// that is never shown, and a laptop drawn around Undertone's own pictures to show the notch and the corners. Every
/// picture in them is drawn by the renderer from a fixed recipe; nothing is read from this Mac's screen or settings.
/// `mise run shots` runs this (`UNDERTONE_SHOTS=<folder>`) after rendering the gallery with `undertone render`.
@MainActor
enum Shots {
    static func run(into folder: URL) {
        do {
            let shots = folder.appendingPathComponent("shots")
            try settings(into: shots.appendingPathComponent("app"))
            try laptops(into: shots)
            try mark(into: folder.appendingPathComponent("png"))
        } catch {
            FileHandle.standardError.write(Data("shots: \(error)\n".utf8))
            exit(1)
        }
    }

    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    // MARK: The settings window

    private static func settings(into folder: URL) throws {
        var settings = UndertoneCore.Settings()
        settings.tonality = .locked(.dusk)
        settings.interval = .daily
        settings.hideNotch = true
        settings.roundCorners = true
        settings.showText = true
        settings.lockScreenMotion = true
        for appearance in Appearance.allCases {
            let view = SettingsView(settings: settings, onChange: { _ in })
            let image = try hosted(view, appearance: appearance == .dark ? .darkAqua : .aqua)
            try write(image, to: folder.appendingPathComponent("settings-\(appearance.rawValue).png"))
        }
    }

    private static func hosted(_ view: some View, appearance: NSAppearance.Name) throws -> CGImage {
        let hosting = NSHostingView(rootView: view)
        hosting.safeAreaRegions = []
        hosting.appearance = NSAppearance(named: appearance)
        hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            throw Failure(description: "no bitmap for the settings window")
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let image = rep.cgImage else { throw Failure(description: "no image of the settings window") }
        return trimmed(image)
    }

    /// Without the transparent rows SwiftUI leaves above and below a grouped form.
    private static func trimmed(_ image: CGImage) -> CGImage {
        guard let context = CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else { return image }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let opaque = (0 ..< image.height).filter { row in
            (0 ..< image.width).contains { pixels[(row * image.width + $0) * 4 + 3] > 0 }
        }
        guard let first = opaque.first, let last = opaque.last else { return image }
        return image.cropping(to: CGRect(x: 0, y: first, width: image.width, height: last - first + 1)) ?? image
    }

    // MARK: Laptops

    /// A 14-inch MacBook Pro's screen, in points.
    static let screen = CGSize(width: 1512, height: 982)
    static let menuBar: CGFloat = 37
    static let scale: CGFloat = 1.5

    private static func laptops(into folder: URL) throws {
        let aurora = Recipe(style: .aurora, tonality: .aurora, appearance: .dark, seed: 19, grain: 0.04)
        let landing = folder.appendingPathComponent("landing")
        try jpeg(laptop(aurora, notch: true, corners: true), to: landing.appendingPathComponent("hero.jpg"))
        try jpeg(
            laptop(
                Recipe(style: .silk, tonality: .dusk, appearance: .light, seed: 9, grain: 0.04),
                notch: true, corners: true, title: ("workstation", "you · macOS 26")
            ),
            to: landing.appendingPathComponent("title.jpg")
        )

        // The notch, without and with the strip: the middle of the top edge.
        let overlays = folder.appendingPathComponent("overlays")
        let waves = Recipe(style: .flow, tonality: .dusk, appearance: .light, seed: 7, grain: 0.035)
        let notchCrop = CGRect(x: screen.width / 2 - 360, y: 0, width: 720, height: 200)
        for on in [false, true] {
            let image = try laptop(waves, notch: on, corners: on, bezel: false)
            try jpeg(crop(image, notchCrop), to: overlays.appendingPathComponent("notch-\(on ? "on" : "off").jpg"))
        }
        // A window tiled flush to the top left corner, without and with rounded corners.
        let dunes = Recipe(style: .mesh, tonality: .citrus, appearance: .light, seed: 4, grain: 0.035)
        let cornerCrop = CGRect(x: 0, y: 0, width: 220, height: 124)
        for on in [false, true] {
            let image = try laptop(dunes, notch: true, corners: on, window: true, bezel: false)
            try jpeg(crop(image, cornerCrop), to: overlays.appendingPathComponent("corners-\(on ? "on" : "off").jpg"))
        }
    }

    /// The picture as the screen shows it, a menu bar over it, the notch, optionally a window and the laptop's bezel.
    private static func laptop(
        _ recipe: Recipe, notch: Bool, corners: Bool, title: (String, String)? = nil, window: Bool = false,
        bezel: Bool = true
    ) throws -> CGImage {
        let width = Int(screen.width * scale), height = Int(screen.height * scale)
        let picture = Renderer.render(recipe, width: width, height: height, scale: Float(scale))
        let overlay = Overlay(
            strip: notch ? Int(menuBar * scale) : 0,
            cornerRadius: corners ? Int(CGFloat(Overlay.windowCorner) * scale) : 0,
            title: title?.0 ?? "", subtitle: title?.1 ?? "", scale: Float(scale)
        )
        guard let desktop = Composer.compose(picture, overlay, appearance: recipe.appearance) else {
            throw Failure(description: "nothing drawn")
        }

        let pad: CGFloat = bezel ? 26 : 0
        let size = CGSize(width: screen.width + pad * 2, height: screen.height + pad * 2)
        let image = NSImage(size: size, flipped: true) { _ in
            let context = NSGraphicsContext.current!.cgContext
            if bezel {
                // The landing page's background, so the bezel's rounded corners sit on it (a JPEG has no alpha).
                NSColor(red: 8 / 255, green: 9 / 255, blue: 11 / 255, alpha: 1).setFill()
                NSRect(origin: .zero, size: size).fill()
                NSColor(white: 0.07, alpha: 1).setFill()
                NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 34, yRadius: 34).fill()
            }
            let screenRect = NSRect(x: pad, y: pad, width: screen.width, height: screen.height)
            context.saveGState()
            NSBezierPath(roundedRect: screenRect, xRadius: bezel ? 12 : 0, yRadius: bezel ? 12 : 0).addClip()
            // Flipped: draw the picture the right way up.
            context.translateBy(x: 0, y: screenRect.maxY + screenRect.minY)
            context.scaleBy(x: 1, y: -1)
            context.draw(desktop, in: screenRect)
            context.restoreGState()
            if window { drawWindow(in: screenRect) }
            drawMenuBar(in: screenRect, onBlack: notch, dark: recipe.appearance == .dark)
            drawNotch(in: screenRect)
            return true
        }
        var rect = CGRect(origin: .zero, size: size)
        guard let cg = image.cgImage(
            forProposedRect: &rect, context: nil, hints: [.ctm: NSAffineTransform(transform: .init(scale: scale))]
        ) else { throw Failure(description: "no laptop image") }
        return cg
    }

    private static func drawNotch(in screen: NSRect) {
        let width: CGFloat = 196, height: CGFloat = 33, radius: CGFloat = 10
        let x = screen.midX - width / 2, y = screen.minY
        let path = NSBezierPath()
        path.move(to: NSPoint(x: x - 6, y: y))
        path.curve(
            to: NSPoint(x: x, y: y + 6),
            controlPoint1: NSPoint(x: x - 1, y: y),
            controlPoint2: NSPoint(x: x, y: y + 1)
        )
        path.line(to: NSPoint(x: x, y: y + height - radius))
        path.curve(
            to: NSPoint(x: x + radius, y: y + height), controlPoint1: NSPoint(x: x, y: y + height),
            controlPoint2: NSPoint(x: x, y: y + height)
        )
        path.line(to: NSPoint(x: x + width - radius, y: y + height))
        path.curve(
            to: NSPoint(x: x + width, y: y + height - radius), controlPoint1: NSPoint(x: x + width, y: y + height),
            controlPoint2: NSPoint(x: x + width, y: y + height)
        )
        path.line(to: NSPoint(x: x + width, y: y + 6))
        path.curve(
            to: NSPoint(x: x + width + 6, y: y), controlPoint1: NSPoint(x: x + width, y: y + 1),
            controlPoint2: NSPoint(x: x + width + 1, y: y)
        )
        path.close()
        NSColor.black.setFill()
        path.fill()
    }

    private static func drawMenuBar(in screen: NSRect, onBlack: Bool, dark: Bool) {
        let color: NSColor = onBlack || dark ? .white : NSColor(white: 0.1, alpha: 1)
        let shadow = NSShadow()
        shadow.shadowColor = onBlack ? .clear : NSColor(white: 0, alpha: dark ? 0.35 : 0)
        shadow.shadowBlurRadius = 3
        let y = screen.minY + menuBar / 2
        var x = screen.minX + 22
        if let apple = symbol("apple.logo", size: 15, color: color) {
            apple.draw(
                at: NSPoint(x: x, y: y - apple.size.height / 2),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
            x += apple.size.width + 22
        }
        for (index, title) in ["Finder", "File", "Edit", "View", "Go", "Window", "Help"].enumerated() {
            let text = NSAttributedString(string: title, attributes: [
                .font: NSFont.systemFont(ofSize: 13.5, weight: index == 0 ? .bold : .regular),
                .foregroundColor: color, .shadow: shadow,
            ])
            text.draw(at: NSPoint(x: x, y: y - text.size().height / 2))
            x += text.size().width + 20
        }
        let clock = NSAttributedString(string: "Tue 20 Oct  10:41", attributes: [
            .font: NSFont.systemFont(ofSize: 13.5), .foregroundColor: color, .shadow: shadow,
        ])
        var right = screen.maxX - 20 - clock.size().width
        clock.draw(at: NSPoint(x: right, y: y - clock.size().height / 2))
        for name in ["magnifyingglass", "battery.75percent", "wifi", "circle.lefthalf.filled"] {
            guard let icon = symbol(name, size: 14, color: color) else { continue }
            right -= icon.size.width + 18
            icon.draw(
                at: NSPoint(x: right, y: y - icon.size.height / 2),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
        }
    }

    /// A Finder-like window tiled flush against the left edge, just under the menu bar.
    private static func drawWindow(in screen: NSRect) {
        let frame = NSRect(x: screen.minX, y: screen.minY + menuBar, width: 900, height: screen.height - menuBar)
        // A toolbar window's corner, as macOS 26 draws it: 26 points in the continuous curve.
        let shape = NSBezierPath(cgPath: ContinuousCorners.path(frame, radius: 26))
        NSColor(white: 0.16, alpha: 1).setFill()
        shape.fill()
        NSGraphicsContext.current?.cgContext.saveGState()
        shape.addClip()
        NSColor(white: 0.21, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: 52)).fill()
        NSGraphicsContext.current?.cgContext.restoreGState()
        for (i, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
            color.setFill()
            NSBezierPath(ovalIn: NSRect(
                x: frame.minX + 20 + CGFloat(i) * 20,
                y: frame.minY + 20,
                width: 12,
                height: 12
            ))
            .fill()
        }
        NSColor(white: 1, alpha: 0.08).setFill()
        for row in 0 ..< 8 {
            NSBezierPath(
                roundedRect: NSRect(x: frame.minX + 24, y: frame.minY + 80 + CGFloat(row) * 34, width: 360, height: 14),
                xRadius: 4, yRadius: 4
            ).fill()
        }
    }

    private static func symbol(_ name: String, size: CGFloat, color: NSColor) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
            .applying(.init(paletteColors: [color]))
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
    }

    // MARK: The mark

    /// Undertone's mark: a disc of one picture, its left half drawn light and its right half dark.
    private static func mark(into folder: URL) throws {
        let recipe = Recipe(style: .mesh, tonality: .ember, appearance: .dark, seed: 3, grain: 0)
        for size in [32, 64, 180, 512] {
            let dark = Renderer.render(recipe, width: size, height: size)
            var light = recipe
            light.appearance = .light
            let bright = Renderer.render(light, width: size, height: size)
            guard let darkImage = dark.cgImage(), let lightImage = bright.cgImage(), let context = CGContext(
                data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { throw Failure(description: "no mark") }
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let inset = rect.insetBy(dx: CGFloat(size) * 0.04, dy: CGFloat(size) * 0.04)
            context.addEllipse(in: inset)
            context.clip()
            context.draw(darkImage, in: rect)
            context.clip(to: CGRect(x: 0, y: 0, width: CGFloat(size) / 2, height: CGFloat(size)))
            context.draw(lightImage, in: rect)
            guard let image = context.makeImage() else { throw Failure(description: "no mark") }
            try write(image, to: folder.appendingPathComponent("undertone-\(size).png"))
        }
    }

    // MARK: Files

    private static func crop(_ image: CGImage, _ rect: CGRect) throws -> CGImage {
        let pixels = CGRect(
            x: rect.minX * scale,
            y: rect.minY * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        guard let cropped = image.cropping(to: pixels.integral) else { throw Failure(description: "crop failed") }
        return cropped
    }

    private static func write(_ image: CGImage, to url: URL) throws {
        guard let data = Composer.png(image) else { throw Failure(description: "no png for \(url.lastPathComponent)") }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    private static func jpeg(_ image: CGImage, to url: URL) throws {
        guard let data = Composer.jpeg(image)
        else { throw Failure(description: "no jpeg for \(url.lastPathComponent)") }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }
}
