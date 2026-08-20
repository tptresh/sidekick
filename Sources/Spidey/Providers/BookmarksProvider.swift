import AppKit

// Browser bookmarks: ambient matches ride along with normal queries, and the
// "bm <query>" / "bookmark <query>" prefix searches bookmarks alone.
enum BookmarksProvider {
    enum Mode {
        case ambient
        case dedicated
    }

    static func results(for query: String) -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let lowered = trimmed.lowercased()
        for prefix in ["bm", "bookmark", "bookmarks"] {
            if lowered == prefix {
                return [ResultItem(
                    title: "Search bookmarks",
                    subtitle: "Keep typing to search your browser bookmarks, e.g. bm recipes",
                    icon: .symbol("bookmark"),
                    score: 800,
                    action: {}
                )]
            }
            if lowered.hasPrefix(prefix + " ") {
                let term = String(trimmed.dropFirst(prefix.count + 1)).trimmingCharacters(in: .whitespaces)
                return items(for: term, mode: .dedicated)
            }
        }
        return items(for: trimmed, mode: .ambient)
    }

    // Pure ranking so the thresholds and caps are testable. Ambient mode keeps
    // only strong name matches, capped to 3 and scored below apps and the site
    // directory; dedicated mode also matches hostnames and returns up to 15.
    static func rank(_ term: String, in bookmarks: [Bookmark], mode: Mode) -> [(bookmark: Bookmark, score: Double)] {
        guard term.count >= 2 else { return [] }
        var scored: [(bookmark: Bookmark, score: Double)] = []
        for bookmark in bookmarks {
            let name = Fuzzy.score(query: term, candidate: bookmark.name)
            switch mode {
            case .ambient:
                guard let name, name >= 0.8 else { continue }
                scored.append((bookmark, 300 + name * 100))
            case .dedicated:
                let host = Fuzzy.score(query: term, candidate: bookmark.host)
                guard let best = [name, host].compactMap({ $0 }).max() else { continue }
                scored.append((bookmark, 800 + best * 100))
            }
        }
        let cap = mode == .ambient ? 3 : 15
        return Array(scored.sorted { $0.score > $1.score }.prefix(cap))
    }

    private static func items(for term: String, mode: Mode) -> [ResultItem] {
        let ranked = rank(term, in: BookmarkStore.shared.entries(), mode: mode)
        if mode == .dedicated, ranked.isEmpty {
            return [ResultItem(
                title: "No bookmarks found",
                subtitle: term.count >= 2
                    ? "Nothing in your browser bookmarks matches \"\(term)\""
                    : "Keep typing to search your browser bookmarks",
                icon: .symbol("bookmark.slash"),
                score: 800,
                action: {}
            )]
        }
        return ranked.map { bookmark, score in
            ResultItem(
                title: bookmark.name.isEmpty ? bookmark.url : bookmark.name,
                subtitle: bookmark.url,
                icon: FaviconStore.shared.resultIcon(for: bookmark.url, fallbackSymbol: "bookmark"),
                score: score,
                secondaryAction: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(bookmark.url, forType: .string)
                },
                action: {
                    if let url = URL(string: bookmark.url) {
                        BrowserLauncher.open(url)
                    }
                }
            )
        }
    }
}
