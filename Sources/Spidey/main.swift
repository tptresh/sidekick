import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
// Dev helper: `Spidey --show "query"` opens the panel on launch with a prefilled query.
if let flagIndex = CommandLine.arguments.firstIndex(of: "--show") {
    delegate.showOnLaunchQuery = CommandLine.arguments.count > flagIndex + 1
        ? CommandLine.arguments[flagIndex + 1]
        : ""
}
// Dev helper: `Spidey --snapshot <dir>` renders the panel for sample queries to PNGs and exits.
if let flagIndex = CommandLine.arguments.firstIndex(of: "--snapshot"),
   CommandLine.arguments.count > flagIndex + 1 {
    delegate.snapshotDirectory = CommandLine.arguments[flagIndex + 1]
}
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
