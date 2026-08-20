import AppKit
import ApplicationServices

// "win mail" lists on-screen windows across apps; a plain query that hits a
// window title hard surfaces the same rows ambiently. Return activates the
// app and raises that specific window. CGWindowList supplies which apps have
// real windows on screen (front to back); titles and the raise itself go
// through the Accessibility API, because reading kCGWindowName would need the
// far heavier Screen Recording permission while AX only needs the grant
// Spidey already asks for. The list is built off the main thread and cached
// briefly so typing stays snappy.
enum WindowSwitcherProvider {
    struct WindowInfo {
        let title: String
        let appName: String
        let pid: pid_t
        let element: AXUIElement
    }

    // Mutated on the main thread only; the listing itself runs on listQueue.
    private static var cache: (date: Date, windows: [WindowInfo])?
    private static var listing = false
    private static var lastListStart = Date.distantPast
    private static var lastListQuery: String?
    private static let cacheTTL: TimeInterval = 1.5
    // Regardless of the TTL, never start a new listing this soon after the
    // last one began - repeated AX walks must not sustain themselves.
    private static let minRefetchInterval: TimeInterval = 5
    private static let listQueue = DispatchQueue(label: "dev.opensource.spidey.window-list", qos: .userInitiated)

    static func results(for query: String) -> [ResultItem] {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        let explicit = lowered == "win" || lowered.hasPrefix("win ")
        let term = explicit
            ? String(lowered.dropFirst("win".count)).trimmingCharacters(in: .whitespaces)
            : lowered

        if explicit {
            guard AXIsProcessTrusted() else {
                return [ResultItem(
                    title: "Switch windows: needs Accessibility access",
                    subtitle: "Return opens the permission prompt, then try again",
                    icon: .symbol("lock.shield"),
                    score: 950,
                    action: { WindowProvider.requestPermission() }
                )]
            }
        } else {
            // Ambient rows only ride along on real queries, never nag.
            guard term.count >= 3, AXIsProcessTrusted() else { return [] }
        }

        guard let windows = cachedWindows(query: lowered) else {
            guard explicit else { return [] }
            return [ResultItem(
                title: "Listing windows\u{2026}",
                subtitle: "One moment, results appear as you type",
                icon: .symbol("macwindow.on.rectangle"),
                score: 950,
                action: {}
            )]
        }

        var items: [ResultItem] = []
        for (index, window) in windows.enumerated() {
            let score: Double
            if term.isEmpty {
                score = 900 - Double(index)
            } else {
                let titleMatch = Fuzzy.score(query: term, candidate: window.title) ?? 0
                if explicit {
                    let appMatch = (Fuzzy.score(query: term, candidate: window.appName) ?? 0) * 0.9
                    let match = max(titleMatch, appMatch)
                    guard match >= 0.5 else { continue }
                    score = 900 + match * 50 - Double(index) * 0.1
                } else {
                    // Ambient: only unmistakable title hits, ranked below
                    // keyword commands so they never crowd them out.
                    guard titleMatch >= 0.8 else { continue }
                    score = 700 + titleMatch * 100 - Double(index) * 0.1
                }
            }
            items.append(ResultItem(
                title: window.title,
                subtitle: explicit || !term.isEmpty ? "Switch to this \(window.appName) window" : window.appName,
                icon: appIcon(pid: window.pid),
                score: score,
                action: { raise(window) }
            ))
        }
        return Array(items.prefix(explicit ? 20 : 3))
    }

    static func raise(_ window: WindowInfo) {
        NSWorkspace.shared.runningApplications
            .first { $0.processIdentifier == window.pid }?
            .activate(options: [.activateIgnoringOtherApps])
        var target: AXUIElement? = window.element
        if AXUIElementPerformAction(window.element, kAXRaiseAction as CFString) != .success {
            // The cached handle can go stale; re-find the window by title.
            let axApp = AXUIElementCreateApplication(window.pid)
            var ref: CFTypeRef?
            AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &ref)
            target = ((ref as? [AXUIElement]) ?? []).first { title(of: $0) == window.title }
            if let target {
                AXUIElementPerformAction(target, kAXRaiseAction as CFString)
            }
        }
        if let target {
            AXUIElementSetAttributeValue(target, kAXMainAttribute as CFString, kCFBooleanTrue)
        }
    }

    // MARK: - Listing windows

    private static func cachedWindows(query: String) -> [WindowInfo]? {
        if let cache, Date().timeIntervalSince(cache.date) < cacheTTL {
            return cache.windows
        }
        // A cold cache lists once. A stale one only relists when the query
        // text changed since the last listing request and the minimum
        // interval has passed - a notification-triggered re-render (same
        // query) serves the cache as-is, so one completed listing's refresh
        // notification can't schedule the next listing forever.
        if cache == nil
            || (query != lastListQuery
                && Date().timeIntervalSince(lastListStart) >= minRefetchInterval) {
            scheduleListing(query: query)
        }
        // A slightly stale list beats an empty panel while the refresh runs.
        return cache?.windows
    }

    private static func scheduleListing(query: String) {
        guard !listing else { return }
        listing = true
        lastListStart = Date()
        lastListQuery = query
        listQueue.async {
            let windows = onScreenWindows()
            DispatchQueue.main.async {
                listing = false
                cache = (Date(), windows)
                // Reuse the row-upgrade refresh hook the favicon loader uses
                // so the open query re-runs against the fresh list.
                NotificationCenter.default.post(name: .spideyFaviconLoaded, object: nil)
            }
        }
    }

    private static func onScreenWindows() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let list = (CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]) ?? []
        let ownPid = ProcessInfo.processInfo.processIdentifier

        // Front-to-back pids of apps with real (layer 0) windows on screen;
        // the menu bar, Dock, and status items live on other layers.
        var pids: [pid_t] = []
        var seen = Set<pid_t>()
        for info in list {
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let pid = (info[kCGWindowOwnerPID as String] as? Int).map(pid_t.init),
                  pid != ownPid, !seen.contains(pid) else { continue }
            seen.insert(pid)
            pids.append(pid)
        }

        let apps = NSWorkspace.shared.runningApplications
        var windows: [WindowInfo] = []
        for pid in pids {
            guard let app = apps.first(where: { $0.processIdentifier == pid }),
                  app.activationPolicy == .regular else { continue }
            let appName = app.localizedName ?? "App"
            let axApp = AXUIElementCreateApplication(pid)
            // A hung app must not stall the listing for the default six seconds.
            AXUIElementSetMessagingTimeout(axApp, 1.0)
            var ref: CFTypeRef?
            AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &ref)
            for window in (ref as? [AXUIElement]) ?? [] {
                guard !isMinimized(window) else { continue }
                let name = title(of: window)
                guard !name.isEmpty else { continue }
                windows.append(WindowInfo(title: name, appName: appName, pid: pid, element: window))
            }
        }
        return windows
    }

    // MARK: - Accessibility helpers

    private static func title(of element: AXUIElement) -> String {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &ref)
        return (ref as? String) ?? ""
    }

    private static func isMinimized(_ element: AXUIElement) -> Bool {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &ref)
        return (ref as? Bool) ?? false
    }

    private static func appIcon(pid: pid_t) -> ResultIcon {
        guard let image = NSWorkspace.shared.runningApplications
            .first(where: { $0.processIdentifier == pid })?.icon else {
            return .symbol("macwindow.on.rectangle")
        }
        image.size = NSSize(width: 32, height: 32)
        return .appIcon(image)
    }
}
