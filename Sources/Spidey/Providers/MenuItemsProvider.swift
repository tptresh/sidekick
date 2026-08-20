import AppKit
import ApplicationServices

// "menu export pdf": searches the menu bar of the app in front via the
// Accessibility API and presses the matching item. Spidey's own panel is the
// frontmost app while the query runs, so "in front" means the app that owns
// the menu bar (Spidey is LSUIElement, so its panel never does). The menu
// tree is walked off the main thread and cached briefly so typing stays
// snappy. Needs the same one-time Accessibility permission as window
// snapping.
enum MenuItemsProvider {
    struct Entry {
        let title: String
        // Menu titles leading to the item, e.g. ["File", "Export"].
        let path: [String]
        let element: AXUIElement
    }

    private static let maxEntries = 300
    private static let maxDepth = 4

    // Mutated on the main thread only; the walk itself runs on walkQueue.
    private static var cache: (pid: pid_t, date: Date, entries: [Entry])?
    private static var walking = false
    private static var lastWalkStart = Date.distantPast
    private static var lastWalkQuery: String?
    private static let cacheTTL: TimeInterval = 3
    // Regardless of the TTL, never start a new walk this soon after the last
    // one began — repeated AX walks must not sustain themselves.
    private static let minRefetchInterval: TimeInterval = 5
    private static let walkQueue = DispatchQueue(label: "dev.opensource.spidey.menu-walk", qos: .userInitiated)

    static func results(for query: String) -> [ResultItem] {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard lowered == "menu" || lowered.hasPrefix("menu ") else { return [] }
        let term = lowered == "menu"
            ? ""
            : String(lowered.dropFirst("menu ".count)).trimmingCharacters(in: .whitespaces)

        guard let app = targetApp() else { return [] }
        let appName = app.localizedName ?? "the front app"

        guard AXIsProcessTrusted() else {
            return [ResultItem(
                title: "Search \(appName) menus: needs Accessibility access",
                subtitle: "Return opens the permission prompt, then try again",
                icon: .symbol("lock.shield"),
                score: 950,
                action: { WindowProvider.requestPermission() }
            )]
        }

        guard term.count >= 2 else {
            return [ResultItem(
                title: "Search \(appName) menus",
                subtitle: "Keep typing to match a menu item, e.g. menu export",
                icon: .symbol("filemenu.and.selection"),
                score: 950,
                action: {}
            )]
        }

        guard let entries = cachedEntries(for: app, query: lowered) else {
            return [ResultItem(
                title: "Reading \(appName) menus\u{2026}",
                subtitle: "One moment, results appear as you type",
                icon: .symbol("filemenu.and.selection"),
                score: 950,
                action: {}
            )]
        }

        let matches = entries
            .compactMap { entry -> (Entry, Double)? in
                let inTitle = Fuzzy.score(query: term, candidate: entry.title) ?? 0
                let fullPath = (entry.path + [entry.title]).joined(separator: " ")
                let inPath = (Fuzzy.score(query: term, candidate: fullPath) ?? 0) * 0.9
                let match = max(inTitle, inPath)
                return match >= 0.5 ? (entry, match) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(12)

        if matches.isEmpty {
            return [ResultItem(
                title: "No menu item matches \u{201C}\(term)\u{201D}",
                subtitle: "Searched the \(appName) menu bar",
                icon: .symbol("filemenu.and.selection"),
                score: 890,
                action: {}
            )]
        }

        let icon = appIcon(of: app)
        return matches.enumerated().map { index, pair in
            let (entry, match) = pair
            return ResultItem(
                title: entry.title,
                subtitle: "\(appName): " + (entry.path + [entry.title]).joined(separator: " \u{25B8} "),
                icon: icon,
                score: 900 + match * 50 - Double(index) * 0.1,
                action: { press(entry, in: app) }
            )
        }
    }

    // Spidey's panel has key focus while the user types, so the target is the
    // menu bar's owner (unchanged by an LSUIElement panel), falling back to
    // the frontmost or first visible regular app.
    static func targetApp() -> NSRunningApplication? {
        let own = ProcessInfo.processInfo.processIdentifier
        if let owner = NSWorkspace.shared.menuBarOwningApplication,
           owner.processIdentifier != own {
            return owner
        }
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != own, front.activationPolicy == .regular {
            return front
        }
        return NSWorkspace.shared.runningApplications.first {
            $0.activationPolicy == .regular && !$0.isHidden
        }
    }

    private static func press(_ entry: Entry, in app: NSRunningApplication) {
        app.activate(options: [.activateIgnoringOtherApps])
        // Give the target app a beat to take focus so the action lands on it.
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.15) {
            AXUIElementPerformAction(entry.element, kAXPressAction as CFString)
        }
    }

    // MARK: - Walking the menu bar

    private static func cachedEntries(for app: NSRunningApplication, query: String) -> [Entry]? {
        let cached = cache?.pid == app.processIdentifier ? cache : nil
        if let cached, Date().timeIntervalSince(cached.date) < cacheTTL {
            return cached.entries
        }
        // A cold cache walks once. A stale one only rewalks when the query
        // text changed since the last walk request and the minimum interval
        // has passed — a notification-triggered re-render (same query) serves
        // the cache as-is, so one completed walk's refresh notification can't
        // schedule the next walk forever.
        if cached == nil
            || (query != lastWalkQuery
                && Date().timeIntervalSince(lastWalkStart) >= minRefetchInterval) {
            scheduleWalk(of: app, query: query)
        }
        // A slightly stale tree beats an empty panel while the walk runs.
        return cached?.entries
    }

    private static func scheduleWalk(of app: NSRunningApplication, query: String) {
        guard !walking else { return }
        walking = true
        lastWalkStart = Date()
        lastWalkQuery = query
        walkQueue.async {
            let entries = walk(app)
            DispatchQueue.main.async {
                walking = false
                cache = (app.processIdentifier, Date(), entries)
                // Reuse the row-upgrade refresh hook the favicon loader uses
                // so the open query re-runs against the fresh tree.
                NotificationCenter.default.post(name: .spideyFaviconLoaded, object: nil)
            }
        }
    }

    private static func walk(_ app: NSRunningApplication) -> [Entry] {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        // A hung app must not stall the walk for the default six seconds.
        AXUIElementSetMessagingTimeout(axApp, 1.0)
        var barRef: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &barRef)
        guard let barRef, CFGetTypeID(barRef) == AXUIElementGetTypeID() else { return [] }
        let bar = barRef as! AXUIElement

        var collected: [Entry] = []
        for top in children(of: bar) {
            let name = title(of: top)
            // The Apple menu is system-wide noise, not the app's own commands.
            guard !name.isEmpty, name != "Apple" else { continue }
            collect(menusOf: top, path: [name], depth: 0, into: &collected)
        }
        return collected
    }

    // A menu bar item or submenu item holds one AXMenu child whose children
    // are the actual AXMenuItems; separators have empty titles.
    private static func collect(
        menusOf item: AXUIElement, path: [String], depth: Int, into collected: inout [Entry]
    ) {
        guard depth < maxDepth, collected.count < maxEntries else { return }
        for menu in children(of: item) where role(of: menu) == "AXMenu" {
            for child in children(of: menu) {
                guard collected.count < maxEntries else { return }
                let name = title(of: child)
                guard !name.isEmpty, isEnabled(child) else { continue }
                if hasSubmenu(child) {
                    collect(menusOf: child, path: path + [name], depth: depth + 1, into: &collected)
                } else {
                    collected.append(Entry(title: name, path: path, element: child))
                }
            }
        }
    }

    // MARK: - Accessibility helpers

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &ref)
        return (ref as? [AXUIElement]) ?? []
    }

    private static func title(of element: AXUIElement) -> String {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &ref)
        return (ref as? String) ?? ""
    }

    private static func role(of element: AXUIElement) -> String {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &ref)
        return (ref as? String) ?? ""
    }

    private static func isEnabled(_ element: AXUIElement) -> Bool {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &ref)
        return (ref as? Bool) ?? true
    }

    private static func hasSubmenu(_ element: AXUIElement) -> Bool {
        children(of: element).contains { role(of: $0) == "AXMenu" }
    }

    private static func appIcon(of app: NSRunningApplication) -> ResultIcon {
        guard let image = app.icon else { return .symbol("filemenu.and.selection") }
        image.size = NSSize(width: 32, height: 32)
        return .appIcon(image)
    }
}
