// Generates the Spidey app icon: cartoon spidey mask on a navy rounded square.
// Usage: swift scripts/makeicon.swift Resources/AppIcon.icns
import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.icns"

// The classic emblem: red disk, black web, large white sweeping eyes.
// Eye geometry mirrors StatusIcons.spideyEyePath, drawn in an 18-unit space.
func spideyEye(mirrored: Bool) -> NSBezierPath {
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: mirrored ? 18 - x : x, y: y)
    }
    let eye = NSBezierPath()
    eye.move(to: point(2.8, 13.0))
    eye.curve(to: point(8.3, 5.6), controlPoint1: point(1.8, 9.4), controlPoint2: point(4.2, 5.4))
    eye.curve(to: point(2.8, 13.0), controlPoint1: point(10.2, 8.8), controlPoint2: point(6.2, 11.8))
    eye.close()
    return eye
}

func drawIcon(size: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        let scale = size / 1024.0

        // Rounded square background, deep navy.
        let bgRect = rect.insetBy(dx: 90 * scale, dy: 90 * scale)
        let bg = NSBezierPath(roundedRect: bgRect, xRadius: 190 * scale, yRadius: 190 * scale)
        NSColor(red: 0.035, green: 0.055, blue: 0.110, alpha: 1).setFill()
        bg.fill()

        // Mask disk in muted crimson with a black outline.
        let headRect = NSRect(
            x: rect.midX - 310 * scale, y: rect.midY - 310 * scale,
            width: 620 * scale, height: 620 * scale
        )
        let head = NSBezierPath(ovalIn: headRect)
        NSColor(red: 0.690, green: 0.180, blue: 0.210, alpha: 1).setFill()
        head.fill()
        NSColor(white: 0.05, alpha: 1).setStroke()
        head.lineWidth = 20 * scale
        head.stroke()

        // Web: radial spokes from the center plus concentric arcs, clipped to the disk.
        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(ovalIn: headRect.insetBy(dx: 6 * scale, dy: 6 * scale)).setClip()
        NSColor(white: 0.05, alpha: 1).setStroke()
        let center = NSPoint(x: headRect.midX, y: headRect.midY + 40 * scale)
        for index in 0..<12 {
            let angle = CGFloat(index) * .pi / 6
            let spoke = NSBezierPath()
            spoke.move(to: center)
            spoke.line(to: NSPoint(
                x: center.x + cos(angle) * 420 * scale,
                y: center.y + sin(angle) * 420 * scale
            ))
            spoke.lineWidth = 9 * scale
            spoke.stroke()
        }
        for radius in stride(from: CGFloat(90), through: 360, by: 90) {
            let ring = NSBezierPath(ovalIn: NSRect(
                x: center.x - radius * scale, y: center.y - radius * scale,
                width: radius * 2 * scale, height: radius * 2 * scale
            ))
            ring.lineWidth = 9 * scale
            ring.stroke()
        }
        NSGraphicsContext.current?.restoreGraphicsState()

        // Large white sweeping eyes with black outlines, in 18-unit mask space.
        let transform = NSAffineTransform()
        transform.translateX(by: headRect.minX, yBy: headRect.minY)
        transform.scale(by: headRect.width / 18.0)
        for mirrored in [false, true] {
            let eye = spideyEye(mirrored: mirrored)
            eye.transform(using: transform as AffineTransform)
            NSColor.white.setFill()
            eye.fill()
            NSColor(white: 0.05, alpha: 1).setStroke()
            eye.lineWidth = 18 * scale
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
