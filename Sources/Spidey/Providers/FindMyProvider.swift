import AppKit
import ApplicationServices

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

    // MARK: - Matching names (pure, so it can be tested without Find My)

    // Find My renders labels with curly apostrophes ("Tanush\u{2019}s Keys") and
    // the search field can type curly quotes too, so fold every quote form and
    // collapse runs of spaces before comparing.
    static func normalized(_ text: String) -> String {
        let folded = text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "")
            .replacingOccurrences(of: "\u{201D}", with: "")
            .replacingOccurrences(of: "\"", with: "")
        return folded.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    // A sidebar row reads "Tanush's Keys, Home, 9 min ago": the device name
    // is the part before the location.
    static func deviceName(fromRowLabel label: String) -> String {
        let text = normalized(label)
        guard let comma = text.range(of: ", ") else { return text }
        return String(text[..<comma.lowerBound])
    }

    // Words with apostrophes dropped, so "tanushs" and "tanush" both meet "tanush's".
    private static func words(_ text: String) -> [String] {
        normalized(text)
            .replacingOccurrences(of: "'", with: "")
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    // How well a row label answers the typed term, or nil for no match.
    // 4 exact name, 3 name contains the term, 2 every typed word starts a word
    // of the name ("tanush iphone" for "Tanush's iPhone"), 1 the term only
    // appears further along the label (its location line).
    static func matchRank(label: String, term: String) -> Int? {
        let term = normalized(term)
        guard !term.isEmpty else { return nil }
        let name = deviceName(fromRowLabel: label)
        if name == term { return 4 }
        if name.contains(term) { return 3 }
        let typed = words(term).filter { $0 != "my" && $0 != "the" }
        let nameWords = words(name)
        if !typed.isEmpty, typed.allSatisfy({ word in nameWords.contains { $0.hasPrefix(word) } }) {
            return 2
        }
        return normalized(label).contains(term) ? 1 : nil
    }

    // Index of the label that best answers the term. A device whose name
    // carries the Mac user's first name counts as yours. For a device-kind
    // search ("ping my iphone", "ping airpods pro") any name match of yours
    // beats a family device, even one left with the bare default name
    // "iPhone". For any other term (a full name like "mum's iphone") the
    // closest name wins and being yours only breaks ties. Location-only
    // matches always come after name matches; the earlier row breaks the
    // remaining ties.
    static func bestMatch(_ labels: [String], term: String, owner: String?) -> Int? {
        let ownerWord = owner.flatMap { words($0).first }
        let kindSearch = isKindTerm(term)
        var best: (index: Int, key: [Int])?
        for (index, label) in labels.enumerated() {
            guard let rank = matchRank(label: label, term: term) else { continue }
            let mine = ownerWord.map { owner in
                words(deviceName(fromRowLabel: label)).contains { $0.hasPrefix(owner) }
            } ?? false
            let byName = rank >= 2 ? 1 : 0
            let key = kindSearch ? [byName, mine ? 1 : 0, rank] : [rank, mine ? 1 : 0]
            if let current = best, current.key.lexicographicallyPrecedes(key) == false { continue }
            best = (index, key)
        }
        return best?.index
    }

    // True when the term names a kind of device rather than one device.
    static func isKindTerm(_ term: String) -> Bool {
        let term = normalized(term)
        return kinds.contains { $0.searchTerm == term || $0.matchNames.contains(term) }
    }

    // Which button of a confirmation sheet to press after Play Sound, if any.
    // Never anything that cancels or stops.
    static func confirmationChoice(_ labels: [String]) -> Int? {
        let lowered = labels.map(normalized)
        let refuse = ["cancel", "stop", "don't", "dont", "not now"]
        for wanted in ["play sound", "play", "continue", "ok"] {
            if let index = lowered.firstIndex(where: { label in
                label.contains(wanted) && !refuse.contains { label.contains($0) }
            }) {
                return index
            }
        }
        return nil
    }

    // MARK: - Outcomes and what the user is told

    enum Outcome: String, CaseIterable {
        case ok
        case noAccessibility, couldNotLaunch, noWindow, notReady
        case deviceNotFound, rowPressFailed, noPlayButton, playUnavailable, playPressFailed

        // Only steps after the device row was found are worth a second pass:
        // a device missing from the list will still be missing, but a press
        // that landed mid-render often sticks the second time.
        var isRetryable: Bool {
            self == .rowPressFailed || self == .noPlayButton || self == .playPressFailed
        }
    }

    static func failureMessage(_ outcome: Outcome, term: String) -> String {
        let onDevice = "Find My is open on it, so pressing Play Sound there finishes the job."
        switch outcome {
        case .ok:
            return ""
        case .noAccessibility:
            return "Spidey needs Accessibility permission to press Play Sound in Find My. "
                + "Turn it on in System Settings > Privacy & Security > Accessibility, then ping again. "
                + "Find My is open meanwhile."
        case .couldNotLaunch:
            return "Find My could not be opened. Try opening Find My from the Applications folder."
        case .noWindow:
            return "Find My did not show a window in time. It is open now: pick the device and press Play Sound."
        case .notReady:
            return "Find My opened but its device list did not load, so it may still be signing in to iCloud. "
                + "Pick the device in Find My once the list appears."
        case .deviceNotFound:
            return "Nothing called \u{201C}\(term)\u{201D} is in the Devices or Items list in Find My. "
                + "Find My is open on the list so you can check the name."
        case .rowPressFailed:
            return "Find My would not open its row. Find My is open on the list: click the device, then Play Sound."
        case .noPlayButton:
            return "Find My did not show a Play Sound button for it. " + onDevice
        case .playUnavailable:
            return "Play Sound is greyed out in Find My, so the device is probably offline, switched off or out of range. "
                + "Find My is open on it."
        case .playPressFailed:
            return "Find My did not accept the Play Sound press. " + onDevice
        }
    }

    // MARK: - Driving the Find My app

    // Serial so a second Return cannot race a ping already in flight.
    private static let pingQueue = DispatchQueue(label: "dev.opensource.spidey.findmy-ping", qos: .userInitiated)

    static func ping(searchTerm: String) {
        guard AXIsProcessTrusted() else {
            // Permission was withdrawn after the row was drawn: open Find My
            // anyway so the user can finish by hand, and say why nothing rang.
            openFindMy()
            WindowProvider.requestPermission()
            report(.noAccessibility, term: searchTerm)
            return
        }
        let itemsTabFirst = itemsFirst(searchTerm)
        openFindMy { launched in
            guard launched else {
                report(.couldNotLaunch, term: searchTerm)
                return
            }
            pingQueue.async {
                let outcome = runPing(term: normalized(searchTerm), itemsFirst: itemsTabFirst)
                NSLog("Spidey Find My ping (\(searchTerm)): \(outcome.rawValue)")
                if outcome != .ok {
                    report(outcome, term: searchTerm)
                }
            }
        }
    }

    private static func openFindMy(completion: ((Bool) -> Void)? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { openFindMy(completion: completion) }
            return
        }
        let url = URL(fileURLWithPath: "/System/Applications/FindMy.app")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, error in
            if let error { NSLog("Spidey could not open Find My: \(error)") }
            completion?(app != nil || findMyApp() != nil)
        }
    }

    private static func findMyApp() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.findmy" }
    }

    private static func runPing(term: String, itemsFirst: Bool) -> Outcome {
        let outcome = attemptPing(term: term, itemsFirst: itemsFirst)
        guard outcome.isRetryable else { return outcome }
        openFindMy()
        _ = poll(seconds: 3) { readyWindow() }
        return attemptPing(term: term, itemsFirst: itemsFirst)
    }

    // The observed structure (macOS 15/26, English): sidebar tabs are
    // AXRadioButtons labeled People/Devices/Items, each device or item row is
    // a single AXStaticText ("Tanush's Keys, Home, 9 min ago"), and pressing a
    // row shows either the full detail (with a "Play Sound,Off" button) or a
    // compact card whose "More Info" button leads to it.
    private static func attemptPing(term: String, itemsFirst: Bool) -> Outcome {
        guard let window = waitForReadyWindow() else {
            return anyWindow() == nil ? .noWindow : .notReady
        }

        let tabs = itemsFirst ? ["items", "devices"] : ["devices", "items"]
        for (index, tab) in tabs.enumerated() {
            guard selectTab(tab, in: window) else { continue }
            // The sidebar fills in from iCloud after the window is already on
            // screen, so the first tab waits out a cold launch. By the time the
            // second one is tried the list has loaded and a miss is a real miss.
            guard let (row, name) = poll(seconds: index == 0 ? 10 : 4, { deviceRow(in: window, term: term) })
            else { continue }
            guard activate(row, in: window) else { return .rowPressFailed }
            // The press that opens the detail pane is the flaky step: if the
            // pane never names the device, press the row once more before
            // settling for whatever Play Sound button is showing.
            var play = findPlayButton(in: window, name: name, seconds: 6)
            if play == nil, activate(row, in: window) {
                play = findPlayButton(in: window, name: name, seconds: 4)
            }
            guard let play = play ?? findPlayButton(in: window, name: nil, seconds: 2) else {
                return .noPlayButton
            }
            return pressPlay(play, in: window)
        }
        // Leave the list the user asked for on screen so finishing by hand is
        // one click rather than a hunt through the wrong tab.
        _ = selectTab(tabs[0], in: window)
        return .deviceNotFound
    }

    // Waits for a window with the People/Devices/Items tabs. A window that
    // shows up without them after a few seconds usually has its sidebar
    // hidden, so ask Find My to show it once.
    private static func waitForReadyWindow() -> AXUIElement? {
        if let window = poll(seconds: 6, { readyWindow() }) { return window }
        if anyWindow() != nil { _ = pressMenuItem(named: "show sidebar") }
        return poll(seconds: 9) { readyWindow() }
    }

    // The Play Sound button toggles and its label carries the state, so a
    // single press on a device that is already ringing would silence it. Stop
    // first, then start, so a ping always ends in a fresh sound. A greyed-out
    // button means the device cannot be reached right now.
    private static func pressPlay(_ play: AXUIElement, in window: AXUIElement) -> Outcome {
        guard poll(seconds: 3, { isEnabled(play) ? true : nil }) != nil else { return .playUnavailable }
        if isRinging(play) {
            _ = press(play)
            _ = poll(seconds: 3) { isRinging(play) ? nil : true }
        }
        guard press(play) else { return .playPressFailed }
        confirmIfAsked(in: window)
        return .ok
    }

    private static func isRinging(_ play: AXUIElement) -> Bool {
        let node = Node(play)
        return node.has(",on") || node.has(", on")
    }

    // Some devices put a confirmation sheet in front of the sound. Press its
    // go-ahead button if one appears within a couple of seconds.
    private static func confirmIfAsked(in window: AXUIElement) {
        _ = poll(seconds: 2) { () -> Bool? in
            guard let sheet = search(window, budget: 400, { $0.role == "AXSheet" }) ?? dialogWindow()
            else { return nil }
            let buttons = searchAll(sheet, budget: 300, limit: 8) { $0.role == "AXButton" }
            let labels = buttons.map { Node($0).labels.joined(separator: " ") }
            if let choice = confirmationChoice(labels) { _ = press(buttons[choice]) }
            return true
        }
    }

    // MARK: - Locating the pieces

    private static let tabNames = ["people", "devices", "items"]

    private static func appElement() -> AXUIElement? {
        guard let app = findMyApp() else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        // Bound every accessibility call, so one unanswered query cannot eat a
        // whole poll window (the default wait is six seconds per message).
        _ = AXUIElementSetMessagingTimeout(axApp, 2)
        return axApp
    }

    private static func windows() -> [AXUIElement] {
        guard let axApp = appElement() else { return [] }
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &ref)
        return (ref as? [AXUIElement]) ?? []
    }

    private static func anyWindow() -> AXUIElement? { windows().first }

    private static func dialogWindow() -> AXUIElement? {
        windows().first { axString($0, kAXSubroleAttribute) == "AXDialog" }
    }

    // Find My can own more than one window and builds its sidebar a moment
    // after the first one appears, so "ready" means a window that already shows
    // the People/Devices/Items tabs. A minimized window is brought back first,
    // since its controls do not answer presses from the Dock.
    private static func readyWindow() -> AXUIElement? {
        for window in windows() {
            if axBool(window, kAXMinimizedAttribute) == true {
                AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            }
            if tabButton(nil, in: window) != nil {
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                return window
            }
        }
        return nil
    }

    private static func pressMenuItem(named title: String) -> Bool {
        guard let axApp = appElement() else { return false }
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &ref) == .success,
              let value = ref, CFGetTypeID(value) == AXUIElementGetTypeID() else { return false }
        let menuBar = unsafeBitCast(value, to: AXUIElement.self)
        guard let item = search(menuBar, budget: 800, { $0.role == "AXMenuItem" && $0.isExactly(title) })
        else { return false }
        return press(item)
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
                if poll(seconds: 1.5, { selectionState(radio) == true ? true : nil }) != nil { return true }
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
    // answers a press, so prefer candidates that offer one, then the best name
    // match among them. Returns the row and the device name it shows.
    private static func deviceRow(in window: AXUIElement, term: String) -> (AXUIElement, String)? {
        let matches = searchAll(window, limit: 12) { node in
            (node.role == "AXStaticText" || node.role == "AXCell" || node.role == "AXRow")
                && matchRank(label: node.labels.joined(separator: " "), term: term) != nil
        }
        let pressable = matches.filter { pressTarget(for: $0) != nil }
        let pool = pressable.isEmpty ? matches : pressable
        let labels = pool.map { Node($0).labels.joined(separator: " ") }
        guard let index = bestMatch(labels, term: term, owner: NSFullUserName()) else { return nil }
        let name = deviceName(fromRowLabel: labels[index])
        return (pool[index], name.isEmpty ? term : name)
    }

    // The detail pane keeps the previous device on screen for a beat after a
    // new row is pressed, so a Play Sound button found straight away can still
    // belong to the last device. Wait for one sitting next to the device's
    // name; a nil name accepts any Play Sound button.
    private static func findPlayButton(
        in window: AXUIElement, name: String?, seconds: TimeInterval
    ) -> AXUIElement? {
        var openedMoreInfo = false
        return poll(seconds: seconds) { () -> AXUIElement? in
            let controls = searchAll(window, limit: 6) { node in
                node.role == "AXButton" && (node.has("play sound") || node.has("more info"))
            }
            let scoped = controls.filter { button in
                guard let name else { return true }
                return context(of: button, mentions: name, in: window)
            }
            if let play = scoped.first(where: { Node($0).has("play sound") }) { return play }
            // A compact card only offers More Info; the real controls are one
            // step further in.
            if !openedMoreInfo, let more = scoped.first {
                openedMoreInfo = press(more)
            }
            return nil
        }
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

    private static func isEnabled(_ element: AXUIElement) -> Bool {
        axBool(element, kAXEnabledAttribute) ?? true
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
    // the window, so a stale frame cannot put the click somewhere else. A
    // click only lands if Find My is in front, so wait until it is.
    private static func click(_ element: AXUIElement, in window: AXUIElement) -> Bool {
        guard let row = frame(of: element), let bounds = frame(of: window) else { return false }
        let visible = bounds.intersection(row)
        guard visible.width > 2, visible.height > 2 else { return false }
        openFindMy()
        guard poll(seconds: 2, { findMyApp()?.isActive == true ? true : nil }) != nil else { return false }
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

    private static func axBool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success else { return nil }
        return (ref as? NSNumber)?.boolValue
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
            Thread.sleep(forTimeInterval: 0.3)
        } while Date() < deadline
        return nil
    }

    // MARK: - Telling the user when it did not work

    // Without this a failed ping looks exactly like a working one: Find My
    // comes to the front and the device stays silent. Find My is brought
    // forward again so the message and the place to finish are side by side.
    private static func report(_ outcome: Outcome, term: String) {
        if outcome != .couldNotLaunch { openFindMy() }
        SystemProvider.tellUser(title: "Could not ping \(term)", body: failureMessage(outcome, term: term))
    }
}
