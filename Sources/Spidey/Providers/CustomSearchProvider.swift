import AppKit

// User-defined search keywords from searches.json: "yt lofi beats" opens the
// YouTube results. User keywords score 955 so they outrank the built-in 950
// keywords when the user deliberately shadows one.
enum CustomSearchProvider {
    static func results(for query: String) -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let store = CustomSearchStore.shared

        let parts = trimmed.split(separator: " ", maxSplits: 1)
        let trigger = String(parts[0]).lowercased()
        if let search = store.search(for: trigger) {
            guard parts.count == 2 else {
                return [ResultItem(
                    title: "Search \(search.name)",
                    subtitle: "Keep typing to search \(search.name), e.g. \(search.keyword) lofi beats",
                    icon: FaviconStore.shared.resultIcon(
                        for: search.homepageURLString, fallbackSymbol: "magnifyingglass"
                    ),
                    score: 955,
                    action: {}
                )]
            }
            let term = String(parts[1]).trimmingCharacters(in: .whitespaces)
            guard !term.isEmpty, let url = search.searchURL(for: term) else { return [] }
            return [ResultItem(
                title: "Search \(search.name) for \"\(term)\"",
                subtitle: "Opens in \(BrowserLauncher.targetName)",
                icon: FaviconStore.shared.resultIcon(
                    for: search.homepageURLString, fallbackSymbol: "magnifyingglass"
                ),
                score: 955,
                action: { BrowserLauncher.open(url) }
            )]
        }

        if trimmed.lowercased() == "searches" {
            return [setupRow(store: store)]
        }
        return []
    }

    private static func setupRow(store: CustomSearchStore) -> ResultItem {
        if store.fileExists {
            return ResultItem(
                title: "Edit custom searches",
                subtitle: "Reveals searches.json in Finder - keyword \u{2192} URL with {query}",
                icon: .symbol("plus.magnifyingglass"),
                score: 950,
                action: {
                    NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
                }
            )
        }
        return ResultItem(
            title: "Set up custom searches",
            subtitle: "Return creates searches.json with examples - keyword \u{2192} URL with {query}",
            icon: .symbol("plus.magnifyingglass"),
            score: 950,
            action: {
                guard let url = store.createExampleFile() else { return }
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        )
    }
}
