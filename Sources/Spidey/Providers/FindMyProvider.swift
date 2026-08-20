import AppKit
import ApplicationServices

// "ping my iphone", "ping airpods", "find my keys": plays a sound on an Apple
// device through the Find My app. macOS has no public Find My API and the
// on-disk cache is TCC-protected, so the only door is the app itself: the
// action launches Find My and drives it with accessibility scripting (switch
// to the right tab, select the device row whose label contains the typed name,
// press Play Sound). Needs the same one-time Accessibility permission as
// window snapping. If any step fails, Find My is left open on the device so
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

    static func ping(searchTerm: String) {
        openFindMy()
        let script = pingScript(searchTerm: searchTerm, itemsFirst: itemsFirst(searchTerm))
        DispatchQueue.global(qos: .userInitiated).async {
            let output = Shell.run("/usr/bin/osascript", ["-e", script])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if output != "OK" {
                // Find My stays open (usually on the device), so the user can
                // finish with one click even when the script could not.
                NSLog("Spidey Find My ping (\(searchTerm)): \(output)")
            }
        }
    }

    private static func openFindMy() {
        let url = URL(fileURLWithPath: "/System/Applications/FindMy.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    static func escapeForAppleScript(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // Find My's UI is a Catalyst tree with no stable element paths across
    // macOS versions, so the script searches by accessibility label instead:
    // switch tab (View menu first, sidebar buttons as fallback), find the row
    // containing the device name, press it, then press Play Sound (context
    // menu as fallback). AppleScript's `contains` ignores case by default,
    // which is exactly the matching we want.
    static func pingScript(searchTerm: String, itemsFirst: Bool) -> String {
        let term = escapeForAppleScript(searchTerm)
        let firstTab = itemsFirst ? "Items" : "Devices"
        let secondTab = itemsFirst ? "Devices" : "Items"
        return """
        on labelOf(el)
            set out to ""
            tell application "System Events"
                try
                    set d to description of el
                    if d is not missing value then set out to out & d & " "
                end try
                try
                    set n to name of el
                    if n is not missing value then set out to out & n
                end try
            end tell
            return out
        end labelOf

        on findFirst(el, target, roleList, depth)
            if depth < 1 then return missing value
            set kids to {}
            try
                tell application "System Events" to set kids to UI elements of el
            end try
            repeat with k in kids
                set r to ""
                try
                    tell application "System Events" to set r to role of k
                end try
                if ((count of roleList) is 0) or (roleList contains r) then
                    if (my labelOf(k)) contains target then return (contents of k)
                end if
                set hit to my findFirst(k, target, roleList, depth - 1)
                if hit is not missing value then return hit
            end repeat
            return missing value
        end findFirst

        on climbToRow(el)
            tell application "System Events"
                set cur to el
                repeat 6 times
                    try
                        set p to value of attribute "AXParent" of cur
                        set r to role of p
                        if r is "AXCell" or r is "AXRow" then return (contents of p)
                        set cur to p
                    on error
                        exit repeat
                    end try
                end repeat
            end tell
            return el
        end climbToRow

        on clickEl(el)
            tell application "System Events"
                try
                    perform action "AXPress" of el
                    return true
                end try
                try
                    click el
                    return true
                end try
                try
                    set p to position of el
                    set s to size of el
                    set cx to (item 1 of p) + ((item 1 of s) div 2)
                    set cy to (item 2 of p) + ((item 2 of s) div 2)
                    tell process "FindMy" to click at {cx, cy}
                    return true
                end try
            end tell
            return false
        end clickEl

        on switchTab(tabName)
            tell application "System Events"
                tell process "FindMy"
                    try
                        click menu item tabName of menu 1 of menu bar item "View" of menu bar 1
                        return true
                    end try
                end tell
                set w to window 1 of process "FindMy"
            end tell
            set tabEl to my findFirst(w, tabName, {"AXRadioButton", "AXButton", "AXTabButton"}, 10)
            if tabEl is not missing value then return my clickEl(tabEl)
            return false
        end switchTab

        on findDeviceRow(target)
            tell application "System Events" to set w to window 1 of process "FindMy"
            set rowEl to my findFirst(w, target, {"AXCell", "AXRow"}, 16)
            if rowEl is missing value then
                set txt to my findFirst(w, target, {"AXStaticText"}, 16)
                if txt is not missing value then set rowEl to my climbToRow(txt)
            end if
            return rowEl
        end findDeviceRow

        on findPlayControl(scope)
            set el to my findFirst(scope, "Play Sound", {"AXButton", "AXMenuItem", "AXCell", "AXMenuButton"}, 16)
            if el is missing value then set el to my findFirst(scope, "Play Sound", {"AXStaticText"}, 16)
            return el
        end findPlayControl

        set target to "\(term)"
        set firstTab to "\(firstTab)"
        set secondTab to "\(secondTab)"

        set deadline to (current date) + 20
        tell application "System Events"
            repeat until (exists process "FindMy")
                if (current date) > deadline then return "ERR|not-running"
                delay 0.2
            end repeat
            tell process "FindMy"
                set frontmost to true
                repeat until (exists window 1)
                    if (current date) > deadline then return "ERR|no-window"
                    delay 0.2
                end repeat
            end tell
        end tell
        delay 1

        my switchTab(firstTab)
        delay 0.7
        set rowEl to my findDeviceRow(target)
        if rowEl is missing value then
            if my switchTab(secondTab) then
                delay 0.7
                set rowEl to my findDeviceRow(target)
            end if
        end if
        if rowEl is missing value then return "ERR|no-device"

        my clickEl(rowEl)
        delay 1

        tell application "System Events" to set w to window 1 of process "FindMy"
        set playEl to my findPlayControl(w)
        if playEl is missing value then
            try
                tell application "System Events" to perform action "AXShowMenu" of rowEl
                delay 0.5
                set playEl to my findPlayControl(rowEl)
            end try
            if playEl is missing value then set playEl to my findPlayControl(w)
        end if
        if playEl is missing value then return "SELECTED|no-play-control"
        if my clickEl(playEl) then return "OK"
        return "SELECTED|click-failed"
        """
    }
}
