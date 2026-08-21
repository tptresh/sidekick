import AppKit

// Turns whatever is open in the browser into "you were watching this".
// Two ways in: the watching command offers what it finds as one-Return
// saves, and the Mac going to sleep saves it without being asked, which is
// the moment people actually stop watching.
enum WatchCapture {
    struct Candidate: Equatable {
        let episode: EpisodeParser.Episode
        let url: String
        let site: String
    }

    // Mutated on the main thread only; the tab read itself is off it.
    private(set) static var candidates: [Candidate] = []
    private static var lastScanStarted = Date.distantPast
    private static var scanning = false
    // A tab list this fresh is good enough; scanning shells out to
    // AppleScript, so it must not run per keystroke.
    private static let rescanInterval: TimeInterval = 5

    // What is playing right now, with a background refresh when the list has
    // gone stale. Returns the last known list immediately so the panel never
    // waits on AppleScript.
    static func currentCandidates() -> [Candidate] {
        if !scanning, Date().timeIntervalSince(lastScanStarted) >= rescanInterval {
            scan(timeout: 15) { found in
                let changed = found != candidates
                candidates = found
                // Reuse the row-upgrade refresh hook so the open query re-runs
                // against the fresh list.
                if changed {
                    NotificationCenter.default.post(name: .spideyFaviconLoaded, object: nil)
                }
            }
        }
        return candidates
    }

    // Saves every episode page open right now. The completion always runs,
    // even with no browser open, because the sleep command waits on it.
    static func captureNow(timeout: TimeInterval, completion: @escaping () -> Void) {
        scan(timeout: timeout) { found in
            candidates = found
            for candidate in found { save(candidate) }
            completion()
        }
    }

    static func save(_ candidate: Candidate) {
        WatchStore.shared.record(
            show: candidate.episode.show,
            season: candidate.episode.season,
            episode: candidate.episode.episode,
            site: candidate.site,
            url: candidate.url
        )
    }

    // Already saved at exactly this point, so there is nothing to offer.
    static func isAlreadySaved(_ candidate: Candidate, store: WatchStore = .shared) -> Bool {
        guard let entry = store.entry(forShow: candidate.episode.show) else { return false }
        return entry.episode == candidate.episode.episode
            && (candidate.episode.season == nil || entry.season == candidate.episode.season)
    }

    // Pure half, so the tab-to-candidate reading is testable: one candidate
    // per show, keeping the leftmost tab when a show is open twice.
    static func candidates(from tabs: [TabsProvider.Tab]) -> [Candidate] {
        var seen: Set<String> = []
        var found: [Candidate] = []
        for tab in tabs {
            guard isWatchable(tab.url),
                  let episode = EpisodeParser.parse(title: tab.title, url: tab.url)
            else { continue }
            let key = WatchStore.normalize(episode.show)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            found.append(Candidate(episode: episode, url: tab.url, site: siteName(for: tab.url)))
        }
        return found
    }

    // A search for "the pitt season 1 episode 6" reads exactly like the show
    // itself, but its page resumes nothing, so search tabs are ignored.
    private static let searchHosts = [
        "google.", "bing.com", "duckduckgo.com", "search.yahoo.", "search.brave.com",
        "ecosia.org", "startpage.com",
    ]

    static func isWatchable(_ url: String) -> Bool {
        guard url.hasPrefix("http"), let host = URL(string: url)?.host?.lowercased()
        else { return false }
        return !searchHosts.contains { host.contains($0) }
    }

    static func siteName(for url: String) -> String {
        guard let host = URL(string: url)?.host else { return "the web" }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private static func scan(timeout: TimeInterval, then finish: @escaping ([Candidate]) -> Void) {
        scanning = true
        lastScanStarted = Date()
        TabsProvider.readOpenTabs(timeout: timeout) { tabs in
            scanning = false
            finish(candidates(from: tabs))
        }
    }
}
