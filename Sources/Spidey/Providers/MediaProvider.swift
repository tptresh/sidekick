import Foundation

// youtube <anything> searches YouTube; bare youtube / netflix / crunchyroll open the homepage.
enum MediaProvider {
    static func youtubeSearchURL(_ query: String) -> URL {
        URL(string: "https://www.youtube.com/results?search_query=\(BrowserLauncher.encodeQuery(query))")!
    }

    static let homepages: [(names: [String], title: String, url: String, symbol: String)] = [
        (["youtube", "yt"], "YouTube", "https://www.youtube.com", "play.rectangle.fill"),
        (["netflix"], "Netflix", "https://www.netflix.com", "tv.fill"),
        (["crunchyroll"], "Crunchyroll", "https://www.crunchyroll.com", "tv.fill"),
    ]

    static func results(for query: String) -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let lowered = trimmed.lowercased()
        var items: [ResultItem] = []

        // "youtube lofi beats" opens the YouTube search results.
        for prefix in ["youtube ", "yt "] where lowered.hasPrefix(prefix) {
            let term = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            if !term.isEmpty {
                let url = youtubeSearchURL(term)
                items.append(ResultItem(
                    title: "Search YouTube for \"\(term)\"",
                    subtitle: "Opens in \(BrowserLauncher.targetName)",
                    icon: FaviconStore.shared.resultIcon(for: "https://www.youtube.com", fallbackSymbol: "play.rectangle.fill"),
                    score: 960,
                    action: { BrowserLauncher.open(url) }
                ))
            }
        }

        // Bare site name opens the homepage.
        for site in homepages {
            let best = site.names.compactMap { Fuzzy.score(query: lowered, candidate: $0) }.max()
            guard let match = best, match >= 0.9, let url = URL(string: site.url) else { continue }
            items.append(ResultItem(
                title: "Open \(site.title)",
                subtitle: "Opens \(site.url) in \(BrowserLauncher.targetName)",
                icon: FaviconStore.shared.resultIcon(for: site.url, fallbackSymbol: site.symbol),
                score: 870 + match * 20,
                action: { BrowserLauncher.open(url) }
            ))
        }
        return items
    }
}
