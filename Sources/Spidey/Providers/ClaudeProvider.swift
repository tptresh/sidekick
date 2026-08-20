import AppKit

// "claude <prompt>" opens Terminal running a Claude Code session with that prompt.
enum ClaudeProvider {
    static func results(for query: String) -> [ResultItem] {
        let lowered = query.lowercased()
        guard lowered.hasPrefix("claude ") else { return [] }
        let prompt = String(query.dropFirst("claude ".count)).trimmingCharacters(in: .whitespaces)
        guard !prompt.isEmpty else { return [] }
        let directory = SettingsStore.shared.claudeDirectory
        let shortDir = directory.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        return [ResultItem(
            title: "Start Claude Code session: \"\(prompt)\"",
            subtitle: "Opens Terminal in \(shortDir) and runs claude",
            icon: .symbol("terminal.fill"),
            score: 1000,
            action: { launch(prompt: prompt, directory: directory) }
        )]
    }

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

    static func launch(prompt: String, directory: String) {
        let command = appleScriptEscape(shellCommand(prompt: prompt, directory: directory))
        let script = """
        tell application "Terminal"
            activate
            do script "\(command)"
        end tell
        """
        SystemProvider.runAppleScript(script)
    }
}
