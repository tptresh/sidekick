import AppKit

// "claude <prompt>" starts a Claude Code session in the Claude desktop app via its
// claude://code/new deep link, with the prompt and working folder as query params.
enum ClaudeProvider {
    static func results(for query: String) -> [ResultItem] {
        let lowered = query.lowercased()
        guard lowered.hasPrefix("claude ") else { return [] }
        let prompt = String(query.dropFirst("claude ".count)).trimmingCharacters(in: .whitespaces)
        guard !prompt.isEmpty else { return [] }
        let directory = SettingsStore.shared.claudeDirectory
        let shortDir = directory.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        let hasClaudeApp = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "claude://")!) != nil
        return [ResultItem(
            title: "Start Claude Code session: \"\(prompt)\"",
            subtitle: hasClaudeApp
                ? "Opens the Claude Code app in \(shortDir)"
                : "Opens Terminal in \(shortDir) and runs claude",
            icon: claudeAppIcon() ?? .symbol("terminal.fill"),
            score: 1000,
            action: { launch(prompt: prompt, directory: directory) }
        )]
    }

    static func deepLinkURL(prompt: String, directory: String) -> URL? {
        var components = URLComponents()
        components.scheme = "claude"
        components.host = "code"
        components.path = "/new"
        components.queryItems = [
            URLQueryItem(name: "q", value: prompt),
            URLQueryItem(name: "folder", value: directory),
        ]
        return components.url
    }

    static func launch(prompt: String, directory: String) {
        // Prefer the Claude desktop app; fall back to Terminal when no app
        // handles the claude:// scheme.
        if let url = deepLinkURL(prompt: prompt, directory: directory),
           NSWorkspace.shared.urlForApplication(toOpen: URL(string: "claude://")!) != nil {
            NSWorkspace.shared.open(url)
            return
        }
        launchInTerminal(prompt: prompt, directory: directory)
    }

    // MARK: - Terminal fallback

    static func shellEscape(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func appleScriptEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    static func shellCommand(prompt: String, directory: String) -> String {
        "cd \(shellEscape(directory)) && claude \(shellEscape(prompt))"
    }

    static func launchInTerminal(prompt: String, directory: String) {
        let command = appleScriptEscape(shellCommand(prompt: prompt, directory: directory))
        let script = """
        tell application "Terminal"
            activate
            do script "\(command)"
        end tell
        """
        SystemProvider.runAppleScript(script)
    }

    private static func claudeAppIcon() -> ResultIcon? {
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "claude://")!)
        else { return nil }
        return .appIcon(NSWorkspace.shared.icon(forFile: appURL.path))
    }
}
