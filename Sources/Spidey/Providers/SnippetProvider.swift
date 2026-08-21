import AppKit

// "snip add addr 123 Main Street" saves a snippet; "snip" lists them and Return
// copies one; typing a snippet's keyword on its own surfaces it directly.
// Deleting works two ways on purpose: "snip rm <keyword>" as a command, and
// Cmd+Return on any listed snippet row.
enum SnippetProvider {
    enum Parsed: Equatable {
        case list(filter: String)
        case add(keyword: String, content: String)
        case addHelp
        case remove(keyword: String)
        case removeHelp
    }

    static func parse(_ query: String) -> Parsed? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let lowered = trimmed.lowercased()
        let triggers = ["snippets", "snippet", "snip"]
        guard let trigger = triggers.first(where: { lowered == $0 || lowered.hasPrefix($0 + " ") }) else {
            return nil
        }
        let rest = String(trimmed.dropFirst(trigger.count)).trimmingCharacters(in: .whitespaces)
        if rest.isEmpty { return .list(filter: "") }
        // maxSplits keeps the content's own spacing and casing intact.
        let parts = rest.split(separator: " ", maxSplits: 1)
        let tail = parts.count > 1 ? String(parts[1]) : ""
        switch parts[0].lowercased() {
        case "add":
            let pieces = tail.split(separator: " ", maxSplits: 1)
            guard pieces.count == 2 else { return .addHelp }
            return .add(keyword: String(pieces[0]).lowercased(), content: String(pieces[1]))
        case "rm", "remove", "delete":
            let keyword = tail.trimmingCharacters(in: .whitespaces)
            guard !keyword.isEmpty else { return .removeHelp }
            return .remove(keyword: keyword.lowercased())
        default:
            return .list(filter: rest)
        }
    }

    static func results(for query: String) -> [ResultItem] {
        results(for: query, store: SnippetStore.shared)
    }

    static func results(for query: String, store: SnippetStore) -> [ResultItem] {
        if let parsed = parse(query) {
            return commandResults(parsed, store: store)
        }
        // Bare keyword match: "addr" alone surfaces the addr snippet.
        let key = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !key.isEmpty, !key.contains(" "), let snippet = store.snippet(forKeyword: key) else {
            return []
        }
        return [copyRow(snippet, score: 900, store: store)]
    }

    private static func commandResults(_ parsed: Parsed, store: SnippetStore) -> [ResultItem] {
        switch parsed {
        case .list(let filter):
            let all = store.snippets
            if all.isEmpty {
                return [ResultItem(
                    title: "No snippets yet",
                    subtitle: "Add one like: snip add addr 123 Main Street, Springfield",
                    icon: .symbol("text.append"),
                    score: 950,
                    action: {}
                )]
            }
            let matches = filter.isEmpty ? all : all.filter {
                $0.keyword.localizedCaseInsensitiveContains(filter)
                    || $0.name.localizedCaseInsensitiveContains(filter)
                    || $0.content.localizedCaseInsensitiveContains(filter)
            }
            if matches.isEmpty {
                return [ResultItem(
                    title: "No snippets match \"\(filter)\"",
                    subtitle: "snip lists everything; snip add \(filter) ... saves a new one",
                    icon: .symbol("text.append"),
                    score: 950,
                    action: {}
                )]
            }
            return matches.enumerated().map { index, snippet in
                copyRow(snippet, score: 950 - Double(index), store: store)
            }

        case .add(let keyword, let content):
            let replacing = store.snippet(forKeyword: keyword) != nil
            return [ResultItem(
                title: "\(replacing ? "Replace" : "Save") snippet: \(keyword)",
                subtitle: "Will save: \(preview(of: content)). Then type \(keyword) to copy it.",
                icon: .symbol("plus.square.on.square"),
                score: 985,
                action: { store.add(keyword: keyword, content: content) }
            )]

        case .addHelp:
            return [ResultItem(
                title: "Add a snippet",
                subtitle: "Like: snip add addr 123 Main Street, Springfield",
                icon: .symbol("plus.square.on.square"),
                score: 950,
                action: {}
            )]

        case .remove(let keyword):
            guard let snippet = store.snippet(forKeyword: keyword) else {
                return [ResultItem(
                    title: "No snippet named \(keyword)",
                    subtitle: "snip lists the saved snippets",
                    icon: .symbol("trash"),
                    score: 950,
                    action: {}
                )]
            }
            return [ResultItem(
                title: "Delete snippet: \(snippet.keyword)",
                subtitle: snippet.preview,
                icon: .symbol("trash"),
                score: 985,
                action: { store.remove(keyword: snippet.keyword) }
            )]

        case .removeHelp:
            return [ResultItem(
                title: "Delete a snippet",
                subtitle: "Like: snip rm addr. Cmd+Return on a listed snippet also deletes it.",
                icon: .symbol("trash"),
                score: 950,
                action: {}
            )]
        }
    }

    private static func copyRow(_ snippet: Snippet, score: Double, store: SnippetStore) -> ResultItem {
        ResultItem(
            title: snippet.keyword,
            subtitle: "\(snippet.preview). Return copies it; Cmd+Return deletes it.",
            icon: .symbol("text.append"),
            score: score,
            secondaryAction: { store.remove(keyword: snippet.keyword) },
            action: { copyToClipboard(snippet.content) }
        )
    }

    private static func preview(of content: String) -> String {
        let flattened = content.replacingOccurrences(of: "\n", with: " ")
        return flattened.count > 60 ? String(flattened.prefix(60)) + "…" : flattened
    }

    private static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
