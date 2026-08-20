import AppKit

// "#E02128" or "rgb(224, 33, 40)": swatch preview plus hex/RGB/HSL copies.
enum ColorProvider {
    struct ParsedColor {
        let red: Int
        let green: Int
        let blue: Int

        var hex: String {
            String(format: "#%02X%02X%02X", red, green, blue)
        }

        var rgbString: String {
            "rgb(\(red), \(green), \(blue))"
        }

        var hslString: String {
            let (hue, saturation, lightness) = hsl
            return "hsl(\(hue), \(saturation)%, \(lightness)%)"
        }

        var hsl: (hue: Int, saturation: Int, lightness: Int) {
            let r = Double(red) / 255
            let g = Double(green) / 255
            let b = Double(blue) / 255
            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let delta = maxC - minC
            let lightness = (maxC + minC) / 2
            var hue = 0.0
            var saturation = 0.0
            if delta > 0 {
                saturation = delta / (1 - abs(2 * lightness - 1))
                switch maxC {
                case r: hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
                case g: hue = (b - r) / delta + 2
                default: hue = (r - g) / delta + 4
                }
                hue *= 60
                if hue < 0 { hue += 360 }
            }
            return (Int(hue.rounded()), Int((saturation * 100).rounded()), Int((lightness * 100).rounded()))
        }
    }

    static func parse(_ query: String) -> ParsedColor? {
        let text = query.trimmingCharacters(in: .whitespaces).lowercased()

        // #RGB or #RRGGBB, leading # required so ordinary words never match.
        if text.hasPrefix("#") {
            var hex = String(text.dropFirst())
            guard hex.count == 3 || hex.count == 6,
                  hex.allSatisfy({ $0.isHexDigit }) else { return nil }
            if hex.count == 3 {
                hex = hex.map { "\($0)\($0)" }.joined()
            }
            let value = UInt32(hex, radix: 16) ?? 0
            return ParsedColor(
                red: Int((value >> 16) & 0xFF),
                green: Int((value >> 8) & 0xFF),
                blue: Int(value & 0xFF)
            )
        }

        // rgb(224, 33, 40) or "rgb 224 33 40".
        if text.hasPrefix("rgb") {
            let numbers = text.dropFirst(3)
                .components(separatedBy: CharacterSet.decimalDigits.inverted)
                .filter { !$0.isEmpty }
                .compactMap { Int($0) }
            guard numbers.count == 3, numbers.allSatisfy({ (0...255).contains($0) }) else { return nil }
            return ParsedColor(red: numbers[0], green: numbers[1], blue: numbers[2])
        }
        return nil
    }

    static func swatch(for color: ParsedColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 32, height: 32), flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: 7, yRadius: 7)
            NSColor(
                red: CGFloat(color.red) / 255,
                green: CGFloat(color.green) / 255,
                blue: CGFloat(color.blue) / 255,
                alpha: 1
            ).setFill()
            path.fill()
            NSColor.white.withAlphaComponent(0.25).setStroke()
            path.lineWidth = 1
            path.stroke()
            return true
        }
        return image
    }

    static func results(for query: String) -> [ResultItem] {
        guard let color = parse(query) else { return [] }
        let icon = ResultIcon.appIcon(swatch(for: color))
        func copyRow(_ text: String, subtitle: String, score: Double) -> ResultItem {
            ResultItem(
                title: text,
                subtitle: subtitle,
                icon: icon,
                score: score,
                action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(text, forType: .string)
                }
            )
        }
        return [
            copyRow(color.hex, subtitle: "\(color.rgbString), \(color.hslString). Return copies the hex.", score: 985),
            copyRow(color.rgbString, subtitle: "Return copies the RGB value.", score: 984),
            copyRow(color.hslString, subtitle: "Return copies the HSL value.", score: 983),
        ]
    }
}
