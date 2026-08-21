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
            drawSasukeFigure()
        }
    }

    // Sasuke as a chibi figure: a wide mass of hair over a small body with one
    // hand on his hip. The hair is a solid silhouette with the face knocked out
    // of it and the eyes filled back in, so the figure keeps its shape at menu
    // bar size and still works as a template image.
    private static func drawSasukeFigure() {
        // Torso and sandals are filled; the arms and legs are stroked with round
        // caps, so the limbs come out as soft capsules instead of hand-built
        // outlines with hard corners.
        NSBezierPath(roundedRect: NSRect(x: 6.8, y: 6.4, width: 4.4, height: 3.4), xRadius: 0.75, yRadius: 0.75).fill()
        for sandal in sasukeSandalPaths() { sandal.fill() }
        for limb in sasukeLimbPaths() {
            limb.path.lineWidth = limb.width
            limb.path.lineCapStyle = .round
            limb.path.lineJoinStyle = .round
            limb.path.stroke()
        }

        // Non-zero, not even-odd: neighbouring spikes overlap where the hair
        // sweeps, and even-odd would punch holes through them.
        let hair = sasukeHairPath()
        hair.windingRule = .nonZero
        hair.fill()

        // Only the eyes and the belt are cut out. Knocking the whole face out
        // leaves a pale mask floating in the hair, which reads as a skull rather
        // than as him; a solid figure with two lit eyes keeps the shape bold.
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.setBlendMode(.destinationOut)
        sasukeEyePaths().forEach { $0.fill() }
        let belt = NSBezierPath()
        belt.move(to: NSPoint(x: 6.8, y: 6.6))
        belt.line(to: NSPoint(x: 11.2, y: 6.6))
        belt.lineWidth = 0.4
        belt.stroke()
        context.restoreGState()

        // The knot he ties the rope belt with, put back over the cut line.
        NSBezierPath(ovalIn: NSRect(x: 8.5, y: 6.1, width: 1.0, height: 1.0)).fill()
    }

    // The head, which is nearly all hair: a big smooth bang framing each side of
    // the face, and a jagged crown that sweeps up and back to his left.
    static func sasukeHairPath() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 5.6, y: 8.8))
        // Up the outside of the near bang to the temple, the widest part.
        path.curve(to: NSPoint(x: 3.6, y: 12.6), controlPoint1: NSPoint(x: 4.4, y: 10.4), controlPoint2: NSPoint(x: 3.5, y: 11.2))
        let crown: [NSPoint] = [
            NSPoint(x: 5.0, y: 13.6), NSPoint(x: 3.4, y: 15.0),
            NSPoint(x: 5.4, y: 15.4), NSPoint(x: 5.8, y: 17.3),
            NSPoint(x: 7.4, y: 16.4), NSPoint(x: 8.8, y: 17.8),
            NSPoint(x: 10.4, y: 16.6), NSPoint(x: 12.2, y: 17.5),
            NSPoint(x: 12.6, y: 15.7), NSPoint(x: 14.8, y: 15.2),
            NSPoint(x: 13.6, y: 13.8), NSPoint(x: 15.2, y: 12.4),
            NSPoint(x: 13.4, y: 11.6),
        ]
        for point in crown { path.line(to: point) }
        // Down the outside of the far bang.
        path.curve(to: NSPoint(x: 12.4, y: 8.8), controlPoint1: NSPoint(x: 13.3, y: 10.4), controlPoint2: NSPoint(x: 13.0, y: 9.6))
        // The jaw arcs up between the bang tips, so the bangs hang past it and
        // over his collar the way they do on the figure.
        path.curve(to: NSPoint(x: 5.6, y: 8.8), controlPoint1: NSPoint(x: 11.4, y: 10.0), controlPoint2: NSPoint(x: 6.6, y: 10.0))
        path.close()
        return path
    }

    // The opening his face shows through when the head is drawn in colour for
    // the theme entrance: full cheeks down to a soft chin, with his centre
    // parting dipping between the eyes. The menu bar figure stays solid, so
    // this shape is cut for the portrait rather than for the silhouette.
    static func sasukeFacePath() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 6.7, y: 13.4))
        path.curve(to: NSPoint(x: 9.0, y: 10.1), controlPoint1: NSPoint(x: 6.6, y: 11.8), controlPoint2: NSPoint(x: 7.5, y: 10.1))
        path.curve(to: NSPoint(x: 11.3, y: 13.4), controlPoint1: NSPoint(x: 10.5, y: 10.1), controlPoint2: NSPoint(x: 11.4, y: 11.8))
        path.line(to: NSPoint(x: 10.7, y: 14.1))
        path.line(to: NSPoint(x: 9.0, y: 13.2))
        path.line(to: NSPoint(x: 7.3, y: 14.1))
        path.close()
        return path
    }

    // Angled almond eyes, big the way a chibi's are but still slanting down
    // toward his nose. No mouth: a dark one on a light face turns into a skull
    // once the figure is down at menu bar size.
    static func sasukeEyePaths() -> [NSBezierPath] {
        [false, true].map { mirrored in
            func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
                NSPoint(x: mirrored ? 18 - x : x, y: y)
            }
            let path = NSBezierPath()
            path.move(to: point(7.45, 12.4))
            path.curve(to: point(8.8, 11.75), controlPoint1: point(8.0, 13.2), controlPoint2: point(8.6, 12.5))
            path.curve(to: point(7.45, 12.4), controlPoint1: point(8.4, 11.2), controlPoint2: point(7.6, 11.4))
            path.close()
            return path
        }
    }

    // His sandals. The legs are stroked down into these, so the join is hidden.
    static func sasukeSandalPaths() -> [NSBezierPath] {
        [false, true].map { mirrored in
            let x: CGFloat = mirrored ? 9.2 : 6.1
            return NSBezierPath(roundedRect: NSRect(x: x, y: 0.5, width: 2.7, height: 1.3), xRadius: 0.45, yRadius: 0.45)
        }
    }

    // Stubby capsule limbs. The near arm bends out and back in to his hip,
    // leaving a wedge of daylight that gives the pose away at a glance.
    static func sasukeLimbPaths() -> [(path: NSBezierPath, width: CGFloat)] {
        func line(_ points: [NSPoint]) -> NSBezierPath {
            let path = NSBezierPath()
            path.move(to: points[0])
            for point in points.dropFirst() { path.line(to: point) }
            return path
        }
        return [
            (line([NSPoint(x: 7.7, y: 6.8), NSPoint(x: 7.7, y: 2.1)]), 1.9),
            (line([NSPoint(x: 10.3, y: 6.8), NSPoint(x: 10.3, y: 2.1)]), 1.9),
            (line([NSPoint(x: 6.9, y: 9.3), NSPoint(x: 4.9, y: 8.0), NSPoint(x: 6.5, y: 6.8)]), 1.1),
            (line([NSPoint(x: 11.1, y: 9.3), NSPoint(x: 12.4, y: 8.0), NSPoint(x: 12.4, y: 6.7)]), 1.1),
        ]
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
