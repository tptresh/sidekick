import AppKit
import Combine

// Feeds new screenshots into the clipboard history so they can be pasted or
// dragged from Sidekick without racing the corner thumbnail. Uses Spotlight's
// screen-capture flag rather than watching a folder, so it keeps working even
// if the user changes the screenshot save location.
final class ScreenshotWatcher {
    static let shared = ScreenshotWatcher()

    private let query = NSMetadataQuery()
    private var running = false
    private var cancellable: AnyCancellable?

    private init() {}

    func start() {
        cancellable = SettingsStore.shared.$screenshotsToClipboard
            .sink { [weak self] enabled in
                enabled ? self?.startQuery() : self?.stopQuery()
            }
    }

    private func startQuery() {
        guard !running else { return }
        running = true
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1")
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        query.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSCreationDateKey, ascending: false)]
        NotificationCenter.default.addObserver(
            self, selector: #selector(initialGatherFinished),
            name: .NSMetadataQueryDidFinishGathering, object: query
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(queryUpdated),
            name: .NSMetadataQueryDidUpdate, object: query
        )
        query.start()
    }

    private func stopQuery() {
        guard running else { return }
        running = false
        query.stop()
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: query)
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: query)
    }

    // Seed the history with the most recent screenshots so they are available
    // immediately, not only ones taken after this launch. Skipping paths that
    // are already recorded keeps a relaunch from reshuffling the history.
    @objc private func initialGatherFinished(_ note: Notification) {
        query.disableUpdates()
        let store = ClipboardStore.shared
        store.pruneMissingScreenshots()
        let known = Set(store.entries.filter(\.fromScreenshot).map(\.value))
        let newest = (0..<min(query.resultCount, ClipboardStore.screenshotKeepCount))
            .compactMap { query.result(at: $0) as? NSMetadataItem }
        // Oldest first, so the newest screenshot ends up on top of the history.
        for item in newest.reversed() {
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  !known.contains(path) else { continue }
            let date = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date ?? Date()
            store.recordScreenshot(path: path, date: date)
        }
        query.enableUpdates()
    }

    @objc private func queryUpdated(_ note: Notification) {
        guard let added = note.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem],
              !added.isEmpty else { return }
        for item in added {
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else { continue }
            let date = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date ?? Date()
            ClipboardStore.shared.recordScreenshot(path: path, date: date)
        }
    }
}
