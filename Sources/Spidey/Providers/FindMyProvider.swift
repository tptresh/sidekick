import AppKit
import ApplicationServices

// "ping my iphone", "ping airpods", "find my keys": plays a sound on an Apple
// device through the Find My app. macOS has no public Find My API and the
// on-disk cache is TCC-protected, so the only door is the app itself: the
// action launches Find My and drives it with the Accessibility API (switch to
// the right tab, select the device row whose label contains the typed name,
// press Play Sound). Needs the same one-time Accessibility permission as
// window snapping. If a step fails, Find My is left open on the device so
// finishing by hand is one click.
enum FindMyProvider {
    struct Kind {
        let title: String
        let symbol: String
        let matchNames: [String]
        // What to look for in the Find My sidebar row labels.
        let searchTerm: String
    }

    static let kinds: [Kind] = [
        Kind(title: "iPhone", symbol: "iphone", matchNames: ["iphone", "phone"], searchTerm: "iphone"),
        Kind(title: "iPad", symbol: "ipad", matchNames: ["ipad", "tablet"], searchTerm: "ipad"),
        Kind(title: "AirPods", symbol: "airpodspro",
             matchNames: ["airpods", "airpods pro", "airpods max", "earbuds", "headphones"],
             searchTerm: "airpods"),
        Kind(title: "Apple Watch", symbol: "applewatch", matchNames: ["watch", "apple watch"], searchTerm: "watch"),
        Kind(title: "Mac", symbol: "laptopcomputer",
             matchNames: ["mac", "macbook", "laptop", "imac", "mac mini"],
             searchTerm: "mac"),
    ]

    // Named AirTags and shared items live under the Items tab, so terms that
    // sound like tagged belongings search there first.
    private static let itemTerms = [
        "airtag", "air tag", "tag", "keys", "keychain", "wallet", "backpack",
        "bag", "purse", "luggage", "suitcase", "bike", "umbrella",
    ]

    struct Parsed: Equatable {
        // nil term means a bare "ping": offer the common device kinds.
        let term: String?
    }

    // Recognizes "ping <device>", "ping my <device>", "find my <device>",
    // and "where is/are my <device>". Anything else is not for this provider.
    static func parse(_ query: String) -> Parsed? {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        if lowered == "ping" || lowered == "ping my" || lowered == "find my" {
            return Parsed(term: nil)
        }
        let prefixes = ["ping my ", "ping ", "find my ", "where is my ", "where are my ", "where's my "]
        for prefix in prefixes {
            guard lowered.hasPrefix(prefix) else { continue }
            let term = String(lowered.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            return Parsed(term: term.isEmpty ? nil : term)
        }
        return nil
    }

    static func kindMatching(_ term: String) -> Kind? {
        var best: (kind: Kind, score: Double)?
        for kind in kinds {
            let score = kind.matchNames.compactMap { Fuzzy.score(query: term, candidate: $0) }.max() ?? 0
            if score >= 0.7, score > (best?.score ?? 0) {
                best = (kind, score)
            }
        }
        return best?.kind
    }

    static func itemsFirst(_ term: String) -> Bool {
        itemTerms.contains { (Fuzzy.score(query: term, candidate: $0) ?? 0) >= 0.8 }
    }

    static func results(for query: String) -> [ResultItem] {
        guard let parsed = parse(query) else { return [] }

        guard let term = parsed.term else {
            // Bare "ping": one row per common kind, plus a hint that any
            // Find My name works.
            var items = kinds.enumerated().map { index, kind in
                pingItem(
                    title: "Ping \(kind.title)",
                    subtitle: subtitle(),
                    symbol: kind.symbol,
                    score: 880 - Double(index),
                    searchTerm: kind.searchTerm
                )
            }
            items.append(ResultItem(
                title: "Ping any Find My device",
                subtitle: "Type its name, e.g. ping keys or ping my iphone",
                icon: .symbol("dot.radiowaves.left.and.right"),
                score: 870,
                action: {}
            ))
            return items
        }

        if let kind = kindMatching(term) {
            return [pingItem(
                title: "Ping \(kind.title)",
                subtitle: subtitle(),
                symbol: kind.symbol,
                score: 940,
                searchTerm: kind.searchTerm
            )]
        }
        return [pingItem(
            title: "Ping \u{201C}\(term)\u{201D}",
            subtitle: subtitle(named: term),
            symbol: "dot.radiowaves.left.and.right",
            score: 930,
            searchTerm: term
        )]
    }

    private static func subtitle(named term: String? = nil) -> String {
        let what = term.map { "the device named \u{201C}\($0)\u{201D}" } ?? "it"
        return "Plays a sound on \(what) through Find My"
    }

    private static func pingItem(
        title: String, subtitle: String, symbol: String, score: Double, searchTerm: String
    ) -> ResultItem {
        guard AXIsProcessTrusted() else {
            // Same flow as window snapping: first Return opens the system
            // prompt, later ones actually ping.
            return ResultItem(
                title: "\(title): needs Accessibility access",
                subtitle: "Return opens the permission prompt, then try again",
                icon: .symbol("lock.shield"),
                score: score,
                action: { WindowProvider.requestPermission() }
            )
        }
        return ResultItem(
            title: title,
            subtitle: subtitle,
            icon: .symbol(symbol),
            score: score,
            action: { ping(searchTerm: searchTerm) }
        )
    }

    // MARK: - Driving the Find My app

    // Serial so a second Return cannot race a ping already in flight.
    private static let pingQueue = DispatchQueue(label: "dev.opensource.spidey.findmy-ping", qos: .userInitiated)

    static func ping(searchTerm: String) {
        openFindMy()
        let itemsTabFirst = itemsFirst(searchTerm)
        pingQueue.async {
            let outcome = runPing(term: normalized(searchTerm), itemsFirst: itemsTabFirst)
            NSLog("Spidey Find My ping (\(searchTerm)): \(outcome)")
        }
    }

    private static func openFindMy() {
        let url = URL(fileURLWithPath: "/System/Applications/FindMy.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // Find My renders row labels with curly apostrophes ("Tanush’s Keys"), so
    // fold those before the case-insensitive contains check.
    static func normalized(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
    }

    // The observed structure (macOS 15/26, English): sidebar tabs are
    // AXRadioButtons labeled People/Devices/Items, each device or item row is
    // a single AXStaticText ("Tanush’s Keys, Home, 9 min ago"), and pressing a
    // row shows either the full detail (with a "Play Sound,Off" button) or a
    // compact card whose "More Info" button leads to it.
    private static func runPing(term: String, itemsFirst: Bool) -> String {
        guard let window = poll(seconds: 15, { findMyWindow() }) else { return "no-window" }
        // Give a fresh launch a beat to build the sidebar.
        Thread.sleep(forTimeInterval: 0.5)

        let tabs = itemsFirst ? ["items", "devices"] : ["devices", "items"]
        for tab in tabs {
            if let radio = search(window, { role, label in
                role == "AXRadioButton" && normalized(label) == tab
            }) {
                _ = press(radio)
            }
            guard let row = poll(seconds: 4, { search(window, { role, label in
                (role == "AXStaticText" || role == "AXCell") && normalized(label).contains(term)
            }) }) else { continue }
            guard press(row) else { return "row-press-failed" }

            guard let control = poll(seconds: 8, { search(window, { role, label in
                let lowered = normalized(label)
                return role == "AXButton" && (lowered.contains("play sound") || lowered.contains("more info"))
            }) }) else { return "no-detail-controls" }

            var play = control
            if normalized(label(of: control)).contains("more info") {
                guard press(control) else { return "more-info-press-failed" }
                guard let found = poll(seconds: 8, { search(window, { role, label in
                    role == "AXButton" && normalized(label).contains("play sound")
                }) }) else { return "no-play-button" }
                play = found
            }
            // The button label carries the state ("Play Sound,On" while
            // playing); pressing again would stop the sound.
            if normalized(label(of: play)).hasSuffix(",on") { return "already-playing" }
            return press(play) ? "ok" : "play-press-failed"
        }
        return "device-not-found"
    }

    // MARK: - Accessibility helpers

    private static func axString(_ element: AXUIElement, _ attribute: String) -> String? {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &ref)
        return ref as? String
    }

    private static func axChildren(_ element: AXUIElement) -> [AXUIElement] {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &ref)
        return (ref as? [AXUIElement]) ?? []
    }

    private static func label(of element: AXUIElement) -> String {
        [axString(element, kAXDescriptionAttribute), axString(element, kAXTitleAttribute)]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func press(_ element: AXUIElement) -> Bool {
        AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }

    private static func findMyWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.findmy" }) else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &ref)
        return (ref as? [AXUIElement])?.first
    }

    // Depth-first search over the whole window; the budget bounds the walk on
    // pathological trees (the map alone holds hundreds of labeled places).
    private static func search(
        _ root: AXUIElement, budget: Int = 8000, _ predicate: (String, String) -> Bool
    ) -> AXUIElement? {
        var remaining = budget
        return deepFind(root, &remaining, predicate)
    }

    private static func deepFind(
        _ root: AXUIElement, _ budget: inout Int, _ predicate: (String, String) -> Bool
    ) -> AXUIElement? {
        guard budget > 0 else { return nil }
        budget -= 1
        let role = axString(root, kAXRoleAttribute) ?? ""
        if predicate(role, label(of: root)) { return root }
        for child in axChildren(root) {
            if let hit = deepFind(child, &budget, predicate) { return hit }
        }
        return nil
    }

    private static func poll(seconds: TimeInterval, _ find: () -> AXUIElement?) -> AXUIElement? {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if let element = find() { return element }
            Thread.sleep(forTimeInterval: 0.4)
        }
        return nil
    }
}
