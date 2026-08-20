import Foundation

// For any plain query, offer to look the show up on each enabled streaming
// service and on every custom media site added in Preferences.
enum StreamingProvider {
    // A learned (query, stream key) association boost at least this strong
    // cancels the demotion for that service's row. It sits well above the
    // global-usage ceiling (50), so only real query associations qualify:
    // roughly two picks today, or one within the hour.
    static let rescueBoostThreshold: Double = 100

    static func rescuesDemotion(boost: Double) -> Bool {
        boost >= rescueBoostThreshold
    }

    static func results(for query: String, usage: UsageStore = .shared) -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, !Calculator.looksLikeExpression(trimmed) else { return [] }
        let encoded = BrowserLauncher.encodeQuery(trimmed)
        let settings = SettingsStore.shared

        var items: [ResultItem] = []
        // Prior probability: someone typing a famous site or brand name almost
        // always wants the website, not a show with that title. When the query
        // strongly matches a well-known (tier >= 2) directory name and does not
        // read like a show title, sink the "Watch ..." rows well below the site
        // row (and the Google fallback at 100). They stay available for the
        // rare user who really wants "Cartier" the series, and frecency rescues
        // the habitual watcher: a service picked repeatedly for this query
        // skips the demotion entirely (below), and the engine's learned boost
        // lifts it further — though never above a strongly matched tiered site.
        let demoted = shouldDemoteShows(for: trimmed)
        let boosts = demoted ? usage.boosts(for: trimmed) : [:]
        var position = 0.0

        // Walk the unified media list so results come out in the order the
        // user arranged in Preferences.
        for entry in settings.orderedMediaEntries {
            switch entry {
            case .service(let service):
                guard settings.enabledServices.contains(service.id) else { continue }
                let url = service.searchURL(encoded)
                let key = "stream:\(service.id)"
                let rowDemoted = demoted && !rescuesDemotion(boost: boosts[key] ?? 0)
                items.append(ResultItem(
                    title: "Watch \"\(trimmed)\" on \(service.name)",
                    subtitle: subtitle("Opens the \(service.name) search in \(BrowserLauncher.targetName)", statusKey: service.id),
                    icon: FaviconStore.shared.resultIcon(for: url.absoluteString, fallbackSymbol: "play.tv.fill"),
                    score: (rowDemoted ? 80.0 : 200.0) - position,
                    rankingKey: key,
                    action: { BrowserLauncher.open(url) }
                ))
            case .custom(let site):
                guard site.enabled, site.isValid,
                      let url = site.searchURL(encodedQuery: encoded) else { continue }
                let how = site.hasSearchTemplate
                    ? "Opens the \(site.displayName) search in \(BrowserLauncher.targetName)"
                    : "Finds it on \(site.host ?? site.displayName) via Google, in \(BrowserLauncher.targetName)"
                let key = "stream:\(site.id.uuidString)"
                let rowDemoted = demoted && !rescuesDemotion(boost: boosts[key] ?? 0)
                items.append(ResultItem(
                    title: "Watch \"\(trimmed)\" on \(site.displayName)",
                    subtitle: subtitle(how, statusKey: site.id.uuidString),
                    icon: FaviconStore.shared.resultIcon(
                        for: site.homepageURL?.absoluteString ?? url.absoluteString,
                        fallbackSymbol: "play.tv.fill"
                    ),
                    score: (rowDemoted ? 80.0 : 200.0) - position,
                    rankingKey: key,
                    action: { BrowserLauncher.open(url) }
                ))
            }
            position += 1
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

    // True when the show-search rows should rank below the site row for this
    // query: it strongly matches a well-known directory name AND does not look
    // like a show title.
    static func shouldDemoteShows(for query: String) -> Bool {
        guard let tier = SiteDirectoryProvider.popularityTier(matching: query),
              tier >= 2 else { return false }
        return !looksShowLike(query)
    }

    // A rough "this reads like a title, not a site name" check: long phrases
    // or media words mean the streaming rows keep their normal rank even when
    // some brand name happens to match.
    static func looksShowLike(_ query: String) -> Bool {
        let words = query.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        if words.count >= 3 { return true }
        let mediaWords: Set<String> = [
            "season", "episode", "series", "show", "movie", "film",
            "anime", "documentary", "trailer",
        ]
        return words.contains { mediaWords.contains(String($0)) }
    }

    private static func subtitle(_ base: String, statusKey: String) -> String {
        guard let status = LinkChecker.shared.status(forKey: statusKey), !status.ok else { return base }
        return base + " — site was unreachable at the last link check"
    }
}
