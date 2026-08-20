import Foundation

enum WebSearchProvider {
    struct Keyword {
        let trigger: String
        let name: String
        let symbol: String
        let url: (String) -> String
    }

    static let keywords: [Keyword] = [
        Keyword(trigger: "google", name: "Google", symbol: "magnifyingglass") {
            "https://www.google.com/search?q=\($0)"
        },
        Keyword(trigger: "amazon", name: "Amazon", symbol: "cart.fill") {
            "https://www.amazon.co.uk/s?k=\($0)"
        },
        Keyword(trigger: "wiki", name: "Wikipedia", symbol: "book.fill") {
            "https://en.wikipedia.org/wiki/Special:Search?search=\($0)"
        },
        Keyword(trigger: "imdb", name: "IMDb", symbol: "film.fill") {
            "https://www.imdb.com/find/?q=\($0)"
        },
        Keyword(trigger: "gh", name: "GitHub", symbol: "chevron.left.forwardslash.chevron.right") {
            "https://github.com/search?q=\($0)"
        },
        Keyword(trigger: "maps", name: "Google Maps", symbol: "map.fill") {
            "https://www.google.com/maps/search/\($0)"
        },
    ]

    static func searchURL(trigger: String, query: String) -> URL? {
        guard let keyword = keywords.first(where: { $0.trigger == trigger }) else { return nil }
        return URL(string: keyword.url(BrowserLauncher.encodeQuery(query)))
    }

    // "amazon death note manga" opens the Amazon search results directly.
    static func results(for query: String) -> [ResultItem] {
        let parts = query.split(separator: " ", maxSplits: 1)
        guard parts.count == 2 else { return [] }
        let trigger = parts[0].lowercased()
        let term = String(parts[1]).trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty,
              let keyword = keywords.first(where: { $0.trigger == trigger }),
              let url = searchURL(trigger: trigger, query: term) else { return [] }
        return [ResultItem(
            title: "Search \(keyword.name) for \"\(term)\"",
            subtitle: "Opens in \(BrowserLauncher.targetName)",
            icon: FaviconStore.shared.resultIcon(for: url.absoluteString, fallbackSymbol: keyword.symbol),
            score: 950,
            action: { BrowserLauncher.open(url) }
        )]
    }

    static func googleFallback(for query: String) -> ResultItem? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let url = URL(string: "https://www.google.com/search?q=\(BrowserLauncher.encodeQuery(trimmed))")
        else { return nil }
        return ResultItem(
            title: "Search Google for \"\(trimmed)\"",
            subtitle: "Opens in \(BrowserLauncher.targetName)",
            icon: FaviconStore.shared.resultIcon(for: "https://www.google.com", fallbackSymbol: "magnifyingglass"),
            score: 100,
            action: { BrowserLauncher.open(url) }
        )
    }
}
