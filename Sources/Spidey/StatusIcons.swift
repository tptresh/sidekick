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

    // Sasuke standing in miniature: an oversized spiky head over a small
    // body with one hand on his hip. The hair is a solid silhouette with the
    // face knocked out of it and the eyes filled back in, so the figure keeps
    // its shape at menu bar size and still works as a template image.
    private static func drawSasukeFigure() {
        // Filled separately rather than as one even-odd path: the arms overlap
        // the torso, and even-odd would punch holes where they cross.
        sasukeBodyPaths().forEach { $0.fill() }

        // The face and eyes must sit wholly inside the hair outline: even-odd
        // counts nesting, so any part that strays outside fills instead of
        // cutting.
        let head = NSBezierPath()
        head.windingRule = .evenOdd
        head.append(sasukeHairPath())
        head.append(sasukeFacePath())
        for eye in sasukeEyePaths() { head.append(eye) }
        head.fill()

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.setBlendMode(.destinationOut)
        for seam in sasukeSeamPaths() {
            seam.lineWidth = 0.4
            seam.lineCapStyle = .round
            seam.stroke()
        }
        context.restoreGState()
    }

    // The whole head: a rounded jaw under a crown of spikes, with the two long
    // bangs dropping past the cheeks.
    static func sasukeHairPath() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 5.8, y: 11.0))
        path.curve(to: NSPoint(x: 9.0, y: 10.1), controlPoint1: NSPoint(x: 6.0, y: 10.5), controlPoint2: NSPoint(x: 7.4, y: 10.1))
        path.curve(to: NSPoint(x: 12.2, y: 11.0), controlPoint1: NSPoint(x: 10.6, y: 10.1), controlPoint2: NSPoint(x: 12.0, y: 10.5))
        // Spikes up the right side, over the crown, and back down the left.
        let spikes: [NSPoint] = [
            NSPoint(x: 13.6, y: 12.0), NSPoint(x: 12.6, y: 12.8),
            NSPoint(x: 15.1, y: 13.3), NSPoint(x: 13.3, y: 14.2),
            NSPoint(x: 15.3, y: 15.6), NSPoint(x: 12.9, y: 15.6),
            NSPoint(x: 14.0, y: 17.4), NSPoint(x: 11.5, y: 16.0),
            NSPoint(x: 10.9, y: 17.9), NSPoint(x: 9.2, y: 16.2),
            NSPoint(x: 7.4, y: 17.8), NSPoint(x: 6.6, y: 15.8),
            NSPoint(x: 4.4, y: 16.9), NSPoint(x: 5.5, y: 15.0),
            NSPoint(x: 3.0, y: 14.5), NSPoint(x: 5.1, y: 13.5),
            NSPoint(x: 3.4, y: 12.2), NSPoint(x: 5.3, y: 11.8),
        ]
        for point in spikes { path.line(to: point) }
        path.close()
        return path
    }

    // The opening the face shows through: bangs down each side and a fringe
    // that parts in the middle and dips between the eyes.
    static func sasukeFacePath() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 6.5, y: 11.4))
        path.line(to: NSPoint(x: 6.9, y: 13.4))
        path.line(to: NSPoint(x: 7.7, y: 15.4))
        path.line(to: NSPoint(x: 9.0, y: 14.5))
        path.line(to: NSPoint(x: 10.3, y: 15.4))
        path.line(to: NSPoint(x: 11.1, y: 13.4))
        path.line(to: NSPoint(x: 11.5, y: 11.4))
        path.curve(to: NSPoint(x: 6.5, y: 11.4), controlPoint1: NSPoint(x: 11.0, y: 10.8), controlPoint2: NSPoint(x: 7.0, y: 10.8))
        path.close()
        return path
    }

    // Narrow eyes set low on the face, slanting down toward the nose.
    static func sasukeEyePaths() -> [NSBezierPath] {
        func eye(mirrored: Bool) -> NSBezierPath {
            func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
                NSPoint(x: mirrored ? 18 - x : x, y: y)
            }
            let path = NSBezierPath()
            path.move(to: point(7.1, 13.5))
            path.line(to: point(8.6, 13.1))
            path.line(to: point(8.7, 12.5))
            path.line(to: point(7.2, 12.6))
            path.close()
            return path
        }
        return [eye(mirrored: false), eye(mirrored: true)]
    }

    // Torso, trousers, sandals and both arms, the near one cocked on his hip.
    static func sasukeBodyPaths() -> [NSBezierPath] {
        let torso = NSBezierPath()
        torso.move(to: NSPoint(x: 6.0, y: 10.6))
        torso.line(to: NSPoint(x: 12.0, y: 10.6))
        torso.line(to: NSPoint(x: 12.3, y: 5.3))
        torso.line(to: NSPoint(x: 5.7, y: 5.3))
        torso.close()

        let trousers = NSBezierPath()
        trousers.move(to: NSPoint(x: 5.8, y: 5.4))
        trousers.line(to: NSPoint(x: 12.2, y: 5.4))
        trousers.line(to: NSPoint(x: 11.9, y: 1.5))
        trousers.line(to: NSPoint(x: 6.1, y: 1.5))
        trousers.close()

        let sandals = [false, true].map { mirrored -> NSBezierPath in
            let x: CGFloat = mirrored ? 9.5 : 5.1
            return NSBezierPath(roundedRect: NSRect(x: x, y: 0.3, width: 3.4, height: 1.3), xRadius: 0.5, yRadius: 0.5)
        }

        // Hand on the hip: the forearm cuts back in to the waist, leaving a
        // wedge of daylight that gives the pose away at a glance.
        let hipArm = NSBezierPath()
        hipArm.move(to: NSPoint(x: 6.0, y: 10.5))
        hipArm.line(to: NSPoint(x: 4.5, y: 9.7))
        hipArm.line(to: NSPoint(x: 3.3, y: 7.6))
        hipArm.line(to: NSPoint(x: 3.7, y: 5.9))
        hipArm.line(to: NSPoint(x: 5.2, y: 5.0))
        hipArm.line(to: NSPoint(x: 6.4, y: 5.5))
        hipArm.line(to: NSPoint(x: 5.4, y: 6.2))
        hipArm.line(to: NSPoint(x: 4.5, y: 7.5))
        hipArm.line(to: NSPoint(x: 5.1, y: 9.1))
        hipArm.close()

        let hangingArm = NSBezierPath()
        hangingArm.move(to: NSPoint(x: 12.0, y: 10.5))
        hangingArm.line(to: NSPoint(x: 13.3, y: 9.7))
        hangingArm.line(to: NSPoint(x: 13.6, y: 6.3))
        hangingArm.line(to: NSPoint(x: 13.4, y: 4.4))
        hangingArm.line(to: NSPoint(x: 12.5, y: 4.4))
        hangingArm.line(to: NSPoint(x: 12.6, y: 6.3))
        hangingArm.line(to: NSPoint(x: 12.3, y: 9.7))
        hangingArm.close()

        return [torso, trousers] + sandals + [hipArm, hangingArm]
    }

    // Knocked out of the silhouette: the shirt collar, the sash at his waist,
    // the gap beside the hanging arm, and the split between the legs.
    static func sasukeSeamPaths() -> [NSBezierPath] {
        let collar = NSBezierPath()
        collar.move(to: NSPoint(x: 8.0, y: 10.6))
        collar.line(to: NSPoint(x: 9.0, y: 9.7))
        collar.line(to: NSPoint(x: 10.0, y: 10.6))

        let sash = NSBezierPath()
        sash.move(to: NSPoint(x: 5.8, y: 5.4))
        sash.line(to: NSPoint(x: 12.2, y: 5.4))

        let armGap = NSBezierPath()
        armGap.move(to: NSPoint(x: 12.3, y: 10.0))
        armGap.line(to: NSPoint(x: 12.5, y: 5.5))

        let legs = NSBezierPath()
        legs.move(to: NSPoint(x: 9.0, y: 1.6))
        legs.line(to: NSPoint(x: 9.0, y: 4.1))

        return [collar, sash, armGap, legs]
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
