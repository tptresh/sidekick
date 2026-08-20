import AppKit

// "large <text>" or "lt <text>": shows the text huge in a black overlay,
// handy for reading a code across the room. Any key or click dismisses it.
enum LargeTypeProvider {
    static func parse(_ query: String) -> String? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let lowered = trimmed.lowercased()
        for keyword in ["large ", "lt "] where lowered.hasPrefix(keyword) {
            let text = String(trimmed.dropFirst(keyword.count))
                .trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : text
        }
        return nil
    }

    static func results(for query: String) -> [ResultItem] {
        guard let text = parse(query) else { return [] }
        return [ResultItem(
            title: "Show \"\(text)\" in large type",
            subtitle: "Fills the screen with the text. Any key or click dismisses it.",
            icon: .symbol("textformat.size.larger"),
            score: 950,
            action: {
                // Let the panel finish hiding first so the overlay keeps key focus.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    LargeTypeWindow.show(text)
                }
            }
        )]
    }
}
