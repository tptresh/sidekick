import Foundation

// For any plain query, offer to look the show up on each enabled streaming
// service and on every custom media site added in Preferences.
enum StreamingProvider {
    static func results(for query: String) -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, !Calculator.looksLikeExpression(trimmed) else { return [] }
        let encoded = BrowserLauncher.encodeQuery(trimmed)
        let settings = SettingsStore.shared

        var items: [ResultItem] = []
        var score = 200.0

        // Walk the unified media list so results come out in the order the
        // user arranged in Preferences.
        for entry in settings.orderedMediaEntries {
            switch entry {
            case .service(let service):
                guard settings.enabledServices.contains(service.id) else { continue }
                let url = service.searchURL(encoded)
                items.append(ResultItem(
                    title: "Watch \"\(trimmed)\" on \(service.name)",
                    subtitle: subtitle("Opens the \(service.name) search in \(BrowserLauncher.targetName)", statusKey: service.id),
                    icon: FaviconStore.shared.resultIcon(for: url.absoluteString, fallbackSymbol: "play.tv.fill"),
                    score: score,
                    action: { BrowserLauncher.open(url) }
                ))
            case .custom(let site):
                // A site joins search results as soon as it is added. Best to
                // worst: open its real search results page, ask its internal
                // search API and jump to the top matching title, or open the
                // site itself so its own search box is one click away.
                guard site.enabled, site.isValid, let homepage = site.homepageURL
                else { continue }
                let how: String
                let action: () -> Void
                if let url = site.searchURL(encodedQuery: encoded) {
                    how = "Opens the \(site.displayName) search in \(BrowserLauncher.targetName)"
                    action = { BrowserLauncher.open(url) }
                } else if let api = site.activeDiscoveredAPI {
                    how = "Opens the top match on \(site.displayName) in \(BrowserLauncher.targetName)"
                    action = {
                        SiteSearchOpener.openTopMatch(
                            apiTemplate: api.apiTemplate, titleTemplate: api.titleTemplate,
                            query: trimmed, homepage: homepage
                        )
                    }
                } else {
                    how = "Opens \(site.displayName) in \(BrowserLauncher.targetName) - search from there"
                    action = { BrowserLauncher.open(homepage) }
                }
                items.append(ResultItem(
                    title: "Watch \"\(trimmed)\" on \(site.displayName)",
                    subtitle: subtitle(how, statusKey: site.id.uuidString),
                    icon: FaviconStore.shared.resultIcon(
                        for: homepage.absoluteString,
                        fallbackSymbol: "play.tv.fill"
                    ),
                    score: score,
                    action: action
                ))
            }
            score -= 1
        }

        // A bare custom-site name opens its homepage, like the built-in media sites.
        let lowered = trimmed.lowercased()
        for site in settings.activeCustomMediaSites {
            guard let match = Fuzzy.score(query: lowered, candidate: site.displayName.lowercased()),
                  match >= 0.9, let url = site.homepageURL else { continue }
            items.append(ResultItem(
                title: "Open \(site.displayName)",
                subtitle: subtitle("Opens \(url.absoluteString) in \(BrowserLauncher.targetName)", statusKey: site.id.uuidString),
                icon: FaviconStore.shared.resultIcon(for: url.absoluteString, fallbackSymbol: "play.tv.fill"),
                score: 870 + match * 20,
                action: { BrowserLauncher.open(url) }
            ))
        }
        return items
    }

    private static func subtitle(_ base: String, statusKey: String) -> String {
        guard let status = LinkChecker.shared.status(forKey: statusKey), !status.ok else { return base }
        return base + " - site was unreachable at the last link check"
    }
}
