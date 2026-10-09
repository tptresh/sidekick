import AppKit

// Focus mode switching. macOS has no public API for changing Focus (the database
// under ~/Library/DoNotDisturb is TCC-protected), so everything goes through
// Apple Shortcuts and the `shortcuts` CLI.
//
// Do Not Disturb works with zero setup: typing "dnd" or "do not disturb" offers
// built-in on and off commands. The first use generates the needed shortcut
// (a single "Set Focus" action), signs it locally with `shortcuts sign`, and
// opens it so macOS shows its one-click "Add Shortcut" confirmation; the moment
// it is added, the command runs. Every later use just runs the shortcut.
//
// Custom Focus modes still work by convention: any shortcut named
// "Focus: <Mode>" (for example "Focus: Work") shows up as a command.
enum FocusProvider {
    static let shortcutPrefix = "focus:"

    struct BuiltInCommand {
        let shortcutName: String
        let title: String
        let subtitle: String
        // Slightly different bases so "dnd" ranks the on command above off.
        let baseScore: Double
        let symbol: String
        let matchNames: [String]
        let enabled: Bool
    }

    static let builtIns: [BuiltInCommand] = [
        BuiltInCommand(
            shortcutName: "Focus: Do Not Disturb",
            title: "Turn On Do Not Disturb",
            subtitle: "Silence notifications until turned off",
            baseScore: 852,
            symbol: "moon.fill",
            matchNames: ["do not disturb", "dnd", "focus", "do not disturb on", "dnd on"],
            enabled: true
        ),
        BuiltInCommand(
            shortcutName: "Focus: Do Not Disturb Off",
            title: "Turn Off Do Not Disturb",
            subtitle: "Allow notifications again",
            baseScore: 848,
            symbol: "slash.circle.fill",
            matchNames: ["do not disturb off", "dnd off", "focus off", "do not disturb", "dnd", "focus"],
            enabled: false
        ),
    ]

    // Cached mode names parsed from `shortcuts list`, refreshed in the
    // background so the synchronous per-keystroke query path never shells out.
    private static var cachedModes: [String] = []
    private static var lastRefresh = Date.distantPast
    private static var refreshInFlight = false
    private static var installsInFlight: Set<String> = []

    static func results(for query: String) -> [ResultItem] {
        refreshIfStale()

        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !lowered.isEmpty else { return [] }

        var items: [ResultItem] = []
        for command in builtIns {
            let best = command.matchNames.compactMap { Fuzzy.score(query: lowered, candidate: $0) }.max()
            guard let match = best, match >= 0.65 else { continue }
            let ready = isInstalled(command)
            items.append(ResultItem(
                title: command.title,
                subtitle: ready ? command.subtitle : command.subtitle + " (first use adds a one-click Shortcut)",
                icon: .symbol(command.symbol),
                score: command.baseScore + match * 60,
                action: { runOrInstall(command) }
            ))
        }

        // User-created "Focus: <Mode>" shortcuts, minus the built-in ones.
        let builtInNames = Set(builtIns.map { $0.shortcutName.lowercased() })
        for mode in cachedModes {
            guard !builtInNames.contains("\(shortcutPrefix) \(mode.lowercased())") else { continue }
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

    // MARK: - Shortcut generation

    // The .shortcut plist for a single "Set Focus" action targeting the
    // built-in Do Not Disturb mode. Its identifier is stable across machines;
    // custom modes use per-user identifiers hidden behind TCC, which is why
    // only DND can be generated.
    static func workflowData(enabled: Bool) throws -> Data {
        let action: [String: Any] = [
            "WFWorkflowActionIdentifier": "is.workflow.actions.dnd.set",
            "WFWorkflowActionParameters": [
                "Enabled": enabled ? 1 : 0,
                "FocusModes": [
                    "Identifier": "com.apple.donotdisturb.mode.default",
                    "DisplayString": "Do Not Disturb",
                ],
            ] as [String: Any],
        ]
        let workflow: [String: Any] = [
            "WFQuickActionSurfaces": [] as [Any],
            "WFWorkflowActions": [action],
            "WFWorkflowIcon": [
                "WFWorkflowIconGlyphNumber": 59511,
                "WFWorkflowIconStartColor": 2071128575,
            ] as [String: Any],
            "WFWorkflowImportQuestions": [] as [Any],
            "WFWorkflowInputContentItemClasses": [] as [Any],
            "WFWorkflowMinimumClientVersion": 900,
            "WFWorkflowMinimumClientVersionString": "900",
            "WFWorkflowOutputContentItemClasses": [] as [Any],
            "WFWorkflowTypes": [] as [Any],
        ]
        return try PropertyListSerialization.data(fromPropertyList: workflow, format: .xml, options: 0)
    }

    private static func isInstalled(_ command: BuiltInCommand) -> Bool {
        cachedModes.contains { "\(shortcutPrefix) \($0.lowercased())" == command.shortcutName.lowercased() }
    }

    private static func runOrInstall(_ command: BuiltInCommand) {
        if isInstalled(command) {
            run(shortcut: command.shortcutName)
        } else {
            install(command)
        }
    }

    // Writes the shortcut, signs it locally, and opens it so macOS shows the
    // "Add Shortcut" confirmation. As soon as the user adds it, run it, so the
    // very first "dnd" still ends with the Focus actually changing.
    private static func install(_ command: BuiltInCommand) {
        // Actions run on the main thread, so this check-and-insert is safe.
        guard !installsInFlight.contains(command.shortcutName) else { return }
        installsInFlight.insert(command.shortcutName)
        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                DispatchQueue.main.async { _ = installsInFlight.remove(command.shortcutName) }
            }
            do {
                let dir = try shortcutsDirectory()
                let unsignedDir = dir.appendingPathComponent("unsigned", isDirectory: true)
                try FileManager.default.createDirectory(at: unsignedDir, withIntermediateDirectories: true)
                // The signed file's basename becomes the imported shortcut's name.
                let unsigned = unsignedDir.appendingPathComponent("\(command.shortcutName).shortcut")
                let signed = dir.appendingPathComponent("\(command.shortcutName).shortcut")
                try workflowData(enabled: command.enabled).write(to: unsigned)
                try? FileManager.default.removeItem(at: signed)

                let sign = Process()
                sign.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                sign.arguments = ["sign", "--mode", "anyone", "--input", unsigned.path, "--output", signed.path]
                let stderrPipe = Pipe()
                sign.standardError = stderrPipe
                try sign.run()
                sign.waitUntilExit()
                guard sign.terminationStatus == 0 else {
                    let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    NSLog("Spidey: shortcuts sign failed: \(String(data: data, encoding: .utf8) ?? "")")
                    return
                }

                DispatchQueue.main.async {
                    NSWorkspace.shared.open(signed)
                }
                // Poll until the user clicks Add (or give up after a minute).
                for _ in 0..<30 {
                    Thread.sleep(forTimeInterval: 2)
                    let modes = listFocusModes()
                    let added = modes.contains { "\(shortcutPrefix) \($0.lowercased())" == command.shortcutName.lowercased() }
                    if added {
                        DispatchQueue.main.async {
                            cachedModes = modes
                            lastRefresh = Date()
                            NotificationCenter.default.post(name: .spideyFocusShortcutsChanged, object: nil)
                        }
                        run(shortcut: command.shortcutName)
                        return
                    }
                }
                NSLog("Spidey: \(command.shortcutName) was not added to Shortcuts; giving up")
            } catch {
                NSLog("Spidey: could not install \(command.shortcutName): \(error)")
            }
        }
    }

    private static func shortcutsDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let dir = base.appendingPathComponent("Spidey/Shortcuts", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
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
                // Drain stderr before waiting: a child that fills the pipe
                // would otherwise never exit.
                let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    let message = String(data: data, encoding: .utf8) ?? ""
                    NSLog("Spidey: shortcuts run \"\(name)\" failed: \(message)")
                    SystemProvider.tellUser(title: "Could not run \(name)", body: shortcutFailureText(message))
                }
            } catch {
                NSLog("Spidey: could not launch shortcuts CLI: \(error)")
                SystemProvider.tellUser(
                    title: "Could not run \(name)",
                    body: "The Shortcuts command line tool would not start, so nothing changed."
                )
            }
        }
    }

    // What to tell the user when `shortcuts run` fails: its own first error
    // line when it gave one, otherwise a plain hint.
    static func shortcutFailureText(_ stderr: String) -> String {
        let line = stderr.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        let hint = "Check the shortcut in the Shortcuts app; nothing changed."
        guard let line else { return hint }
        return "Shortcuts said: \(line). \(hint)"
    }

    // Synchronous; call from a background queue only.
    private static func listFocusModes() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["list"]
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()
        do {
            try process.run()
            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            return output.split(separator: "\n").compactMap { modeName(fromShortcut: String($0)) }
        } catch {
            NSLog("Spidey: could not list shortcuts: \(error)")
            return []
        }
    }

    private static func refreshIfStale() {
        guard !refreshInFlight, Date().timeIntervalSince(lastRefresh) > 30 else { return }
        refreshInFlight = true
        DispatchQueue.global(qos: .utility).async {
            let modes = listFocusModes()
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
