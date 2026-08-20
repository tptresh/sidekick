import AppKit
import Combine

final class SpideyViewModel: ObservableObject {
    @Published var query = "" {
        didSet { refresh() }
    }
    @Published private(set) var results: [ResultItem] = []
    @Published var selectedIndex = 0
    @Published var droppedFiles: [URL] = []

    // Called when the panel should close (after an action, or Esc on an empty query).
    var onHide: (() -> Void)?

    private var syncResults: [ResultItem] = []
    private var fileResults: [ResultItem] = []
    private var fileSearchDebounce: DispatchWorkItem?
    // Destructive system command waiting for a confirming second Return.
    private var armedCommand: String?

    func reset() {
        query = ""
        droppedFiles = []
        armedCommand = nil
        selectedIndex = 0
    }

    func refresh() {
        if !droppedFiles.isEmpty {
            syncResults = droppedFileResults()
            fileResults = []
            publish()
            return
        }

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            syncResults = []
            fileResults = []
            armedCommand = nil
            publish()
            return
        }

        let lowered = trimmed.lowercased()
        if lowered == "clip" || lowered == "clipboard" || lowered.hasPrefix("clip ") {
            let filter = lowered.hasPrefix("clip ")
                ? String(trimmed.dropFirst("clip ".count))
                : ""
            syncResults = clipboardResults(filter: filter)
            fileResults = []
            publish()
            scheduleFileSearch(for: nil)
            return
        }

        var commandItems: [ResultItem] = []
        commandItems += CalculatorProvider.results(for: trimmed)
        commandItems += ClaudeProvider.results(for: trimmed)
        commandItems += DictionaryProvider.results(for: trimmed)
        commandItems += WebSearchProvider.results(for: trimmed)
        commandItems += MediaProvider.results(for: trimmed)
        commandItems += SystemProvider.results(for: trimmed, armedCommand: armedCommand) { [weak self] title in
            self?.armedCommand = title
            self?.refresh()
        }
        // A recognized command makes the generic "watch this" and "guess the URL" rows noise.
        let isCommand = !commandItems.isEmpty

        var items = commandItems
        items += AppProvider.shared.results(for: trimmed)
        items += SiteDirectoryProvider.results(for: trimmed, includeGuess: !isCommand)
        if !isCommand {
            items += StreamingProvider.results(for: trimmed)
        }
        if let fallback = WebSearchProvider.googleFallback(for: trimmed) {
            items.append(fallback)
        }
        syncResults = items
        publish()
        scheduleFileSearch(for: trimmed)
    }

    private func scheduleFileSearch(for query: String?) {
        fileSearchDebounce?.cancel()
        guard let query, query.count >= 3, !Calculator.looksLikeExpression(query) else {
            fileResults = []
            publish()
            return
        }
        let work = DispatchWorkItem { [weak self] in
            FileProvider.search(query) { items in
                guard let self, self.query.trimmingCharacters(in: .whitespaces) == query else { return }
                self.fileResults = items
                self.publish()
            }
        }
        fileSearchDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func publish() {
        results = (syncResults + fileResults).sorted { $0.score > $1.score }
        if selectedIndex >= results.count {
            selectedIndex = 0
        }
    }

    // MARK: - Clipboard mode

    private func clipboardResults(filter: String) -> [ResultItem] {
        let store = ClipboardStore.shared
        var entries = store.entries
        if !filter.isEmpty {
            entries = entries.filter {
                $0.value.localizedCaseInsensitiveContains(filter)
                    || $0.displayTitle.localizedCaseInsensitiveContains(filter)
            }
        }
        if entries.isEmpty {
            return [ResultItem(
                title: "Clipboard history is empty",
                subtitle: "Copy something and it will show up here",
                icon: .symbol("doc.on.clipboard"),
                score: 500,
                action: {}
            )]
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return entries.enumerated().map { index, entry in
            let age = formatter.localizedString(for: entry.date, relativeTo: Date())
            let icon: ResultIcon
            switch entry.kind {
            case .text:
                icon = .symbol("doc.on.clipboard")
            case .file:
                let image = NSWorkspace.shared.icon(forFile: entry.value)
                image.size = NSSize(width: 32, height: 32)
                icon = .appIcon(image)
            case .image:
                if let url = ClipboardStore.shared.imageURL(for: entry), let image = NSImage(contentsOf: url) {
                    image.size = NSSize(width: 32, height: 32)
                    icon = .appIcon(image)
                } else {
                    icon = .symbol("photo")
                }
            }
            return ResultItem(
                title: entry.displayTitle,
                subtitle: "Copied \(age). Return copies it back to the clipboard.",
                icon: icon,
                score: 500 - Double(index),
                dragFileURL: entry.kind == .file ? URL(fileURLWithPath: entry.value) : nil,
                action: { ClipboardStore.shared.copyToPasteboard(entry) }
            )
        }
    }

    // MARK: - Dropped files

    func handleDrop(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        droppedFiles = urls
        for url in urls {
            ClipboardStore.shared.recordDroppedFile(url)
        }
        selectedIndex = 0
        refresh()
    }

    private func droppedFileResults() -> [ResultItem] {
        let urls = droppedFiles
        let names = urls.map(\.lastPathComponent).joined(separator: ", ")
        let label = urls.count == 1 ? names : "\(urls.count) files"
        let firstIcon = NSWorkspace.shared.icon(forFile: urls[0].path)
        firstIcon.size = NSSize(width: 32, height: 32)
        let finish: () -> Void = { [weak self] in
            self?.droppedFiles = []
        }
        return [
            ResultItem(
                title: "Open \(label)",
                subtitle: names,
                icon: .appIcon(firstIcon),
                score: 500,
                action: {
                    urls.forEach { NSWorkspace.shared.open($0) }
                    finish()
                }
            ),
            ResultItem(
                title: "Reveal in Finder",
                subtitle: names,
                icon: .symbol("magnifyingglass.circle.fill"),
                score: 499,
                action: {
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                    finish()
                }
            ),
            ResultItem(
                title: "Copy to clipboard",
                subtitle: "Puts the file\(urls.count == 1 ? "" : "s") on the clipboard for pasting",
                icon: .symbol("doc.on.doc.fill"),
                score: 498,
                action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects(urls as [NSURL])
                    finish()
                }
            ),
            ResultItem(
                title: "Copy path\(urls.count == 1 ? "" : "s")",
                subtitle: urls.map(\.path).joined(separator: "\n"),
                icon: .symbol("text.quote"),
                score: 497,
                action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
                    finish()
                }
            ),
        ]
    }

    // MARK: - Keyboard

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + results.count) % results.count
    }

    func runSelected(commandModifier: Bool) {
        guard results.indices.contains(selectedIndex) else { return }
        let item = results[selectedIndex]
        let wasArmed = armedCommand
        if commandModifier, let secondary = item.secondaryAction {
            secondary()
        } else {
            item.action()
        }
        // Arming a destructive command keeps the panel open for the confirm press.
        let armedNow = armedCommand
        if wasArmed == armedNow || armedNow == nil {
            if droppedFiles.isEmpty {
                onHide?()
            }
        }
    }

    func escapePressed() {
        if !droppedFiles.isEmpty {
            droppedFiles = []
            refresh()
        } else if !query.isEmpty {
            query = ""
        } else {
            onHide?()
        }
    }
}
