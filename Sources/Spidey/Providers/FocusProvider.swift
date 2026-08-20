import AppKit

// Focus mode switching. macOS has no public API for changing Focus (the database
// under ~/Library/DoNotDisturb is TCC-protected), so Spidey drives Apple Shortcuts:
// any shortcut named "Focus: <Mode>" (for example "Focus: Do Not Disturb",
// "Focus: Work", "Focus: Off") becomes a command. The shortcut itself holds a
// single "Set Focus" action; Spidey just runs it by name.
enum FocusProvider {
    static let shortcutPrefix = "focus:"

    // Cached names from `shortcuts list`, refreshed in the background so the
    // synchronous per-keystroke query path never shells out.
    private static var cachedModes: [String] = []
    private static var lastRefresh = Date.distantPast
    private static var refreshInFlight = false

    static func results(for query: String) -> [ResultItem] {
        refreshIfStale()

        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !lowered.isEmpty else { return [] }

        guard !cachedModes.isEmpty else {
            return setupResults(for: lowered)
        }

        var items: [ResultItem] = []
        for mode in cachedModes {
            let best = candidates(for: mode).compactMap { Fuzzy.score(query: lowered, candidate: $0) }.max()
            guard let match = best, match >= 0.65 else { continue }
            let turnsOff = mode.lowercased() == "off"
            items.append(ResultItem(
                title: turnsOff ? "Turn Focus Off" : "Focus: \(mode)",
                subtitle: turnsOff ? "Turn off the current Focus mode" : "Turn on the \(mode) Focus",
                icon: .symbol(symbol(for: mode)),
                score: 850 + match * 60,
                action: { run(shortcut: "Focus: \(mode)") }
            ))
        }
        return items
    }

    // "Focus: Do Not Disturb" -> "Do Not Disturb"; nil for non-Focus shortcuts.
    static func modeName(fromShortcut name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard trimmed.lowercased().hasPrefix(shortcutPrefix) else { return nil }
        let mode = trimmed.dropFirst(shortcutPrefix.count).trimmingCharacters(in: .whitespaces)
        return mode.isEmpty ? nil : mode
    }

    static func candidates(for mode: String) -> [String] {
        var names = [mode, "focus", "focus \(mode)"]
        if mode.lowercased() == "do not disturb" {
            names.append("dnd")
        }
        return names
    }

    static func symbol(for mode: String) -> String {
        let lowered = mode.lowercased()
        let map: [(keyword: String, symbol: String)] = [
            ("off", "slash.circle.fill"),
            ("do not disturb", "moon.fill"),
            ("work", "briefcase.fill"),
            ("personal", "person.fill"),
            ("sleep", "bed.double.fill"),
            ("driving", "car.fill"),
            ("fitness", "figure.run"),
            ("gaming", "gamecontroller.fill"),
            ("reading", "book.fill"),
            ("mindfulness", "leaf.fill"),
            ("study", "graduationcap.fill"),
        ]
        for entry in map where lowered.contains(entry.keyword) {
            return entry.symbol
        }
        return "moon.fill"
    }

    // MARK: - First-run setup

    private static func setupResults(for lowered: String) -> [ResultItem] {
        let triggers = ["focus", "dnd", "do not disturb"]
        let best = triggers.compactMap { Fuzzy.score(query: lowered, candidate: $0) }.max()
        guard let match = best, match >= 0.65 else { return [] }
        return [ResultItem(
            title: "Set Up Focus Switching",
            subtitle: "Spidey switches Focus through Shortcuts named \"Focus: ...\"",
            icon: .symbol("moon.fill"),
            score: 850 + match * 60,
            action: { showSetupInstructions() }
        )]
    }

    private static func showSetupInstructions() {
        let alert = NSAlert()
        alert.messageText = "Set up Focus switching"
        alert.informativeText = """
        macOS only lets apps change Focus through Apple Shortcuts, so Spidey runs shortcuts by name.

        In the Shortcuts app, create a shortcut named "Focus: Do Not Disturb" containing the single action "Set Focus", set to turn Do Not Disturb on until turned off.

        Add one shortcut per mode you use, such as "Focus: Work" or "Focus: Sleep", plus one named "Focus: Off" whose action turns the Focus off. They appear in Spidey automatically.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Shortcuts")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn, let url = URL(string: "shortcuts://create-shortcut") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Shortcuts CLI

    private static func run(shortcut name: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", name]
            let stderrPipe = Pipe()
            process.standardError = stderrPipe
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let message = String(data: data, encoding: .utf8) ?? ""
                    NSLog("Spidey: shortcuts run \"\(name)\" failed: \(message)")
                }
            } catch {
                NSLog("Spidey: could not launch shortcuts CLI: \(error)")
            }
        }
    }

    private static func refreshIfStale() {
        guard !refreshInFlight, Date().timeIntervalSince(lastRefresh) > 30 else { return }
        refreshInFlight = true
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["list"]
            let stdoutPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = Pipe()
            var modes: [String] = []
            do {
                try process.run()
                let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                if let output = String(data: data, encoding: .utf8) {
                    modes = output.split(separator: "\n").compactMap { modeName(fromShortcut: String($0)) }
                }
            } catch {
                NSLog("Spidey: could not list shortcuts: \(error)")
            }
            DispatchQueue.main.async {
                let changed = modes != cachedModes
                cachedModes = modes
                lastRefresh = Date()
                refreshInFlight = false
                if changed {
                    NotificationCenter.default.post(name: .spideyFocusShortcutsChanged, object: nil)
                }
            }
        }
    }
}

extension Notification.Name {
    // Fired when the background `shortcuts list` refresh finds a different set
    // of Focus shortcuts, so open panels can re-run the query.
    static let spideyFocusShortcutsChanged = Notification.Name("spideyFocusShortcutsChanged")
}
