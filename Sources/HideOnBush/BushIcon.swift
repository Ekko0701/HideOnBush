import AppKit
import Foundation

/// Shared "simple bush" (수풀) shape used by both the menu bar status item
/// and the generated app bundle icon. The base stays planted while the leafy
/// bumps sway, so a small sway angle reads as wind on the foliage.
enum BushIcon {
    /// A foliage bump in unit space (origin bottom-left, y up, 0...1).
    private struct Bump {
        let cx: CGFloat
        let cy: CGFloat
        let r: CGFloat
    }

    /// The planted point the foliage sways around.
    private static let pivot = CGPoint(x: 0.5, y: 0.16)

    /// Solid lower body of the bush, in unit space.
    private static let baseRect = CGRect(x: 0.16, y: 0.10, width: 0.68, height: 0.34)
    private static let baseCornerFraction: CGFloat = 0.14

    /// Overlapping leafy bumps that form the bushy top silhouette.
    private static let bumps: [Bump] = [
        Bump(cx: 0.28, cy: 0.480, r: 0.165),
        Bump(cx: 0.43, cy: 0.585, r: 0.185),
        Bump(cx: 0.60, cy: 0.565, r: 0.175),
        Bump(cx: 0.72, cy: 0.475, r: 0.155),
        Bump(cx: 0.505, cy: 0.640, r: 0.155),
    ]

    // MARK: - Mode colors

    static let personalColor = NSColor(srgbRed: 0.27, green: 0.67, blue: 0.36, alpha: 1.0)
    static let workColor = NSColor(srgbRed: 0.56, green: 0.56, blue: 0.58, alpha: 1.0)
    static let mixedColor = NSColor(srgbRed: 0.93, green: 0.62, blue: 0.17, alpha: 1.0)

    // MARK: - Path

    /// Builds the filled bush silhouette inside `rect`. `sway` (radians) rotates
    /// the leafy bumps around the planted base; pass `0` for a still bush.
    static func bushPath(in rect: NSRect, sway: CGFloat) -> NSBezierPath {
        let side = min(rect.width, rect.height)
        let path = NSBezierPath()

        // Planted base — does not sway.
        let body = NSRect(
            x: rect.minX + baseRect.minX * rect.width,
            y: rect.minY + baseRect.minY * rect.height,
            width: baseRect.width * rect.width,
            height: baseRect.height * rect.height
        )
        path.append(NSBezierPath(
            roundedRect: body,
            xRadius: baseCornerFraction * side,
            yRadius: baseCornerFraction * side
        ))

        // Swaying foliage — rotate each bump center around the pivot.
        let cosA = cos(sway)
        let sinA = sin(sway)
        for bump in bumps {
            let dx = bump.cx - pivot.x
            let dy = bump.cy - pivot.y
            let ux = pivot.x + dx * cosA - dy * sinA
            let uy = pivot.y + dx * sinA + dy * cosA
            let cx = rect.minX + ux * rect.width
            let cy = rect.minY + uy * rect.height
            let radius = bump.r * side
            path.append(NSBezierPath(ovalIn: NSRect(
                x: cx - radius,
                y: cy - radius,
                width: radius * 2,
                height: radius * 2
            )))
        }

        path.windingRule = .nonZero
        return path
    }

    // MARK: - Menu bar image

    /// A colored (non-template) bush image sized for the menu bar.
    static func statusImage(color: NSColor, sway: CGFloat, pointSize: CGFloat = 18) -> NSImage {
        let image = NSImage(
            size: NSSize(width: pointSize, height: pointSize),
            flipped: false
        ) { rect in
            let inset = NSRect(
                x: rect.minX + rect.width * 0.07,
                y: rect.minY + rect.height * 0.04,
                width: rect.width * 0.86,
                height: rect.height * 0.92
            )
            let path = bushPath(in: inset, sway: sway)
            color.setFill()
            path.fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
