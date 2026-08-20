import AppKit
import CoreServices

enum DictionaryProvider {
    static func results(for query: String) -> [ResultItem] {
        let lowered = query.lowercased()
        if lowered.hasPrefix("define ") {
            let word = String(query.dropFirst("define ".count)).trimmingCharacters(in: .whitespaces)
            guard !word.isEmpty else { return [] }
            let definition = lookUp(word) ?? "No definition found. Return opens Dictionary."
            return [ResultItem(
                title: "Define \"\(word)\"",
                subtitle: String(definition.prefix(140)),
                icon: .symbol("character.book.closed.fill"),
                score: 980,
                action: { openDictionary(word) }
            )]
        }
        if lowered.hasPrefix("spell ") {
            let word = String(query.dropFirst("spell ".count)).trimmingCharacters(in: .whitespaces)
            guard !word.isEmpty else { return [] }
            let checker = NSSpellChecker.shared
            let guesses = checker.guesses(
                forWordRange: NSRange(location: 0, length: word.utf16.count),
                in: word, language: nil, inSpellDocumentWithTag: 0
            ) ?? []
            let best = guesses.first ?? word
            return [ResultItem(
                title: best,
                subtitle: guesses.isEmpty
                    ? "Looks correctly spelled. Return copies it."
                    : "Suggestions: \(guesses.prefix(4).joined(separator: ", ")). Return copies the first.",
                icon: .symbol("textformat.abc"),
                score: 980,
                action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(best, forType: .string)
                }
            )]
        }
        return []
    }

    static func lookUp(_ word: String) -> String? {
        let range = CFRange(location: 0, length: word.count)
        guard let definition = DCSCopyTextDefinition(nil, word as CFString, range)?.takeRetainedValue()
        else { return nil }
        return String(definition as NSString)
    }

    static func openDictionary(_ word: String) {
        let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word
        if let url = URL(string: "dict://\(encoded)") {
            NSWorkspace.shared.open(url)
        }
    }
}
