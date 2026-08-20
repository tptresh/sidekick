import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
// Dev helper: `Spidey --show "query"` opens the panel on launch with a prefilled query.
if let flagIndex = CommandLine.arguments.firstIndex(of: "--show") {
    delegate.showOnLaunchQuery = CommandLine.arguments.count > flagIndex + 1
        ? CommandLine.arguments[flagIndex + 1]
        : ""
}
// Dev helper: `Spidey --icons <dir>` renders the three hero emblems large to PNGs and exits.
if let flagIndex = CommandLine.arguments.firstIndex(of: "--icons"),
   CommandLine.arguments.count > flagIndex + 1 {
    let dir = CommandLine.arguments[flagIndex + 1]
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    for theme in HeroTheme.allCases {
        let size: CGFloat = 256
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            StatusIcons.watermark(for: theme, size: size, color: .black)
                .draw(in: rect)
            return true
        }
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: dir + "/\(theme.rawValue).png"))
        }
    }
    exit(0)
}
// Dev helper: `Spidey --snapshot <dir>` renders the panel for sample queries to PNGs and exits.
if let flagIndex = CommandLine.arguments.firstIndex(of: "--snapshot"),
   CommandLine.arguments.count > flagIndex + 1 {
    delegate.snapshotDirectory = CommandLine.arguments[flagIndex + 1]
}
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
