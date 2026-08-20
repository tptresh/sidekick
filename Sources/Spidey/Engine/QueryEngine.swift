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
    // Drops completions from file searches that are no longer current.
    private var fileSearchGeneration = 0
    // Destructive system command waiting for a confirming second Return.
    private var armedCommand: String?

    init() {
        // Re-run providers when a site logo finishes downloading so rows upgrade
        // from the fallback symbol to the real favicon.
        NotificationCenter.default.addObserver(
            forName: .spideyFaviconLoaded, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
        // Same idea for Focus: the list of "Focus: ..." shortcuts loads in the
        // background, so re-run the query when it arrives or changes.
        NotificationCenter.default.addObserver(
            forName: .spideyFocusShortcutsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
        // Same again when the day's exchange rates arrive.
        NotificationCenter.default.addObserver(
            forName: .spideyRatesLoaded, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

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

        if lowered == "ss" || lowered == "screenshot" || lowered == "screenshots" {
            syncResults = screenshotResults()
            fileResults = []
            publish()
            scheduleFileSearch(for: nil)
            return
        }

        if lowered == "find" || lowered.hasPrefix("find ") {
            let term = lowered.hasPrefix("find ")
                ? String(trimmed.dropFirst("find ".count)).trimmingCharacters(in: .whitespaces)
                : ""
            // "find my iphone" should ping the device, not only search files.
            let pingItems = FindMyProvider.results(for: trimmed)
            if term.count < 2 {
                syncResults = pingItems + [ResultItem(
                    title: "Find files",
                    subtitle: "Keep typing to search every indexed file, e.g. find tax return",
                    icon: .symbol("doc.text.magnifyingglass"),
                    score: 500,
                    action: {}
                )]
                publish()
                scheduleFileSearch(for: nil)
            } else {
                syncResults = pingItems
                publish()
                scheduleFileSearch(for: term, mode: .dedicated)
            }
            return
        }

        var commandItems: [ResultItem] = []
        commandItems += CalculatorProvider.results(for: trimmed)
        commandItems += ConvertProvider.results(for: trimmed)
        commandItems += TimeProvider.results(for: trimmed)
        commandItems += EmojiProvider.results(for: trimmed)
        commandItems += ColorProvider.results(for: trimmed)
        commandItems += PasswordProvider.results(for: trimmed)
        commandItems += TimerProvider.results(for: trimmed)
        commandItems += ProcessProvider.results(for: trimmed)
        commandItems += WindowProvider.results(for: trimmed)
        commandItems += ToggleProvider.results(for: trimmed)
        commandItems += FindMyProvider.results(for: trimmed)
        commandItems += ClaudeProvider.results(for: trimmed)
        commandItems += DictionaryProvider.results(for: trimmed)
        commandItems += WebSearchProvider.results(for: trimmed)
        commandItems += MediaProvider.results(for: trimmed)
        commandItems += FocusProvider.results(for: trimmed)
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

    private func scheduleFileSearch(for query: String?, mode: FileProvider.Mode = .ambient) {
        fileSearchDebounce?.cancel()
        fileSearchGeneration += 1
        let generation = fileSearchGeneration
        let minLength = mode == .dedicated ? 2 : 3
        guard let query, query.count >= minLength, !Calculator.looksLikeExpression(query) else {
            fileResults = []
            publish()
            return
        }
        let work = DispatchWorkItem { [weak self] in
            FileProvider.search(query, mode: mode) { items in
                guard let self, self.fileSearchGeneration == generation else { return }
                if mode == .dedicated, items.isEmpty {
                    self.fileResults = [ResultItem(
                        title: "No files found",
                        subtitle: "Nothing in the Spotlight index matches \"\(query)\"",
                        icon: .symbol("questionmark.folder"),
                        score: 100,
                        action: {}
                    )]
                } else {
                    self.fileResults = items
                }
                self.publish()
            }
        }
        fileSearchDebounce = work
        // The dedicated mode is an explicit request, so answer it faster.
        DispatchQueue.main.asyncAfter(deadline: .now() + (mode == .dedicated ? 0.15 : 0.25), execute: work)
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
        store.pruneMissingScreenshots()
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
                // Screenshots get a real thumbnail so the right one is easy to pick.
                if entry.fromScreenshot, let image = NSImage(contentsOfFile: entry.value) {
                    image.size = NSSize(width: 32, height: 32)
                    icon = .appIcon(image)
                } else {
                    let image = NSWorkspace.shared.icon(forFile: entry.value)
                    image.size = NSSize(width: 32, height: 32)
                    icon = .appIcon(image)
                }
            case .image:
                if let url = ClipboardStore.shared.imageURL(for: entry), let image = NSImage(contentsOf: url) {
                    image.size = NSSize(width: 32, height: 32)
                    icon = .appIcon(image)
                } else {
                    icon = .symbol("photo")
                }
            }
            let subtitle = entry.fromScreenshot
                ? "Screenshot from \(age). Drag it into any app, or press Return to copy."
                : "Copied \(age). Return copies it back to the clipboard."
            return ResultItem(
                title: entry.displayTitle,
                subtitle: subtitle,
                icon: icon,
                score: 500 - Double(index),
                dragFileURL: entry.kind == .file ? URL(fileURLWithPath: entry.value) : nil,
                action: { ClipboardStore.shared.copyToPasteboard(entry) }
            )
        }
    }

    // MARK: - Screenshots mode

    private func screenshotResults() -> [ResultItem] {
        let store = ClipboardStore.shared
        store.pruneMissingScreenshots()
        let shots = store.entries.filter(\.fromScreenshot)
        if shots.isEmpty {
            let subtitle = SettingsStore.shared.screenshotsToClipboard
                ? "Take one and it will show up here automatically"
                : "Turn on \"Keep recent screenshots\" in Settings to collect them here"
            return [ResultItem(
                title: "No recent screenshots",
                subtitle: subtitle,
                icon: .symbol("camera.viewfinder"),
                score: 500,
                action: {}
            )]
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return shots.enumerated().map { index, entry in
            let age = formatter.localizedString(for: entry.date, relativeTo: Date())
            let icon: ResultIcon
            if let image = NSImage(contentsOfFile: entry.value) {
                image.size = NSSize(width: 32, height: 32)
                icon = .appIcon(image)
            } else {
                icon = .symbol("photo")
            }
            return ResultItem(
                title: entry.displayTitle,
                subtitle: "Taken \(age). Drag it into any app, or press Return to copy.",
                icon: icon,
                score: 500 - Double(index),
                dragFileURL: URL(fileURLWithPath: entry.value),
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
