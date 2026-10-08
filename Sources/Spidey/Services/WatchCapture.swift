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
        // Seconds in, when Now Playing reported this tab.
        var time: Double? = nil
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

    // The episode or movie in the browser's front tab, with how far in it is,
    // while the browser is the app on screen or is playing in the background.
    // Refreshed when the panel opens, so the first couple of letters of
    // "watching" can already offer it, paused or not.
    private(set) static var onScreen: Candidate?
    private static var checkingOnScreen = false

    static func refreshOnScreen() {
        guard !checkingOnScreen else { return }
        // Both checks are cheap, so AppleScript only runs when one passes.
        guard let browser = TabsProvider.runningBrowserApp(),
              NSWorkspace.shared.frontmostApplication == browser
                || browser.bundleURL.map(isPlayingMedia(in:)) == true
        else {
            setOnScreen(nil)
            return
        }
        checkingOnScreen = true
        TabsProvider.readActiveTab(timeout: 3) { tab in
            guard let found = tab.flatMap({ candidates(from: [$0]).first }) else {
                checkingOnScreen = false
                setOnScreen(nil)
                return
            }
            // Shown straight away; the time follows once Now Playing answers.
            setOnScreen(found)
            NowPlaying.read(timeout: 3) { info in
                checkingOnScreen = false
                setOnScreen(withTime(found, tabTitle: tab?.title ?? "", info: info, browser: browser))
            }
        }
    }

    private static func setOnScreen(_ candidate: Candidate?) {
        guard candidate != onScreen else { return }
        onScreen = candidate
        NotificationCenter.default.post(name: .spideyFaviconLoaded, object: nil)
    }

    // Now Playing names the page by its title, so the time only belongs to
    // the tab whose title it reports, and only from the same browser.
    static func withTime(
        _ candidate: Candidate, tabTitle: String, info: NowPlaying.Info?,
        browser: NSRunningApplication?
    ) -> Candidate {
        guard let info, info.bundleID == browser?.bundleIdentifier,
              EpisodeParser.collapse(info.title) == EpisodeParser.collapse(tabTitle)
        else { return candidate }
        var timed = candidate
        timed.time = info.position
        return timed
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
        // Tabs and the playback time are read side by side, so the sleep
        // command waits on the slower of the two, not both.
        var tabs: [TabsProvider.Tab] = []
        var info: NowPlaying.Info?
        let group = DispatchGroup()
        group.enter()
        TabsProvider.readOpenTabs(timeout: timeout) { tabs = $0; group.leave() }
        group.enter()
        NowPlaying.read(timeout: timeout) { info = $0; group.leave() }
        group.notify(queue: .main) {
            let browser = TabsProvider.runningBrowserApp()
            let found = candidates(from: tabs).map { candidate in
                let title = tabs.first { $0.url == candidate.url }?.title ?? ""
                return withTime(candidate, tabTitle: title, info: info, browser: browser)
            }
            candidates = found
            for candidate in found { save(candidate) }
            completion()
        }
    }

    // A skip still waiting means the player has not reached the saved time
    // yet; an earlier time from it is a restart, not progress.
    static func protectedTime(_ candidate: Candidate) -> Double? {
        guard let current = candidate.time,
              let pending = NowPlaying.pendingSkipTime(forShow: candidate.episode.show)
        else { return candidate.time }
        return max(current, pending)
    }

    static func save(_ candidate: Candidate, store: WatchStore = .shared) {
        let time = protectedTime(candidate)
        store.record(
            show: candidate.episode.show,
            season: candidate.episode.season,
            episode: candidate.episode.episode,
            site: candidate.site,
            url: candidate.url,
            time: time
        )
    }

    // Already saved at exactly this point, so there is nothing to offer. A
    // time more than a minute off from the saved one counts as new progress.
    static func isAlreadySaved(_ candidate: Candidate, store: WatchStore = .shared) -> Bool {
        guard let entry = store.entry(forShow: candidate.episode.show) else { return false }
        if let time = candidate.time, abs(time - (entry.time ?? -.infinity)) > 60 { return false }
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
