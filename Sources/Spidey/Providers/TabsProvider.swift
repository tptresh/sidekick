import AppKit

// "tab gmail": lists the open tabs in Brave (or Chrome when Brave isn't
// running) over AppleScript and switches to the match. Only offered while a
// browser is actually running; the first use shows the standard macOS
// Automation consent for controlling it. The tab list is fetched off the
// main thread with a timeout and cached for two seconds so per-keystroke
// queries don't hammer AppleScript.
enum TabsProvider {
    struct Tab {
        let windowIndex: Int
        let tabIndex: Int
        let title: String
        let url: String
    }

    private struct Browser {
        let bundleID: String
        let appleScriptName: String
        let display: String
    }

    private static let browsers = [
        Browser(bundleID: BrowserLauncher.braveBundleID, appleScriptName: "Brave Browser", display: "Brave"),
        Browser(bundleID: "com.google.Chrome", appleScriptName: "Google Chrome", display: "Chrome"),
    ]

    // Mutated on the main thread only; the fetch itself runs on fetchQueue.
    private static var cache: (bundleID: String, date: Date, tabs: [Tab])?
    private static var fetching = false
    private static var lastFetchStart = Date.distantPast
    private static var lastFetchQuery: String?
    private static let cacheTTL: TimeInterval = 2
    // Regardless of the TTL, never start a new fetch this soon after the last
    // one began - a slow osascript must not turn into a respawn loop.
    private static let minRefetchInterval: TimeInterval = 5
    private static let fetchQueue = DispatchQueue(label: "dev.opensource.spidey.tabs", qos: .userInitiated)

    static func results(for query: String) -> [ResultItem] {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        let term: String
        if lowered == "tab" || lowered == "tabs" {
            term = ""
        } else if lowered.hasPrefix("tabs ") {
            term = String(lowered.dropFirst("tabs ".count)).trimmingCharacters(in: .whitespaces)
        } else if lowered.hasPrefix("tab ") {
            term = String(lowered.dropFirst("tab ".count)).trimmingCharacters(in: .whitespaces)
        } else {
            return []
        }

        guard let (browser, app) = runningBrowser() else {
            return [ResultItem(
                title: "No browser tabs to switch to",
                subtitle: "Works while Brave or Chrome is running",
                icon: .symbol("rectangle.stack"),
                score: 940,
                action: {}
            )]
        }

        guard let tabs = cachedTabs(for: browser, query: lowered) else {
            return [ResultItem(
                title: "Reading \(browser.display) tabs\u{2026}",
                subtitle: "First use asks permission to control \(browser.display)",
                icon: appIcon(of: app),
                score: 950,
                action: {}
            )]
        }

        let matches: [(Tab, Double)]
        if term.isEmpty {
            matches = tabs.enumerated().map { ($0.element, 1.0 - Double($0.offset) * 0.001) }
        } else {
            matches = tabs
                .compactMap { tab -> (Tab, Double)? in
                    let inTitle = Fuzzy.score(query: term, candidate: tab.title) ?? 0
                    let inURL = (Fuzzy.score(query: term, candidate: tab.url) ?? 0) * 0.9
                    let match = max(inTitle, inURL)
                    return match >= 0.5 ? (tab, match) : nil
                }
                .sorted { $0.1 > $1.1 }
        }

        if matches.isEmpty {
            if term.isEmpty {
                return [ResultItem(
                    title: "No open tabs",
                    subtitle: "\(browser.display) has no tabs to switch to",
                    icon: appIcon(of: app),
                    score: 890,
                    action: {}
                )]
            }
            return [ResultItem(
                title: "No open tab matches \u{201C}\(term)\u{201D}",
                subtitle: "Searched \(tabs.count) \(browser.display) tab\(tabs.count == 1 ? "" : "s")",
                icon: appIcon(of: app),
                score: 890,
                action: {}
            )]
        }

        let icon = appIcon(of: app)
        return matches.prefix(20).enumerated().map { index, pair in
            let (tab, match) = pair
            return ResultItem(
                title: tab.title.isEmpty ? tab.url : tab.title,
                subtitle: "\(browser.display) tab: \(tab.url)",
                icon: icon,
                score: 900 + match * 50 - Double(index) * 0.1,
                action: { activate(tab, in: browser) }
            )
        }
    }

    private static func runningBrowser() -> (Browser, NSRunningApplication)? {
        let running = NSWorkspace.shared.runningApplications
        for browser in browsers {
            if let app = running.first(where: { $0.bundleIdentifier == browser.bundleID }) {
                return (browser, app)
            }
        }
        return nil
    }

    private static func activate(_ tab: Tab, in browser: Browser) {
        SystemProvider.runAppleScript(
            activateScript(tab, appName: browser.appleScriptName),
            failureTitle: "Could not switch to that tab", timeout: 15
        )
    }

    // The list can be a few seconds old, and closing a tab shifts the ones
    // after it, so the tab is found again by its address only. Its old
    // position could now hold a different tab, so a tab that has gone is
    // reported rather than guessed at.
    static func activateScript(_ tab: Tab, appName: String) -> String {
        """
        tell application "\(appName)"
            repeat with w in windows
                set ti to 0
                repeat with t in tabs of w
                    set ti to ti + 1
                    if (URL of t) is "\(appleScriptEscaped(tab.url))" then
                        set active tab index of w to ti
                        set index of w to 1
                        activate
                        return
                    end if
                end repeat
            end repeat
            error "That tab has been closed since the list was shown. Search again to see the open tabs." number \(SystemProvider.messageErrorNumber)
        end tell
        """
    }

    static func appleScriptEscaped(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - Fetching the tab list

    private static func cachedTabs(for browser: Browser, query: String) -> [Tab]? {
        let cached = cache?.bundleID == browser.bundleID ? cache : nil
        if let cached, Date().timeIntervalSince(cached.date) < cacheTTL {
            return cached.tabs
        }
        // A cold cache fetches once. A stale one only refetches when the
        // query text changed since the last fetch request and the minimum
        // interval has passed - a notification-triggered re-render (same
        // query) serves the cache as-is, so one completed fetch's refresh
        // notification can't schedule the next fetch forever.
        if cached == nil
            || (query != lastFetchQuery
                && Date().timeIntervalSince(lastFetchStart) >= minRefetchInterval) {
            scheduleFetch(browser, query: query)
        }
        // A slightly stale list beats an empty panel while the refresh runs.
        return cached?.tabs
    }

    private static func scheduleFetch(_ browser: Browser, query: String) {
        guard !fetching else { return }
        fetching = true
        lastFetchStart = Date()
        lastFetchQuery = query
        fetchQueue.async {
            let tabs = fetchTabs(browser, timeout: 15)
            DispatchQueue.main.async {
                fetching = false
                cache = (browser.bundleID, Date(), tabs)
                // Reuse the row-upgrade refresh hook the favicon loader uses
                // so the open query re-runs against the fresh list.
                NotificationCenter.default.post(name: .spideyFaviconLoaded, object: nil)
            }
        }
    }

    // One-shot read of the open tabs for callers outside the tab switcher
    // (the watch tracker). Hands back an empty list when no supported browser
    // is running. The completion always runs, on the main thread.
    static func readOpenTabs(timeout: TimeInterval, completion: @escaping ([Tab]) -> Void) {
        guard let (browser, _) = runningBrowser() else {
            DispatchQueue.main.async { completion([]) }
            return
        }
        fetchQueue.async {
            let tabs = fetchTabs(browser, timeout: timeout)
            DispatchQueue.main.async { completion(tabs) }
        }
    }

    // The browser the tab readers below talk to.
    static func runningBrowserApp() -> NSRunningApplication? {
        runningBrowser()?.1
    }

    // Just the tab on screen in the browser's front window.
    static func readActiveTab(timeout: TimeInterval, completion: @escaping (Tab?) -> Void) {
        guard let (browser, _) = runningBrowser() else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        fetchQueue.async {
            let script = """
            set sep to character id 9
            tell application "\(browser.appleScriptName)"
                if (count of windows) is 0 then return ""
                set t to active tab of front window
                return "1" & sep & "1" & sep & (URL of t) & sep & (title of t)
            end tell
            """
            let tab = parseTabRecords(runOSAScript(script, timeout: timeout)).first
            DispatchQueue.main.async { completion(tab) }
        }
    }

    private static func runOSAScript(_ script: String, timeout: TimeInterval) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return "" }
        let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        killer.cancel()
        return String(decoding: data, as: UTF8.self)
    }

    private static func fetchTabs(_ browser: Browser, timeout: TimeInterval) -> [Tab] {
        // sep/nl are computed outside the tell block because "tab" is a class
        // name inside it, and AppleScript strings have no escape sequences.
        let script = """
        set sep to character id 9
        set nl to character id 10
        set out to ""
        tell application "\(browser.appleScriptName)"
            repeat with wi from 1 to (count of windows)
                repeat with ti from 1 to (count of tabs of window wi)
                    try
                        set t to tab ti of window wi
                        set out to out & wi & sep & ti & sep & (URL of t) & sep & (title of t) & nl
                    end try
                end repeat
            end repeat
        end tell
        return out
        """
        // Generous timeout by default: the first run blocks on the Automation
        // consent. A caller with something waiting on it (the Mac going to
        // sleep) passes a short one instead.
        return parseTabRecords(runOSAScript(script, timeout: timeout))
    }

    // One record per line: window \t tab \t url \t title. The title comes
    // last so tabs inside it survive the split, and a newline inside a title
    // splits its record across lines - such a continuation line doesn't parse
    // as a record, so it's glued back onto the previous tab's title.
    static func parseTabRecords(_ output: String) -> [Tab] {
        var tabs: [Tab] = []
        for line in output.split(separator: "\n") {
            // Title comes last so any tabs inside it survive the split.
            let parts = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)
            if parts.count == 4,
               let windowIndex = Int(parts[0]), let tabIndex = Int(parts[1]) {
                tabs.append(Tab(
                    windowIndex: windowIndex,
                    tabIndex: tabIndex,
                    title: sanitizedTitle(String(parts[3])),
                    url: String(parts[2])
                ))
            } else if let last = tabs.last {
                // A title fragment from an embedded newline; rejoin it.
                tabs[tabs.count - 1] = Tab(
                    windowIndex: last.windowIndex,
                    tabIndex: last.tabIndex,
                    title: sanitizedTitle(last.title + " " + line),
                    url: last.url
                )
            }
        }
        return tabs
    }

    // Newlines (and stray carriage returns) in a title would wreck the
    // single-line result row; show them as spaces instead.
    static func sanitizedTitle(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func appIcon(of app: NSRunningApplication) -> ResultIcon {
        guard let image = app.icon else { return .symbol("rectangle.stack") }
        image.size = NSSize(width: 32, height: 32)
        return .appIcon(image)
    }
}
