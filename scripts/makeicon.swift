// Generates the Spidey app icon: cartoon spidey mask on a navy rounded square.
// Usage: swift scripts/makeicon.swift Resources/AppIcon.icns
import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.icns"

func drawIcon(size: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        let scale = size / 1024.0

        // Rounded square background, deep navy.
        let bgRect = rect.insetBy(dx: 90 * scale, dy: 90 * scale)
        let bg = NSBezierPath(roundedRect: bgRect, xRadius: 190 * scale, yRadius: 190 * scale)
        NSColor(red: 0.035, green: 0.055, blue: 0.110, alpha: 1).setFill()
        bg.fill()

        // Web lines radiating from the top center.
        NSColor(red: 0.690, green: 0.180, blue: 0.210, alpha: 0.16).setStroke()
        let origin = NSPoint(x: rect.midX, y: bgRect.maxY)
        for angleDegrees in stride(from: 210.0, through: 330.0, by: 24.0) {
            let angle = angleDegrees * .pi / 180
            let line = NSBezierPath()
            line.move(to: origin)
            line.line(to: NSPoint(
                x: origin.x + cos(angle) * size,
                y: origin.y + sin(angle) * size
            ))
            line.lineWidth = 8 * scale
            line.stroke()
        }

        // Cartoon mask: head circle in red with black outline.
        let headRect = NSRect(
            x: rect.midX - 300 * scale, y: rect.midY - 300 * scale,
            width: 600 * scale, height: 600 * scale
        )
        let head = NSBezierPath(ovalIn: headRect)
        NSColor(red: 0.690, green: 0.180, blue: 0.210, alpha: 1).setFill()
        head.fill()
        NSColor(white: 0.05, alpha: 1).setStroke()
        head.lineWidth = 16 * scale
        head.stroke()

        // Web on the mask.
        NSColor.black.setStroke()
        let vertical = NSBezierPath()
        vertical.move(to: NSPoint(x: headRect.midX, y: headRect.maxY))
        vertical.line(to: NSPoint(x: headRect.midX, y: headRect.minY))
        vertical.lineWidth = 12 * scale
        vertical.stroke()
        for offset: CGFloat in [-95, 95] {
            let arc = NSBezierPath()
            arc.move(to: NSPoint(x: headRect.minX + 40 * scale, y: headRect.midY + offset * scale))
            arc.curve(
                to: NSPoint(x: headRect.maxX - 40 * scale, y: headRect.midY + offset * scale),
                controlPoint1: NSPoint(x: headRect.midX - 120 * scale, y: headRect.midY + offset * 1.7 * scale),
                controlPoint2: NSPoint(x: headRect.midX + 120 * scale, y: headRect.midY + offset * 1.7 * scale)
            )
            arc.lineWidth = 12 * scale
            arc.stroke()
        }

        // Big white cartoon eyes with black outlines.
        for sign: CGFloat in [-1, 1] {
            let eye = NSBezierPath()
            let cx = headRect.midX + sign * 120 * scale
            let top = NSPoint(x: cx + sign * 60 * scale, y: headRect.midY + 90 * scale)
            let bottom = NSPoint(x: cx - sign * 15 * scale, y: headRect.midY - 60 * scale)
            eye.move(to: top)
            eye.curve(
                to: bottom,
                controlPoint1: NSPoint(x: cx + sign * 100 * scale, y: headRect.midY + 10 * scale),
                controlPoint2: NSPoint(x: cx + sign * 45 * scale, y: headRect.midY - 60 * scale)
            )
            eye.curve(
                to: top,
                controlPoint1: NSPoint(x: cx - sign * 70 * scale, y: headRect.midY - 25 * scale),
                controlPoint2: NSPoint(x: cx - sign * 25 * scale, y: headRect.midY + 70 * scale)
            )
            eye.close()
            NSColor.white.setFill()
            eye.fill()
            NSColor.black.setStroke()
            eye.lineWidth = 16 * scale
            eye.stroke()
        }
        return true
    }
}

let iconsetURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Spidey.iconset")
try? FileManager.default.removeItem(at: iconsetURL)
try! FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let sizes: [(name: String, points: CGFloat, scale: CGFloat)] = [
    ("icon_16x16", 16, 1), ("icon_16x16@2x", 16, 2),
    ("icon_32x32", 32, 1), ("icon_32x32@2x", 32, 2),
    ("icon_128x128", 128, 1), ("icon_128x128@2x", 128, 2),
    ("icon_256x256", 256, 1), ("icon_256x256@2x", 256, 2),
    ("icon_512x512", 512, 1), ("icon_512x512@2x", 512, 2),
]

for spec in sizes {
    let pixels = spec.points * spec.scale
    let image = drawIcon(size: pixels)
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try! png.write(to: iconsetURL.appendingPathComponent("\(spec.name).png"))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", output]
try! process.run()
process.waitUntilExit()
print(process.terminationStatus == 0 ? "Wrote \(output)" : "iconutil failed")
