import AppKit

enum ResultIcon {
    case appIcon(NSImage)
    case symbol(String)
}

struct ResultItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: ResultIcon
    let score: Double
    // When set, the row can be dragged out of the panel as this file.
    var dragFileURL: URL? = nil
    // When set, Cmd+Return runs this instead (used to reveal files in Finder).
    var secondaryAction: (() -> Void)? = nil
    let action: () -> Void
}
