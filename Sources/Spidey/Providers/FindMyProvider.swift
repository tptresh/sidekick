import AppKit
import ApplicationServices
import UserNotifications

// "ping my iphone", "ping airpods", "find my keys": plays a sound on an Apple
// device through the Find My app. macOS has no public Find My API and the
// on-disk cache is TCC-protected, so the only door is the app itself: the
// action launches Find My and drives it with the Accessibility API (switch to
// the right tab, select the device row whose label contains the typed name,
// press Play Sound). Needs the same one-time Accessibility permission as
// window snapping.
//
// Find My fills its sidebar from iCloud well after its window appears, and
// leaves the previously selected device on screen while the next one loads, so
// nothing here assumes a step has landed: the tab switch is confirmed, the row
// is waited for, and Play Sound is only pressed once the pane around it names
// the device that was asked for. If a step still fails, Find My is left open
// on the list and a notification says why, so a silent phone is never a
// mystery.
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

    private static let okOutcome = "ok"

    static func ping(searchTerm: String) {
        openFindMy()
        let itemsTabFirst = itemsFirst(searchTerm)
        pingQueue.async {
            let outcome = runPing(term: normalized(searchTerm), itemsFirst: itemsTabFirst)
            NSLog("Spidey Find My ping (\(searchTerm)): \(outcome)")
            if outcome != okOutcome {
                report(failure: outcome, term: searchTerm)
            }
        }
    }

    private static func openFindMy() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { openFindMy() }
            return
        }
        let url = URL(fileURLWithPath: "/System/Applications/FindMy.app")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    private static func findMyApp() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.findmy" }
    }

    // Find My renders row labels with curly apostrophes ("Tanush's Keys"), so
    // fold those before the case-insensitive contains check.
    static func normalized(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
    }

    // Only failures that happened after the device row was found are worth a
    // second pass: a device missing from the list will still be missing, but a
    // press that landed mid-render often sticks the second time.
    private static let retryableOutcomes: Set<String> = [
        "row-press-failed", "no-play-button", "play-press-failed",
    ]

    private static func runPing(term: String, itemsFirst: Bool) -> String {
        let outcome = attemptPing(term: term, itemsFirst: itemsFirst)
        guard retryableOutcomes.contains(outcome) else { return outcome }
        openFindMy()
        Thread.sleep(forTimeInterval: 1)
        return attemptPing(term: term, itemsFirst: itemsFirst)
    }

    // The observed structure (macOS 15/26, English): sidebar tabs are
    // AXRadioButtons labeled People/Devices/Items, each device or item row is
    // a single AXStaticText ("Tanush's Keys, Home, 9 min ago"), and pressing a
    // row shows either the full detail (with a "Play Sound,Off" button) or a
    // compact card whose "More Info" button leads to it.
    private static func attemptPing(term: String, itemsFirst: Bool) -> String {
        guard let window = poll(seconds: 15, { readyWindow() }) else { return "no-window" }

        let tabs = itemsFirst ? ["items", "devices"] : ["devices", "items"]
        for (index, tab) in tabs.enumerated() {
            guard selectTab(tab, in: window) else { continue }
            // The sidebar fills in from iCloud after the window is already on
            // screen, so the first tab waits out a cold launch. By the time the
            // second one is tried the list has loaded and a miss is a real miss.
            guard let row = poll(seconds: index == 0 ? 10 : 4, { deviceRow(in: window, term: term) })
            else { continue }
            guard activate(row, in: window) else { return "row-press-failed" }
            // Let the detail pane swap over before reading it.
            Thread.sleep(forTimeInterval: 0.8)
            guard let play = playButton(in: window, term: term) else { return "no-play-button" }
            return pressPlay(play)
        }
        // Leave the list the user asked for on screen so finishing by hand is
        // one click rather than a hunt through the wrong tab.
        _ = selectTab(tabs[0], in: window)
        return "device-not-found"
    }

    // The Play Sound button toggles and its label carries the state, so a
    // single press on a device that is already ringing would silence it. Stop
    // first, then start, so a ping always ends in a fresh sound.
    private static func pressPlay(_ play: AXUIElement) -> String {
        let node = Node(play)
        if node.has(",on") || node.has(", on") {
            _ = press(play)
            Thread.sleep(forTimeInterval: 0.8)
        }
        return press(play) ? okOutcome : "play-press-failed"
    }

    // MARK: - Locating the pieces

    private static let tabNames = ["people", "devices", "items"]

    // Find My can own more than one window and builds its sidebar a moment
    // after the first one appears, so "ready" means a window that already shows
    // the People/Devices/Items tabs.
    private static func readyWindow() -> AXUIElement? {
        guard let app = findMyApp() else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        // Bound every accessibility call, so one unanswered query cannot eat a
        // whole poll window (the default wait is six seconds per message).
        _ = AXUIElementSetMessagingTimeout(axApp, 2)
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &ref)
        for window in (ref as? [AXUIElement]) ?? [] where tabButton(nil, in: window) != nil {
            return window
        }
        return nil
    }

    private static func tabButton(_ name: String?, in window: AXUIElement) -> AXUIElement? {
        search(window) { node in
            guard node.role == "AXRadioButton" else { return false }
            guard let name else { return tabNames.contains { node.isExactly($0) } }
            return node.isExactly(name)
        }
    }

    // Pressing the tab that is already showing is a no-op, and a press sent
    // during the launch animation gets dropped, so confirm the switch stuck
    // before trusting the list underneath it.
    private static func selectTab(_ name: String, in window: AXUIElement) -> Bool {
        guard let radio = poll(seconds: 4, { tabButton(name, in: window) }) else { return false }
        for attempt in 0..<3 {
            switch selectionState(radio) {
            case true?:
                return true
            case nil:
                // No selection state exposed: the press itself is all we get.
                if attempt == 0 { _ = press(radio) }
                Thread.sleep(forTimeInterval: 0.5)
                return true
            default:
                _ = press(radio)
                Thread.sleep(forTimeInterval: 0.6)
            }
        }
        return selectionState(radio) == true
    }

    private static func selectionState(_ element: AXUIElement) -> Bool? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &ref) == .success,
              let number = ref as? NSNumber else { return nil }
        return number.intValue != 0
    }

    // Several things in the window can carry the device's name at once: the
    // sidebar row, the detail header, a label on the map. Only the sidebar row
    // answers a press, so prefer a candidate that offers one.
    private static func deviceRow(in window: AXUIElement, term: String) -> AXUIElement? {
        let matches = searchAll(window, limit: 8) { node in
            (node.role == "AXStaticText" || node.role == "AXCell" || node.role == "AXRow")
                && node.has(term)
        }
        return matches.first { pressTarget(for: $0) != nil } ?? matches.first
    }

    // The detail pane keeps the previous device on screen for a beat after a
    // new row is pressed, so a Play Sound button found straight away can still
    // belong to the last device. Wait for one sitting next to the name that was
    // asked for; only if the pane never names it at all fall back to any Play
    // Sound button, which beats doing nothing.
    private static func playButton(in window: AXUIElement, term: String) -> AXUIElement? {
        findPlayButton(in: window, term: term, seconds: 8)
            ?? findPlayButton(in: window, term: nil, seconds: 2)
    }

    private static func findPlayButton(
        in window: AXUIElement, term: String?, seconds: TimeInterval
    ) -> AXUIElement? {
        let deadline = Date().addingTimeInterval(seconds)
        var openedMoreInfo = false
        repeat {
            let controls = searchAll(window, limit: 6) { node in
                node.role == "AXButton" && (node.has("play sound") || node.has("more info"))
            }
            let scoped = controls.filter { button in
                guard let term else { return true }
                return context(of: button, mentions: term, in: window)
            }
            if let play = scoped.first(where: { Node($0).has("play sound") }) { return play }
            // A compact card only offers More Info; the real controls are one
            // step further in.
            if !openedMoreInfo, let more = scoped.first {
                openedMoreInfo = press(more)
            }
            Thread.sleep(forTimeInterval: 0.4)
        } while Date() < deadline
        return nil
    }

    // Walks a few containers out from the button looking for the device name.
    // Stops short of the window itself, whose subtree always holds the name by
    // way of the sidebar row.
    private static func context(of element: AXUIElement, mentions term: String, in window: AXUIElement) -> Bool {
        let text = ["AXStaticText", "AXHeading", "AXTextField"]
        var current = parent(of: element)
        for _ in 0..<5 {
            guard let container = current, !CFEqual(container, window) else { return false }
            if search(container, budget: 300, { text.contains($0.role) && $0.has(term) }) != nil {
                return true
            }
            current = parent(of: container)
        }
        return false
    }

    // MARK: - Pressing things

    private static func press(_ element: AXUIElement) -> Bool {
        AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }

    // A row is only sometimes pressable itself; often the press action lives on
    // the cell or the group wrapping its label.
    private static func pressTarget(for element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element
        for _ in 0..<4 {
            guard let candidate = current else { return nil }
            if actionNames(candidate).contains(kAXPressAction) { return candidate }
            current = parent(of: candidate)
        }
        return nil
    }

    private static func activate(_ row: AXUIElement, in window: AXUIElement) -> Bool {
        if let target = pressTarget(for: row), press(target) { return true }
        if select(row) { return true }
        return click(row, in: window)
    }

    private static func select(_ element: AXUIElement) -> Bool {
        var current: AXUIElement? = element
        for _ in 0..<4 {
            guard let candidate = current else { return false }
            let done = AXUIElementSetAttributeValue(
                candidate, kAXSelectedAttribute as CFString, kCFBooleanTrue
            )
            if done == .success { return true }
            current = parent(of: candidate)
        }
        return false
    }

    // Last resort when a row answers neither a press nor a selection: click it
    // the way a person would. Clamped to the part of the row actually inside
    // the window, so a stale frame cannot put the click somewhere else.
    private static func click(_ element: AXUIElement, in window: AXUIElement) -> Bool {
        guard let row = frame(of: element), let bounds = frame(of: window) else { return false }
        let visible = bounds.intersection(row)
        guard visible.width > 2, visible.height > 2 else { return false }
        openFindMy()
        Thread.sleep(forTimeInterval: 0.4)
        let point = CGPoint(x: visible.midX, y: visible.midY)
        guard let down = CGEvent(
            mouseEventSource: nil, mouseType: .leftMouseDown,
            mouseCursorPosition: point, mouseButton: .left
        ), let up = CGEvent(
            mouseEventSource: nil, mouseType: .leftMouseUp,
            mouseCursorPosition: point, mouseButton: .left
        ) else { return false }
        down.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.08)
        up.post(tap: .cghidEventTap)
        return true
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

    private static func parent(of element: AXUIElement) -> AXUIElement? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &ref) == .success,
              let value = ref, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private static func actionNames(_ element: AXUIElement) -> [String] {
        var ref: CFArray?
        guard AXUIElementCopyActionNames(element, &ref) == .success else { return [] }
        return (ref as? [String]) ?? []
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let position = positionRef, CFGetTypeID(position) == AXValueGetTypeID(),
              let size = sizeRef, CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(position, to: AXValue.self), .cgPoint, &origin),
              AXValueGetValue(unsafeBitCast(size, to: AXValue.self), .cgSize, &extent) else { return nil }
        return CGRect(origin: origin, size: extent)
    }

    // One element's role and labels. The labels are fetched only when a
    // predicate asks for them, which keeps a whole-window sweep down to a
    // couple of accessibility messages per element.
    private final class Node {
        let element: AXUIElement
        let role: String
        private var fetched: [String]?

        init(_ element: AXUIElement) {
            self.element = element
            self.role = axString(element, kAXRoleAttribute) ?? ""
        }

        var labels: [String] {
            if let fetched { return fetched }
            let values = [kAXDescriptionAttribute, kAXTitleAttribute, kAXValueAttribute]
                .compactMap { axString(element, $0) }
                .filter { !$0.isEmpty }
            fetched = values
            return values
        }

        // `needle` is expected to be normalized already.
        func has(_ needle: String) -> Bool {
            normalized(labels.joined(separator: " ")).contains(needle)
        }

        func isExactly(_ value: String) -> Bool {
            labels.contains { normalized($0) == value }
        }
    }

    // Breadth-first so the shallowest match wins: window chrome and sidebar
    // rows sit near the root, while the map's hundreds of place labels are
    // buried deep. The budget bounds the walk on pathological trees.
    private static func search(
        _ root: AXUIElement, budget: Int = 6000, _ predicate: (Node) -> Bool
    ) -> AXUIElement? {
        searchAll(root, budget: budget, limit: 1, predicate).first
    }

    private static func searchAll(
        _ root: AXUIElement, budget: Int = 6000, limit: Int, _ predicate: (Node) -> Bool
    ) -> [AXUIElement] {
        var queue = [root]
        var index = 0
        var found: [AXUIElement] = []
        while index < queue.count, index < budget {
            let element = queue[index]
            index += 1
            if predicate(Node(element)) {
                found.append(element)
                if found.count >= limit { return found }
            }
            queue.append(contentsOf: axChildren(element))
        }
        return found
    }

    private static func poll<Value>(seconds: TimeInterval, _ find: () -> Value?) -> Value? {
        let deadline = Date().addingTimeInterval(seconds)
        repeat {
            if let value = find() { return value }
            Thread.sleep(forTimeInterval: 0.4)
        } while Date() < deadline
        return nil
    }

    // MARK: - Telling the user when it did not work

    private static let failureReasons: [String: String] = [
        "no-window": "Find My did not open a window in time.",
        "device-not-found": "It is not in the Devices or Items list.",
        "row-press-failed": "Its row in Find My would not open.",
        "no-play-button": "Find My did not offer Play Sound for it.",
        "play-press-failed": "Find My refused the Play Sound press.",
    ]

    // Without this a failed ping looks exactly like a working one: Find My
    // comes to the front and the device stays silent.
    private static func report(failure outcome: String, term: String) {
        let reason = failureReasons[outcome] ?? "Find My did not respond as expected."
        DispatchQueue.main.async {
            NSSound(named: "Funk")?.play()
            // Notifications need a real app bundle; skip them when running
            // bare from .build during development.
            guard Bundle.main.bundleIdentifier != nil else { return }
            let content = UNMutableNotificationContent()
            content.title = "Could not ping \(term)"
            content.body = "\(reason) Find My is open if you want to finish by hand."
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            )
        }
    }
}
