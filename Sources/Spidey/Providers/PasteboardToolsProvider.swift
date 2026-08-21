import AppKit

// Utilities for the current system pasteboard (not the history):
// "plain" / "paste plain" rewrites styled clipboard contents as plain text,
// and "clear clipboard" empties the pasteboard.
enum PasteboardToolsProvider {
    enum Command: Equatable {
        case plainText
        case clearClipboard
    }

    static func parse(_ query: String) -> Command? {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        switch lowered {
        case "plain", "paste plain", "plain text", "plain paste":
            return .plainText
        case "clear clipboard", "clipboard clear":
            return .clearClipboard
        default:
            // Only full words trigger these rows at command score - a short
            // prefix like "pas" en route to anything else must not. "clear
            // clip" onward counts: the first word is complete and the second
            // is unambiguous.
            if lowered.count >= "clear clip".count, "clear clipboard".hasPrefix(lowered) {
                return .clearClipboard
            }
            return nil
        }
    }

    static func results(for query: String) -> [ResultItem] {
        switch parse(query) {
        case .plainText:
            return [plainTextRow()]
        case .clearClipboard:
            return [clearClipboardRow()]
        case nil:
            return []
        }
    }

    // Pasteboard flavors that mean the copied text carries styling.
    private static let styledTypes: [NSPasteboard.PasteboardType] = [
        .rtf, .rtfd, .html,
        NSPasteboard.PasteboardType("public.html"),
        NSPasteboard.PasteboardType("public.rtf"),
    ]

    private static func plainTextRow() -> ResultItem {
        let pasteboard = NSPasteboard.general
        let types = pasteboard.types ?? []
        let text = pasteboard.string(forType: .string)

        guard let text, !text.isEmpty else {
            return ResultItem(
                title: "No text on the clipboard",
                subtitle: "Copy some styled text first, then run \"plain\" to strip its formatting",
                icon: .symbol("doc.on.clipboard"),
                score: 950,
                action: {}
            )
        }
        guard types.contains(where: { styledTypes.contains($0) }) else {
            return ResultItem(
                title: "Clipboard is already plain text",
                subtitle: "No formatting to strip - paste away",
                icon: .symbol("checkmark.circle"),
                score: 950,
                action: {}
            )
        }
        return ResultItem(
            title: "Convert Clipboard to Plain Text",
            subtitle: "Strips RTF/HTML styling so the copied text pastes unformatted",
            icon: .symbol("textformat"),
            score: 950,
            action: {
                ClipboardStore.shared.ignoreNextPasteboardChange()
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
            }
        )
    }

    private static func clearClipboardRow() -> ResultItem {
        ResultItem(
            title: "Clear Clipboard",
            subtitle: "Empties the current clipboard contents (history is kept)",
            icon: .symbol("xmark.circle"),
            score: 950,
            action: {
                ClipboardStore.shared.ignoreNextPasteboardChange()
                NSPasteboard.general.clearContents()
            }
        )
    }
}
