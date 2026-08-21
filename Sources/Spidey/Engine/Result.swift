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
    // Mutable so the engine can add learned-ranking (frecency) boosts on top
    // of the provider's static score before sorting.
    var score: Double
    // Stable identity used to learn which result the user picks for which
    // query, e.g. "app:com.google.Chrome" or "site:netflix.com". nil (the
    // default) means "don't learn from selections of this row".
    var rankingKey: String? = nil
    // When set, the row can be dragged out of the panel as this file.
    var dragFileURL: URL? = nil
    // When set, Cmd+Return runs this instead (used to reveal files in Finder).
    var secondaryAction: (() -> Void)? = nil
    // When true, running the secondary action leaves the panel open (used by
    // clipboard rows whose Cmd+Return toggles a pin in place).
    var secondaryKeepsPanel: Bool = false
    let action: () -> Void
}
