import AppKit
import IOKit.pwr_mgt

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

    // The episode or movie in the browser's front tab, only while the browser
    // is actually playing something. Refreshed when the panel opens, so the
    // first couple of letters of "watching" can already offer it.
    private(set) static var playing: Candidate?
    private static var checkingPlaying = false

    static func refreshPlaying() {
        guard !checkingPlaying else { return }
        // The power check is cheap, so AppleScript only runs mid-playback.
        guard let browser = TabsProvider.runningBrowserBundleURL(), isPlayingMedia(in: browser) else {
            setPlaying(nil)
            return
        }
        checkingPlaying = true
        TabsProvider.readActiveTab(timeout: 3) { tab in
            checkingPlaying = false
            setPlaying(tab.flatMap { candidates(from: [$0]).first })
        }
    }

    private static func setPlaying(_ candidate: Candidate?) {
        guard candidate != playing else { return }
        playing = candidate
        NotificationCenter.default.post(name: .spideyFaviconLoaded, object: nil)
    }

    // Browsers hold a "keep the display awake" power assertion while a video
    // plays and a "keep the system awake" one while audio plays, from the
    // main process or one of its helpers inside the app bundle. That is the
    // only public signal, since the player usually sits in a cross-site frame.
    static func isPlayingMedia(in bundle: URL) -> Bool {
        var unmanaged: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&unmanaged) == kIOReturnSuccess,
              let byProcess = unmanaged?.takeRetainedValue() as? [NSNumber: [[String: Any]]]
        else { return false }
        let prefix = bundle.path
        for (pid, assertions) in byProcess where !assertions.isEmpty {
            guard let path = executablePath(pid: pid_t(pid.int32Value)), path.hasPrefix(prefix)
            else { continue }
            // Brave reports "Playing audio" under the older NoIdleSleep name.
            let mediaTypes = [
                kIOPMAssertPreventUserIdleDisplaySleep, kIOPMAssertPreventUserIdleSystemSleep,
                kIOPMAssertionTypeNoIdleSleep, kIOPMAssertionTypeNoDisplaySleep,
            ]
            if assertions.contains(where: { mediaTypes.contains(($0["AssertType"] as? String) ?? "") }) {
                return true
            }
        }
        return false
    }

    private static func executablePath(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
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

    static func save(_ candidate: Candidate, store: WatchStore = .shared) {
        store.record(
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
        if candidate.episode.isMovie { return entry.isMovie }
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
                    ?? EpisodeParser.parseMovie(title: tab.title, url: tab.url)
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
