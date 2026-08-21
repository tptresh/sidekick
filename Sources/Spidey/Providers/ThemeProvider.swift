import AppKit

// Typing a hero's name offers a theme switch with a full screen entrance:
// "spidey" swings the mask in on a web line, "the bat" lights the signal.
enum ThemeProvider {
    static func results(for query: String) -> [ResultItem] {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        // "the" alone starts too many ordinary searches to hijack.
        guard lowered.count >= 3, lowered != "the" else { return [] }

        var items: [ResultItem] = []
        if matches(lowered, ["spidey", "spiderman", "spider-man", "spider man", "spidey theme"]) {
            items.append(item(for: .spiderman))
        }
        if matches(lowered, ["the bat", "batman", "bat man", "batman theme", "dark knight", "gotham"]) {
            items.append(item(for: .batman))
        }
        if matches(lowered, ["iron man", "ironman", "iron-man", "iron man theme", "stark", "tony stark", "jarvis"]) {
            items.append(item(for: .ironMan))
        }
        return items
    }

    // Progressive prefix match: every keystroke on the way to a trigger keeps
    // the row visible, but typing past it ("batman movie") drops it.
    private static func matches(_ query: String, _ triggers: [String]) -> Bool {
        triggers.contains { $0.hasPrefix(query) }
    }

    private static func item(for theme: HeroTheme) -> ResultItem {
        let isCurrent = SettingsStore.shared.theme == theme
        let icon = StatusIcons.watermark(for: theme, size: 32, color: NSColor(theme.palette.accent))
        let subtitle: String
        if isCurrent {
            subtitle = "Already on. Press Return to replay the entrance"
        } else {
            switch theme {
            case .spiderman:
                subtitle = "Thwip. The mask swings in from the top of the screen"
            case .batman:
                subtitle = "Lights the signal and summons the Dark Knight"
            case .ironMan:
                subtitle = "The armor flies in and assembles, piece by piece"
            }
        }
        return ResultItem(
            title: isCurrent ? "\(theme.displayName) theme is on" : "Switch to the \(theme.displayName) theme",
            subtitle: subtitle,
            icon: .appIcon(icon),
            score: 960,
            action: { ThemeAnimator.shared.play(theme) }
        )
    }
}
