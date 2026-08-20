import AppKit

// Simple, iconic hero emblems drawn in code as filled silhouettes with cutouts.
// Rendered as template images so they adapt to light and dark menu bars.
enum StatusIcons {
    static func menuBarIcon(for theme: HeroTheme) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            path(for: theme).fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    // Larger tinted rendering used inside the panel and settings previews.
    static func watermark(for theme: HeroTheme, size: CGFloat, color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            color.setFill()
            let transform = NSAffineTransform()
            transform.scale(by: size / 18.0)
            transform.concat()
            path(for: theme).fill()
            return true
        }
    }

    // All shapes live in an 18x18 unit space, y pointing up.
    static func path(for theme: HeroTheme) -> NSBezierPath {
        switch theme {
        case .spiderman: return spideyMaskPath()
        case .batman: return batSymbolPath()
        case .ironman: return ironHelmetPath()
        }
    }

    // Round mask silhouette with the classic large sweeping eyes cut out.
    static func spideyMaskPath() -> NSBezierPath {
        let path = NSBezierPath()
        path.windingRule = .evenOdd
        path.append(NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: 16, height: 16)))
        path.append(spideyEyePath(mirrored: false))
        path.append(spideyEyePath(mirrored: true))
        return path
    }

    // One eye: pointed at the top outer corner, rounded at the bottom inner corner.
    private static func spideyEyePath(mirrored: Bool) -> NSBezierPath {
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: mirrored ? 18 - x : x, y: y)
        }
        let eye = NSBezierPath()
        eye.move(to: point(2.8, 13.0))
        // Outer edge sweeping down.
        eye.curve(to: point(8.3, 5.6), controlPoint1: point(1.8, 9.4), controlPoint2: point(4.2, 5.4))
        // Inner edge back up to the tip, bowing outward for a solid teardrop.
        eye.curve(to: point(2.8, 13.0), controlPoint1: point(10.2, 8.8), controlPoint2: point(6.2, 11.8))
        eye.close()
        return eye
    }

    // Classic wide bat: high wing tips, ears, scalloped bottom, center tail point.
    static func batSymbolPath() -> NSBezierPath {
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: y) }
        let path = NSBezierPath()
        // Left wing tip, then the top edge dipping into the notch before the ear.
        path.move(to: point(0.6, 13.6))
        path.curve(to: point(6.2, 11.8), controlPoint1: point(1.6, 12.0), controlPoint2: point(4.4, 11.4))
        // Left ear.
        path.line(to: point(6.9, 14.4))
        path.line(to: point(7.6, 12.2))
        // Head with a slight dip in the middle.
        path.curve(to: point(10.4, 12.2), controlPoint1: point(8.7, 11.8), controlPoint2: point(9.3, 11.8))
        // Right ear.
        path.line(to: point(11.1, 14.4))
        path.line(to: point(11.8, 11.8))
        // Top edge out to the high right wing tip.
        path.curve(to: point(17.4, 13.6), controlPoint1: point(13.6, 11.4), controlPoint2: point(16.4, 12.0))
        // Bottom edge: two scallops per wing, then the tail point, mirrored back.
        path.curve(to: point(12.2, 9.4), controlPoint1: point(15.8, 11.0), controlPoint2: point(13.6, 9.8))
        path.curve(to: point(10.0, 8.9), controlPoint1: point(11.5, 10.2), controlPoint2: point(10.5, 9.6))
        path.curve(to: point(9.0, 6.6), controlPoint1: point(9.6, 8.0), controlPoint2: point(9.2, 7.2))
        path.curve(to: point(8.0, 8.9), controlPoint1: point(8.8, 7.2), controlPoint2: point(8.4, 8.0))
        path.curve(to: point(5.8, 9.4), controlPoint1: point(7.5, 9.6), controlPoint2: point(6.5, 10.2))
        path.curve(to: point(0.6, 13.6), controlPoint1: point(4.4, 9.8), controlPoint2: point(2.2, 11.0))
        path.close()
        return path
    }

    // Helmet silhouette: rounded dome, tapered jaw, one horizontal visor slit cut out.
    static func ironHelmetPath() -> NSBezierPath {
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: y) }
        let path = NSBezierPath()
        path.windingRule = .evenOdd

        let helmet = NSBezierPath()
        // Chin.
        helmet.move(to: point(6.6, 2.8))
        helmet.line(to: point(11.4, 2.8))
        // Angular right jaw and cheek, then the side.
        helmet.line(to: point(13.8, 5.0))
        helmet.line(to: point(15.2, 8.2))
        helmet.line(to: point(15.2, 12.4))
        // Flat-ish dome.
        helmet.curve(to: point(9.0, 15.8), controlPoint1: point(15.2, 14.6), controlPoint2: point(12.2, 15.8))
        helmet.curve(to: point(2.8, 12.4), controlPoint1: point(5.8, 15.8), controlPoint2: point(2.8, 14.6))
        helmet.line(to: point(2.8, 8.2))
        // Angular left cheek and jaw back down to the chin.
        helmet.line(to: point(4.2, 5.0))
        helmet.close()
        path.append(helmet)

        // Visor slit.
        path.append(NSBezierPath(
            roundedRect: NSRect(x: 4.2, y: 9.4, width: 9.6, height: 1.7),
            xRadius: 0.85, yRadius: 0.85
        ))
        return path
    }
}
