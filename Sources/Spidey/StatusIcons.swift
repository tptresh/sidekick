import AppKit

// Monochrome, cartoon style hero icons drawn in code.
// Rendered as template images so they adapt to light and dark menu bars.
enum StatusIcons {
    static func menuBarIcon(for theme: HeroTheme) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            switch theme {
            case .spiderman: drawSpideyMask(in: rect)
            case .batman: drawBatSymbol(in: rect)
            case .ironman: drawIronMask(in: rect)
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    // Big rounded mask outline, two large teardrop eyes, simple web lines.
    static func drawSpideyMask(in rect: NSRect) {
        let inset = rect.insetBy(dx: 1.5, dy: 1.0)
        let head = NSBezierPath(ovalIn: inset)
        head.lineWidth = 1.6
        head.stroke()

        // Web lines: one vertical, two horizontal arcs.
        let center = NSPoint(x: inset.midX, y: inset.midY)
        let vertical = NSBezierPath()
        vertical.move(to: NSPoint(x: center.x, y: inset.maxY))
        vertical.line(to: NSPoint(x: center.x, y: inset.minY))
        vertical.lineWidth = 0.9
        vertical.stroke()

        for offset: CGFloat in [-2.6, 2.6] {
            let arc = NSBezierPath()
            arc.move(to: NSPoint(x: inset.minX + 1.2, y: center.y + offset))
            arc.curve(
                to: NSPoint(x: inset.maxX - 1.2, y: center.y + offset),
                controlPoint1: NSPoint(x: center.x - 3, y: center.y + offset * 1.8),
                controlPoint2: NSPoint(x: center.x + 3, y: center.y + offset * 1.8)
            )
            arc.lineWidth = 0.9
            arc.stroke()
        }

        // Teardrop eyes, filled.
        drawSpideyEye(centerX: center.x - 3.4, rect: inset, mirrored: false)
        drawSpideyEye(centerX: center.x + 3.4, rect: inset, mirrored: true)
    }

    private static func drawSpideyEye(centerX: CGFloat, rect: NSRect, mirrored: Bool) {
        let eye = NSBezierPath()
        let sign: CGFloat = mirrored ? 1 : -1
        let top = NSPoint(x: centerX + sign * 1.6, y: rect.midY + 2.2)
        let bottom = NSPoint(x: centerX - sign * 0.4, y: rect.midY - 1.6)
        eye.move(to: top)
        eye.curve(
            to: bottom,
            controlPoint1: NSPoint(x: centerX + sign * 2.6, y: rect.midY + 0.2),
            controlPoint2: NSPoint(x: centerX + sign * 1.2, y: rect.midY - 1.6)
        )
        eye.curve(
            to: top,
            controlPoint1: NSPoint(x: centerX - sign * 1.8, y: rect.midY - 0.6),
            controlPoint2: NSPoint(x: centerX - sign * 0.6, y: rect.midY + 1.8)
        )
        eye.close()
        eye.fill()
    }

    // Classic winged bat silhouette.
    static func drawBatSymbol(in rect: NSRect) {
        let w = rect.width
        let h = rect.height
        let midY = rect.midY
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX + 0.5, y: midY))
        // Top edge with ears.
        path.curve(
            to: NSPoint(x: rect.midX - 1.8, y: midY + 2.2),
            controlPoint1: NSPoint(x: rect.minX + w * 0.22, y: midY + h * 0.30),
            controlPoint2: NSPoint(x: rect.midX - 3.6, y: midY + 1.4)
        )
        path.line(to: NSPoint(x: rect.midX - 1.3, y: midY + 4.4))
        path.line(to: NSPoint(x: rect.midX - 0.5, y: midY + 2.6))
        path.line(to: NSPoint(x: rect.midX + 0.5, y: midY + 2.6))
        path.line(to: NSPoint(x: rect.midX + 1.3, y: midY + 4.4))
        path.line(to: NSPoint(x: rect.midX + 1.8, y: midY + 2.2))
        path.curve(
            to: NSPoint(x: rect.maxX - 0.5, y: midY),
            controlPoint1: NSPoint(x: rect.midX + 3.6, y: midY + 1.4),
            controlPoint2: NSPoint(x: rect.maxX - w * 0.22, y: midY + h * 0.30)
        )
        // Bottom scalloped edge.
        path.curve(
            to: NSPoint(x: rect.midX + 2.0, y: midY - 1.8),
            controlPoint1: NSPoint(x: rect.maxX - w * 0.2, y: midY - h * 0.16),
            controlPoint2: NSPoint(x: rect.midX + 3.4, y: midY - 0.6)
        )
        path.curve(
            to: NSPoint(x: rect.midX, y: midY - 3.6),
            controlPoint1: NSPoint(x: rect.midX + 1.2, y: midY - 3.0),
            controlPoint2: NSPoint(x: rect.midX + 0.6, y: midY - 3.6)
        )
        path.curve(
            to: NSPoint(x: rect.midX - 2.0, y: midY - 1.8),
            controlPoint1: NSPoint(x: rect.midX - 0.6, y: midY - 3.6),
            controlPoint2: NSPoint(x: rect.midX - 1.2, y: midY - 3.0)
        )
        path.curve(
            to: NSPoint(x: rect.minX + 0.5, y: midY),
            controlPoint1: NSPoint(x: rect.midX - 3.4, y: midY - 0.6),
            controlPoint2: NSPoint(x: rect.minX + w * 0.2, y: midY - h * 0.16)
        )
        path.close()
        path.fill()
    }

    // Angular faceplate: rounded rect head, slit eyes, jaw lines.
    static func drawIronMask(in rect: NSRect) {
        let inset = rect.insetBy(dx: 2.5, dy: 1.0)
        let head = NSBezierPath(roundedRect: inset, xRadius: 4, yRadius: 4)
        head.lineWidth = 1.6
        head.stroke()

        for xOffset: CGFloat in [-3.2, 0.8] {
            let eye = NSBezierPath(
                roundedRect: NSRect(x: inset.midX + xOffset, y: inset.midY + 1.2, width: 2.4, height: 1.4),
                xRadius: 0.7, yRadius: 0.7
            )
            eye.fill()
        }

        let jaw = NSBezierPath()
        jaw.move(to: NSPoint(x: inset.minX + 2.0, y: inset.minY + 3.2))
        jaw.line(to: NSPoint(x: inset.maxX - 2.0, y: inset.minY + 3.2))
        jaw.lineWidth = 1.0
        jaw.stroke()

        let chin = NSBezierPath()
        chin.move(to: NSPoint(x: inset.midX, y: inset.minY + 3.2))
        chin.line(to: NSPoint(x: inset.midX, y: inset.minY + 0.8))
        chin.lineWidth = 1.0
        chin.stroke()
    }

    // Larger tinted rendering used as the hero watermark inside the panel.
    static func watermark(for theme: HeroTheme, size: CGFloat, color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            color.setStroke()
            color.setFill()
            let transform = NSAffineTransform()
            transform.scale(by: size / 18.0)
            transform.concat()
            let unit = NSRect(x: 0, y: 0, width: 18, height: 18)
            switch theme {
            case .spiderman: drawSpideyMask(in: unit)
            case .batman: drawBatSymbol(in: unit)
            case .ironman: drawIronMask(in: unit)
            }
            return true
        }
        return image
    }
}
