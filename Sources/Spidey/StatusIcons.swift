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
        case .ironMan:
            drawIronManEmblem()
        }
    }

    // Iron Man facing us: helmet over squared shoulders. The silhouette is
    // filled first, then the faceplate groove, armor seams, and reactor ring
    // are knocked out with destination-out strokes so the panel lines read
    // like the real helmet while staying template-friendly.
    private static func drawIronManEmblem() {
        let body = NSBezierPath()
        body.windingRule = .evenOdd
        body.append(ironHelmetPath())
        for slit in ironEyeSlitPaths() { body.append(slit) }
        body.append(ironMouthPath())
        body.append(ironBustPath())
        body.append(ironReactorPath())
        body.fill()

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.setBlendMode(.destinationOut)
        let groove = ironFaceplateGroovePath()
        groove.lineWidth = 0.4
        groove.stroke()
        for seam in ironShoulderSeamPaths() {
            seam.lineWidth = 0.4
            seam.stroke()
        }
        let ring = NSBezierPath(ovalIn: NSRect(x: 7.4, y: 1.8, width: 3.2, height: 3.2))
        ring.lineWidth = 0.35
        ring.stroke()
        context.restoreGState()
    }

    // Helmet: rounded crown, temple flare, angular chamfered jaw.
    static func ironHelmetPath() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 5.6, y: 7.6))
        path.line(to: NSPoint(x: 7.2, y: 6.9))
        path.line(to: NSPoint(x: 10.8, y: 6.9))
        path.line(to: NSPoint(x: 12.4, y: 7.6))
        path.line(to: NSPoint(x: 13.0, y: 9.6))
        path.curve(to: NSPoint(x: 13.5, y: 12.0), controlPoint1: NSPoint(x: 13.4, y: 10.3), controlPoint2: NSPoint(x: 13.5, y: 11.1))
        path.curve(to: NSPoint(x: 9.0, y: 16.4), controlPoint1: NSPoint(x: 13.5, y: 14.9), controlPoint2: NSPoint(x: 11.6, y: 16.4))
        path.curve(to: NSPoint(x: 4.5, y: 12.0), controlPoint1: NSPoint(x: 6.4, y: 16.4), controlPoint2: NSPoint(x: 4.5, y: 14.9))
        path.curve(to: NSPoint(x: 5.0, y: 9.6), controlPoint1: NSPoint(x: 4.5, y: 11.1), controlPoint2: NSPoint(x: 4.6, y: 10.3))
        path.close()
        return path
    }

    // The groove separating the faceplate from the helmet shell.
    static func ironFaceplateGroovePath() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 5.9, y: 8.2))
        path.line(to: NSPoint(x: 6.3, y: 11.9))
        path.curve(to: NSPoint(x: 9.0, y: 13.4), controlPoint1: NSPoint(x: 6.6, y: 12.9), controlPoint2: NSPoint(x: 7.5, y: 13.4))
        path.curve(to: NSPoint(x: 11.7, y: 11.9), controlPoint1: NSPoint(x: 10.5, y: 13.4), controlPoint2: NSPoint(x: 11.4, y: 12.9))
        path.line(to: NSPoint(x: 12.1, y: 8.2))
        return path
    }

    // Angled eye slits, higher at the outer corners like the movie helmets.
    static func ironEyeSlitPaths() -> [NSBezierPath] {
        func slit(mirrored: Bool) -> NSBezierPath {
            func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
                NSPoint(x: mirrored ? 18 - x : x, y: y)
            }
            let path = NSBezierPath()
            path.move(to: point(6.1, 11.7))
            path.line(to: point(8.4, 11.3))
            path.line(to: point(8.4, 10.6))
            path.line(to: point(6.3, 10.7))
            path.close()
            return path
        }
        return [slit(mirrored: false), slit(mirrored: true)]
    }

    // Thin mouth slot low on the faceplate.
    static func ironMouthPath() -> NSBezierPath {
        NSBezierPath(roundedRect: NSRect(x: 7.8, y: 8.1, width: 2.4, height: 0.45), xRadius: 0.2, yRadius: 0.2)
    }

    // Shoulders and chest with an angular collar notch under the helmet.
    static func ironBustPath() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 2.0, y: 1.0))
        path.line(to: NSPoint(x: 2.6, y: 4.2))
        path.curve(to: NSPoint(x: 4.6, y: 5.8), controlPoint1: NSPoint(x: 2.8, y: 5.1), controlPoint2: NSPoint(x: 3.5, y: 5.8))
        path.line(to: NSPoint(x: 7.3, y: 5.8))
        path.line(to: NSPoint(x: 7.9, y: 5.0))
        path.line(to: NSPoint(x: 10.1, y: 5.0))
        path.line(to: NSPoint(x: 10.7, y: 5.8))
        path.line(to: NSPoint(x: 13.4, y: 5.8))
        path.curve(to: NSPoint(x: 15.4, y: 4.2), controlPoint1: NSPoint(x: 14.5, y: 5.8), controlPoint2: NSPoint(x: 15.2, y: 5.1))
        path.line(to: NSPoint(x: 16.0, y: 1.0))
        path.close()
        return path
    }

    // Seams splitting the pauldrons from the chest plate.
    static func ironShoulderSeamPaths() -> [NSBezierPath] {
        func seam(mirrored: Bool) -> NSBezierPath {
            func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
                NSPoint(x: mirrored ? 18 - x : x, y: y)
            }
            let path = NSBezierPath()
            path.move(to: point(6.3, 5.8))
            path.line(to: point(5.6, 1.0))
            return path
        }
        return [seam(mirrored: false), seam(mirrored: true)]
    }

    // The reactor core; a knocked-out ring around it suggests the housing.
    static func ironReactorPath() -> NSBezierPath {
        NSBezierPath(ovalIn: NSRect(x: 8.0, y: 2.4, width: 2.0, height: 2.0))
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
