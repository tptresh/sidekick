import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
// Dev helper: `Spidey --show "query"` opens the panel on launch with a prefilled query.
if let flagIndex = CommandLine.arguments.firstIndex(of: "--show") {
    delegate.showOnLaunchQuery = CommandLine.arguments.count > flagIndex + 1
        ? CommandLine.arguments[flagIndex + 1]
        : ""
}
// Dev helper: `Spidey --icons <dir>` renders every hero emblem large to PNGs and exits.
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
// Dev helper: `Spidey --filesearch "query" <outfile>` writes file search results and exits.
// Run via `open -n` so the results reflect the app's own folder permissions.
if let flagIndex = CommandLine.arguments.firstIndex(of: "--filesearch"),
   CommandLine.arguments.count > flagIndex + 2 {
    let query = CommandLine.arguments[flagIndex + 1]
    let outfile = CommandLine.arguments[flagIndex + 2]
    FileProvider.search(query, mode: .dedicated) { items in
        let lines = items.map(\.subtitle).joined(separator: "\n")
        try? (lines + "\n[\(items.count) results]\n").write(toFile: outfile, atomically: true, encoding: .utf8)
        exit(0)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 15) { exit(1) }
    RunLoop.main.run()
}
// Dev helper: `Spidey --entrance <spiderman|batman> <dir>` plays that theme's
// full screen entrance, captures frames of the overlay to PNGs, and exits.
if let flagIndex = CommandLine.arguments.firstIndex(of: "--entrance"),
   CommandLine.arguments.count > flagIndex + 2,
   let theme = HeroTheme(rawValue: CommandLine.arguments[flagIndex + 1]) {
    delegate.entranceTheme = theme
    delegate.entranceDirectory = CommandLine.arguments[flagIndex + 2]
}
// Dev helper: `Spidey --snapshot <dir>` renders the panel for sample queries to PNGs and exits.
if let flagIndex = CommandLine.arguments.firstIndex(of: "--snapshot"),
   CommandLine.arguments.count > flagIndex + 1 {
    delegate.snapshotDirectory = CommandLine.arguments[flagIndex + 1]
}
// Capture modes are extra, short-lived instances launched with `open -n`
// while the real app keeps running, so they must not evict it.
if delegate.snapshotDirectory == nil, delegate.entranceDirectory == nil {
    SingleInstance.enforce()
}
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
