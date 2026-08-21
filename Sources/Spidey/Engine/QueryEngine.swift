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
                fileResults = []
                publish()
                scheduleFileSearch(for: term, mode: .dedicated)
            }
            return
        }

        if lowered == "in" || lowered.hasPrefix("in ") {
            let phrase = lowered.hasPrefix("in ")
                ? String(trimmed.dropFirst("in ".count)).trimmingCharacters(in: .whitespaces)
                : ""
            if phrase.count < 3 {
                syncResults = [ResultItem(
                    title: "Search inside files",
                    subtitle: "Keep typing to search file contents, e.g. in quarterly forecast",
                    icon: .symbol("doc.text.magnifyingglass"),
                    score: 500,
                    action: {}
                )]
                publish()
                scheduleFileSearch(for: nil)
            } else {
                syncResults = []
                fileResults = []
                publish()
                scheduleFileSearch(for: phrase, mode: .content)
            }
            return
        }

        // Everyday phrasing rewritten into the terse syntax the machine
        // commands expect, so "set a timer for 5 minutes" reaches the timer.
        // Identical to the query whenever nothing needed rewriting, and only
        // the system providers below see it: apps, bookmarks, streaming and
        // web search always get exactly what was typed.
        let systemQuery = Phrasing.normalize(trimmed)

        var commandItems: [ResultItem] = []
        commandItems += ThemeProvider.results(for: trimmed)
        commandItems += CalculatorProvider.results(for: trimmed)
        commandItems += ConvertProvider.results(for: trimmed)
        commandItems += TimeProvider.results(for: systemQuery)
        commandItems += EmojiProvider.results(for: trimmed)
        commandItems += ColorProvider.results(for: trimmed)
        commandItems += PasswordProvider.results(for: trimmed)
        commandItems += TimerProvider.results(for: systemQuery)
        commandItems += SnippetProvider.results(for: trimmed)
        commandItems += ProcessProvider.results(for: systemQuery)
        commandItems += MusicProvider.results(for: systemQuery)
        commandItems += ScriptCommandsProvider.results(for: trimmed)
        commandItems += WindowProvider.results(for: systemQuery)
        commandItems += MenuItemsProvider.results(for: trimmed)
        commandItems += TabsProvider.results(for: trimmed)
        commandItems += ToggleProvider.results(for: systemQuery)
        commandItems += DevToolsProvider.results(for: trimmed)
        commandItems += SystemInfoProvider.results(for: systemQuery)
        commandItems += VolumeProvider.results(for: systemQuery)
        commandItems += QRProvider.results(for: trimmed)
        commandItems += LargeTypeProvider.results(for: trimmed)
        commandItems += FindMyProvider.results(for: trimmed)
        commandItems += CalendarProvider.results(for: trimmed)
        commandItems += ClaudeProvider.results(for: trimmed)
        commandItems += DictionaryProvider.results(for: trimmed)
        commandItems += CustomSearchProvider.results(for: trimmed)
        commandItems += WebSearchProvider.results(for: trimmed)
        commandItems += MediaProvider.results(for: trimmed)
        commandItems += FocusProvider.results(for: systemQuery)
        commandItems += PasteboardToolsProvider.results(for: systemQuery)
        let systemItems = SystemProvider.results(for: systemQuery, armedCommand: armedCommand) { [weak self] title in
            guard let self else { return }
            self.armedCommand = title
            self.refresh()
            // Arming disables boosts, which can re-sort the list; keep the
            // confirmation row under the highlight for the second Return.
            if let index = self.results.firstIndex(where: { $0.title.hasPrefix("\(title):") }) {
                self.selectedIndex = index
            }
        }
        // Editing to an unrelated query drops the armed row; disarm so
        // learned boosts come back instead of staying silently disabled.
        if let armed = armedCommand,
           !systemItems.contains(where: { $0.title.hasPrefix(armed) }) {
            armedCommand = nil
        }
        commandItems += systemItems
        // A recognized command makes the generic "watch this" and "guess the URL" rows noise.
        let isCommand = !commandItems.isEmpty

        var items = commandItems
        items += AppProvider.shared.results(for: trimmed)
        items += ContactsProvider.results(for: trimmed)
        items += WindowSwitcherProvider.results(for: trimmed)
        items += SiteDirectoryProvider.results(for: trimmed)
        items += BookmarksProvider.results(for: trimmed)
        var searchScore = WebSearchProvider.fallbackScore
        if !isCommand {
            items += StreamingProvider.results(for: trimmed)
            // Nothing verifies that a guessed homepage exists, so the web
            // search - which always lands somewhere - goes right above it.
            if let guess = SiteDirectoryProvider.guessResult(for: trimmed) {
                items.append(guess)
                searchScore = max(searchScore, guess.score + 5)
            }
        }
        if let fallback = WebSearchProvider.googleFallback(for: trimmed, score: searchScore) {
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
        let minLength = mode == .ambient ? 3 : 2
        guard let query, query.count >= minLength, !Calculator.looksLikeExpression(query) else {
            fileResults = []
            publish()
            return
        }
        let work = DispatchWorkItem { [weak self] in
            FileProvider.search(query, mode: mode) { items in
                guard let self, self.fileSearchGeneration == generation else { return }
                if mode != .ambient, items.isEmpty {
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
        var combined = syncResults + fileResults
        // Learned ranking: lift results the user previously picked for this
        // (or a prefix-compatible) query. Skipped while a destructive command
        // is armed so a boosted row can never displace the confirmation row.
        if armedCommand == nil, droppedFiles.isEmpty {
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                let boosts = UsageStore.shared.boosts(for: trimmed)
                if !boosts.isEmpty {
                    for index in combined.indices {
                        guard let key = combined[index].rankingKey,
                              let boost = boosts[key] else { continue }
                        combined[index].score += boost
                    }
                }
            }
        }
        results = combined.sorted { $0.score > $1.score }
        if selectedIndex >= results.count {
            selectedIndex = 0
        }
    }

    // MARK: - Clipboard mode

    private func clipboardResults(filter: String) -> [ResultItem] {
        let store = ClipboardStore.shared
        store.pruneMissingScreenshots()
        var entries = store.entries // already sorted pinned-first, newest-first within each group
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
                icon = .symbol(entry.pinned ? "pin.fill" : "doc.on.clipboard")
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
                    icon = .symbol(entry.pinned ? "pin.fill" : "photo")
                }
            }
            let copied = entry.fromScreenshot ? "Screenshot from \(age)" : "Copied \(age)"
            let subtitle = entry.pinned
                ? "Pinned · \(copied). Return copies it, ⌘⏎ unpins."
                : "\(copied). Return copies it, ⌘⏎ pins."
            return ResultItem(
                title: entry.displayTitle,
                subtitle: subtitle,
                icon: icon,
                score: 500 - Double(index),
                dragFileURL: entry.kind == .file ? URL(fileURLWithPath: entry.value) : nil,
                secondaryAction: { [weak self] in
                    ClipboardStore.shared.togglePin(entry)
                    self?.refresh()
                },
                secondaryKeepsPanel: true,
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
        var ranSecondary = false
        if commandModifier, let secondary = item.secondaryAction {
            secondary()
            ranSecondary = true
        } else {
            item.action()
        }
        // Learn from the pick: rows without a rankingKey opted out.
        if let key = item.rankingKey {
            UsageStore.shared.recordSelection(
                query: query.trimmingCharacters(in: .whitespaces), rankingKey: key
            )
        }
        // A pin toggle resorts the list in place; the panel stays up.
        if ranSecondary, item.secondaryKeepsPanel { return }
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
