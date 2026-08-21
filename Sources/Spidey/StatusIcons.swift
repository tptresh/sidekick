import AppKit

// Simple, iconic hero emblems drawn in code as filled silhouettes with cutouts.
// Rendered as template images so they adapt to light and dark menu bars.
enum StatusIcons {
    static func menuBarIcon(for theme: HeroTheme) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            draw(theme, color: .black)
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
            draw(theme, color: color)
            return true
        }
    }

    // All shapes live in an 18x18 unit space, y pointing up. The fill color
    // must already be set before calling.
    private static func draw(_ theme: HeroTheme, color: NSColor) {
        switch theme {
        case .spiderman:
            drawSpideyMask(color: color)
        case .batman:
            batSymbolPath().fill()
        case .sasuke:
            drawRinnegan()
        }
    }

    // Sasuke's Rinnegan: concentric rings around a small pupil, with the three
    // tomoe he carries on the innermost one. A badge like the other two
    // emblems, rather than a figure, so it still reads at 18 points; the
    // likeness lives in the theme entrance instead.
    private static func drawRinnegan() {
        for radius: CGFloat in [8.1, 6.3, 4.5] {
            let ring = rinneganRing(radius)
            ring.lineWidth = 0.85
            ring.stroke()
        }
        rinneganRing(1.15).fill()
        for tomoe in rinneganTomoePaths() { tomoe.fill() }
    }

    static func rinneganRing(_ radius: CGFloat) -> NSBezierPath {
        NSBezierPath(ovalIn: NSRect(
            x: 9.0 - radius, y: 9.0 - radius,
            width: radius * 2, height: radius * 2
        ))
    }

    // Three commas riding the inner ring, spaced a third of a turn apart.
    static func rinneganTomoePaths() -> [NSBezierPath] {
        (0..<3).map { index in
            let angle = CGFloat(index) * 120 + 90
            let transform = NSAffineTransform()
            transform.translateX(by: 9.0, yBy: 9.0)
            transform.rotate(byDegrees: angle)
            transform.translateX(by: -0.85, yBy: 2.55)
            transform.scale(by: 1.7)
            let path = tomoePath()
            path.transform(using: transform as AffineTransform)
            return path
        }
    }

    // One tomoe in a unit box: a round head trailing a tail that tapers away.
    private static func tomoePath() -> NSBezierPath {
        func quad(_ path: NSBezierPath, to end: NSPoint, control: NSPoint) {
            let start = path.currentPoint
            path.curve(
                to: end,
                controlPoint1: NSPoint(
                    x: start.x + 2.0 / 3.0 * (control.x - start.x),
                    y: start.y + 2.0 / 3.0 * (control.y - start.y)
                ),
                controlPoint2: NSPoint(
                    x: end.x + 2.0 / 3.0 * (control.x - end.x),
                    y: end.y + 2.0 / 3.0 * (control.y - end.y)
                )
            )
        }
        let path = NSBezierPath()
        path.appendArc(
            withCenter: NSPoint(x: 0.34, y: 0.66),
            radius: 0.32,
            startAngle: 90,
            endAngle: -125,
            clockwise: true
        )
        quad(path, to: NSPoint(x: 0.97, y: 0.04), control: NSPoint(x: 0.36, y: -0.04))
        quad(path, to: NSPoint(x: 0.34, y: 0.98), control: NSPoint(x: 0.82, y: 0.28))
        path.close()
        return path
    }

    // Line-art mask like the classic emblem: stroked rim, thin web, solid eyes.
    private static func drawSpideyMask(color: NSColor) {
        color.setStroke()

        let rim = NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: 16, height: 16))
        rim.lineWidth = 1.0
        rim.stroke()

        // Web: spokes and rings from between the eye tips, clipped to the disk.
        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(ovalIn: NSRect(x: 1.4, y: 1.4, width: 15.2, height: 15.2)).setClip()
        let center = NSPoint(x: 9.0, y: 10.2)
        for index in 0..<12 {
            let angle = CGFloat(index) * .pi / 6
            let spoke = NSBezierPath()
            spoke.move(to: center)
            spoke.line(to: NSPoint(
                x: center.x + cos(angle) * 10.5,
                y: center.y + sin(angle) * 10.5
            ))
            spoke.lineWidth = 0.35
            spoke.stroke()
        }
        for radius: CGFloat in [2.2, 4.4, 6.6] {
            let ring = NSBezierPath(ovalIn: NSRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            ))
            ring.lineWidth = 0.35
            ring.stroke()
        }
        NSGraphicsContext.current?.restoreGraphicsState()

        // Eyes: clear the web behind them, then stroke a bold outline, so they
        // read as clean white cutouts like the classic emblem.
        if let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            context.setBlendMode(.destinationOut)
            spideyEyePath(mirrored: false).fill()
            spideyEyePath(mirrored: true).fill()
            context.restoreGState()
        }
        for mirrored in [false, true] {
            let outline = spideyEyePath(mirrored: mirrored)
            outline.lineWidth = 1.1
            outline.stroke()
        }
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
}
