import AppKit
import Foundation

/// Renders the HideOnBush app icon — a minimal two-leaf sprout — into an
/// `.iconset` directory.
///
/// Usage: icongen <output-iconset-dir>
@main
enum IconGen {
    /// (filename, pixel size) entries required for a macOS `.iconset`.
    private static let variants: [(String, Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    static func main() {
        guard CommandLine.arguments.count == 2 else {
            FileHandle.standardError.write(Data("usage: icongen <output-iconset-dir>\n".utf8))
            exit(2)
        }
        let outputDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

        for (name, size) in variants {
            let data = renderPNG(pixels: size)
            let url = outputDir.appendingPathComponent(name)
            do {
                try data.write(to: url)
            } catch {
                FileHandle.standardError.write(Data("failed to write \(name): \(error)\n".utf8))
                exit(1)
            }
        }
        print("Rendered \(variants.count) icon variants to \(outputDir.path)")
    }

    // MARK: - Rendering

    private static func renderPNG(pixels: Int) -> Data {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            fatalError("could not allocate bitmap rep")
        }
        rep.size = NSSize(width: pixels, height: pixels)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        drawIcon(in: NSRect(x: 0, y: 0, width: CGFloat(pixels), height: CGFloat(pixels)))
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.representation(using: .png, properties: [:]) else {
            fatalError("could not encode PNG")
        }
        return data
    }

    // MARK: - Drawing

    private static func drawIcon(in rect: NSRect) {
        let n = rect.width

        // Rounded-square background with a transparent margin.
        let margin = n * 0.085
        let bg = rect.insetBy(dx: margin, dy: margin)
        let radius = bg.width * 0.2237
        let bgPath = NSBezierPath(roundedRect: bg, xRadius: radius, yRadius: radius)

        // Clean, soft background.
        NSColor(srgbRed: 0.933, green: 0.953, blue: 0.902, alpha: 1.0).setFill()
        bgPath.fill()

        NSGraphicsContext.saveGraphicsState()
        bgPath.addClip()

        let w = bg.width
        func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
            NSColor(srgbRed: r, green: g, blue: b, alpha: a)
        }
        func P(_ fx: CGFloat, _ fy: CGFloat) -> NSPoint {
            NSPoint(x: bg.minX + fx * w, y: bg.minY + fy * bg.height)
        }
        func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> NSBezierPath {
            let rp = r * w
            return NSBezierPath(ovalIn: NSRect(
                x: bg.minX + cx * w - rp, y: bg.minY + cy * bg.height - rp,
                width: rp * 2, height: rp * 2))
        }

        // Soft ground shadow.
        col(0.24, 0.36, 0.22, 0.16).setFill()
        NSBezierPath(ovalIn: NSRect(
            x: bg.minX + 0.22 * w, y: bg.minY + 0.075 * bg.height,
            width: 0.56 * w, height: 0.07 * bg.height)).fill()

        // Organic, asymmetric bush silhouette (lumpy outline, single shape).
        // Centered overall, but with an asymmetric, finely-lumped natural edge.
        let lumps: [(CGFloat, CGFloat, CGFloat)] = [
            (0.500, 0.495, 0.255),  // core
            (0.400, 0.445, 0.190),
            (0.605, 0.470, 0.200),
            (0.500, 0.580, 0.180),
            (0.440, 0.700, 0.130),  // top
            (0.550, 0.715, 0.145),  // peak (right of center)
            (0.665, 0.680, 0.120),
            (0.350, 0.635, 0.115),
            (0.745, 0.570, 0.120),  // right side
            (0.785, 0.485, 0.088),
            (0.715, 0.395, 0.110),
            (0.420, 0.305, 0.140),  // bottom
            (0.565, 0.300, 0.150),
            (0.665, 0.345, 0.110),
            (0.315, 0.380, 0.105),
            (0.245, 0.500, 0.105),  // left side
            (0.285, 0.605, 0.090),
            (0.275, 0.405, 0.090),
            (0.490, 0.770, 0.065),  // fine accents for a leafy edge
            (0.710, 0.645, 0.065),
            (0.205, 0.470, 0.065),
            (0.620, 0.250, 0.072),
            (0.360, 0.255, 0.070),
        ]
        let bush = NSBezierPath()
        for lump in lumps { bush.append(circle(lump.0, lump.1, lump.2)) }
        bush.windingRule = .nonZero

        NSGraphicsContext.saveGraphicsState()
        bush.addClip()

        // Smooth vertical base shading: lighter top → deeper bottom.
        if let base = NSGradient(starting: col(0.357, 0.694, 0.376),
                                 ending: col(0.169, 0.510, 0.263)) {
            base.draw(in: bush.bounds, angle: -90)
        } else {
            col(0.275, 0.620, 0.318).setFill()
            bush.fill()
        }

        // Soft radial shadow pooling at the base (no hard edges).
        if let shade = NSGradient(colors: [col(0.106, 0.380, 0.196, 0.42),
                                           col(0.106, 0.380, 0.196, 0.0)]) {
            shade.draw(fromCenter: P(0.50, 0.18), radius: 0,
                       toCenter: P(0.50, 0.18), radius: 0.52 * w, options: [])
        }

        // Subtle darker dapples for natural, matte foliage depth.
        if let dapple = NSGradient(colors: [col(0.118, 0.404, 0.212, 0.26),
                                            col(0.118, 0.404, 0.212, 0.0)]) {
            dapple.draw(fromCenter: P(0.33, 0.36), radius: 0,
                        toCenter: P(0.33, 0.36), radius: 0.22 * w, options: [])
            dapple.draw(fromCenter: P(0.70, 0.40), radius: 0,
                        toCenter: P(0.70, 0.40), radius: 0.20 * w, options: [])
        }

        // Gentle, matte highlight on the upper foliage (no glossy ball look).
        if let glow = NSGradient(colors: [col(0.561, 0.812, 0.486, 0.30),
                                          col(0.561, 0.812, 0.486, 0.0)]) {
            glow.draw(fromCenter: P(0.47, 0.63), radius: 0,
                      toCenter: P(0.47, 0.63), radius: 0.30 * w, options: [])
        }

        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.restoreGraphicsState()
    }
}
