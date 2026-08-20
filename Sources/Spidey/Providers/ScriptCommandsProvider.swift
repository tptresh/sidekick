import AppKit
import UserNotifications

// Minimal plugin system: executable files in ~/Library/Application Support/
// Spidey/scripts run as "<keyword> [args...]". Scripts can be slow, so they
// only run on Return; the result arrives as a notification and lands on the
// clipboard (or opens) per the output contract in ScriptCommandStore.
enum ScriptCommandsProvider {
    private static let displayPath = "~/Library/Application Support/Spidey/scripts"

    static func results(for query: String) -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        if trimmed.lowercased() == "scripts" {
            return listResults()
        }

        let parts = trimmed.split(separator: " ")
        guard let first = parts.first,
              let command = ScriptCommandStore.shared.command(keyword: String(first)) else { return [] }
        let args = parts.dropFirst().map(String.init)
        let name = command.url.lastPathComponent
        let subtitle: String
        if let description = command.description {
            subtitle = args.isEmpty ? description : "\(description) — with: \(args.joined(separator: " "))"
        } else if args.isEmpty {
            subtitle = "Runs \(name), then notifies with the result"
        } else {
            subtitle = "Runs \(name) with: \(args.joined(separator: " "))"
        }
        return [ResultItem(
            title: "Run \(command.keyword)",
            subtitle: subtitle,
            icon: .symbol("terminal.fill"),
            score: 950,
            secondaryAction: { NSWorkspace.shared.activateFileViewerSelecting([command.url]) },
            action: { run(command, args: args) }
        )]
    }

    private static func listResults() -> [ResultItem] {
        guard FileManager.default.fileExists(atPath: ScriptCommandStore.directory.path) else {
            return [ResultItem(
                title: "Set up script commands",
                subtitle: "Creates \(displayPath) with an example hello.sh and shows it in Finder",
                icon: .symbol("terminal.fill"),
                score: 950,
                action: { ScriptCommandStore.createDirectoryWithExample() }
            )]
        }
        let commands = ScriptCommandStore.shared.commands
        guard !commands.isEmpty else {
            return [ResultItem(
                title: "No script commands yet",
                subtitle: "Drop executable scripts into \(displayPath); the filename becomes the keyword",
                icon: .symbol("terminal.fill"),
                score: 950,
                action: { NSWorkspace.shared.activateFileViewerSelecting([ScriptCommandStore.directory]) }
            )]
        }
        return commands.enumerated().map { index, command in
            ResultItem(
                title: "Run \(command.keyword)",
                subtitle: command.description ?? command.url.lastPathComponent,
                icon: .symbol("terminal"),
                score: 950 - Double(index),
                secondaryAction: { NSWorkspace.shared.activateFileViewerSelecting([command.url]) },
                action: { run(command, args: []) }
            )
        }
    }

    // MARK: - Running

    static func run(_ command: ScriptCommand, args: [String]) {
        requestNotificationAuthorization()
        ScriptCommandStore.run(command, args: args) { result in
            handle(result, command: command)
        }
    }

    private static func handle(_ result: ScriptCommandStore.RunResult, command: ScriptCommand) {
        if result.timedOut {
            notify(title: "\(command.keyword) timed out", body: "Stopped after \(Int(ScriptCommandStore.timeout)) seconds")
            return
        }
        guard result.exitCode == 0 else {
            let firstError = result.stderr
                .split(separator: "\n", omittingEmptySubsequences: true)
                .first.map(String.init) ?? ""
            notify(title: "\(command.keyword) failed (exit \(result.exitCode))", body: firstError)
            return
        }
        switch ScriptCommandStore.parseOutput(result.stdout) {
        case .items(let items):
            let first = items[0]
            let more = items.count > 1 ? " (+\(items.count - 1) more)" : ""
            switch first.action {
            case .copy:
                copyToClipboard(first.arg)
                notify(title: command.keyword, body: "Copied: \(first.title)\(more)")
            case .open:
                open(first.arg)
                notify(title: command.keyword, body: "Opened: \(first.title)\(more)")
            }
        case .plain(let output):
            let text = output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                notify(title: command.keyword, body: "Finished with no output")
                return
            }
            copyToClipboard(text)
            let firstLine = text.split(separator: "\n").first.map(String.init) ?? text
            notify(title: command.keyword, body: "Copied: \(firstLine)")
        }
    }

    private static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static func open(_ arg: String) {
        if let url = URL(string: arg), let scheme = url.scheme?.lowercased() {
            if scheme == "http" || scheme == "https" {
                BrowserLauncher.open(url)
            } else {
                NSWorkspace.shared.open(url)
            }
            return
        }
        let path = (arg as NSString).expandingTildeInPath
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    // MARK: - Notifications

    private static var requestedAuthorization = false

    private static func requestNotificationAuthorization() {
        guard !requestedAuthorization, Bundle.main.bundleIdentifier != nil else { return }
        requestedAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private static func notify(title: String, body: String) {
        NSSound(named: "Pop")?.play()
        // Notifications need a real app bundle; skip them when running bare
        // from .build during development.
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        if !body.isEmpty { content.body = body }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
