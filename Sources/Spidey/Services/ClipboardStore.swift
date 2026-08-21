import AppKit
import Combine

struct ClipEntry: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case text
        case file
        case image
    }

    var id: UUID
    var kind: Kind
    var date: Date
    // text: the string. file: the path. image: filename of a PNG in the images folder.
    var value: String
    // Optional so history saved before screenshots existed still decodes.
    var isScreenshot: Bool?
    // Pinned entries sort first and never age out of the history cap.
    var pinned: Bool

    var fromScreenshot: Bool { isScreenshot == true }

    init(id: UUID, kind: Kind, date: Date, value: String, isScreenshot: Bool? = nil, pinned: Bool = false) {
        self.id = id
        self.kind = kind
        self.date = date
        self.value = value
        self.isScreenshot = isScreenshot
        self.pinned = pinned
    }

    // Histories written before screenshots or pinning existed lack those keys.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(Kind.self, forKey: .kind)
        date = try container.decode(Date.self, forKey: .date)
        value = try container.decode(String.self, forKey: .value)
        isScreenshot = try container.decodeIfPresent(Bool.self, forKey: .isScreenshot)
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
    }

    var displayTitle: String {
        switch kind {
        case .text:
            let flattened = value.replacingOccurrences(of: "\n", with: " ")
            return flattened.count > 80 ? String(flattened.prefix(80)) + "…" : flattened
        case .file:
            return (value as NSString).lastPathComponent
        case .image:
            return "Image"
        }
    }
}

final class ClipboardStore: ObservableObject {
    static let shared = ClipboardStore()

    // Always sorted pinned-first; newest-first within each group.
    @Published private(set) var entries: [ClipEntry] = []

    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    // Set while Spidey itself writes to the pasteboard, so we do not re-record it.
    private var ignoreNextChange = false

    private let directory: URL
    // Tests inject a fixed cap so they do not depend on SettingsStore.
    private let limitOverride: Int?

    private var historyFile: URL { directory.appendingPathComponent("clipboard.json") }
    private var imagesDirectory: URL { directory.appendingPathComponent("images", isDirectory: true) }

    private convenience init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.init(directory: base.appendingPathComponent("Spidey", isDirectory: true))
    }

    init(directory: URL, limitOverride: Int? = nil) {
        self.directory = directory
        self.limitOverride = limitOverride
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        load()
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        if ignoreNextChange {
            ignoreNextChange = false
            return
        }

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let fileURL = urls.first(where: \.isFileURL) {
            record(ClipEntry(id: UUID(), kind: .file, date: Date(), value: fileURL.path))
        } else if let text = pasteboard.string(forType: .string),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            record(ClipEntry(id: UUID(), kind: .text, date: Date(), value: text))
        } else if let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            guard imageData.count < 8_000_000 else { return }
            let name = UUID().uuidString + ".png"
            let pngData: Data
            if pasteboard.data(forType: .png) != nil {
                pngData = imageData
            } else if let rep = NSBitmapImageRep(data: imageData),
                      let converted = rep.representation(using: .png, properties: [:]) {
                pngData = converted
            } else {
                return
            }
            try? pngData.write(to: imagesDirectory.appendingPathComponent(name))
            record(ClipEntry(id: UUID(), kind: .image, date: Date(), value: name))
        }
    }

    func record(_ entry: ClipEntry) {
        // Copying a value that is already pinned just refreshes it in place.
        if let index = entries.firstIndex(where: { $0.kind == entry.kind && $0.value == entry.value && $0.pinned }) {
            entries[index].date = entry.date
            trimAndSort()
            return
        }
        // De-duplicate consecutive copies of the same value.
        entries.removeAll { $0.kind == entry.kind && $0.value == entry.value }
        entries.insert(entry, at: 0)
        trimAndSort()
    }

    func recordDroppedFile(_ url: URL) {
        record(ClipEntry(id: UUID(), kind: .file, date: Date(), value: url.path))
    }

    // How many screenshot rows the watcher keeps around.
    static let screenshotKeepCount = 5

    func recordScreenshot(path: String, date: Date) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        record(ClipEntry(id: UUID(), kind: .file, date: date, value: path, isScreenshot: true))
        var seen = 0
        entries.removeAll { entry in
            guard entry.fromScreenshot else { return false }
            seen += 1
            return seen > Self.screenshotKeepCount
        }
        save()
    }

    // Screenshots live wherever macOS saved them; if the user deleted one,
    // its history row is dead weight.
    func pruneMissingScreenshots() {
        let before = entries.count
        entries.removeAll { $0.fromScreenshot && !FileManager.default.fileExists(atPath: $0.value) }
        if entries.count != before { save() }
    }

    // Toggles the pinned flag on the entry with the same id.
    func togglePin(_ entry: ClipEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].pinned.toggle()
        trimAndSort()
    }

    // Puts an entry back on the system pasteboard.
    func copyToPasteboard(_ entry: ClipEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        ignoreNextChange = true
        switch entry.kind {
        case .text:
            pasteboard.setString(entry.value, forType: .string)
        case .file:
            pasteboard.writeObjects([NSURL(fileURLWithPath: entry.value)])
        case .image:
            if let data = try? Data(contentsOf: imagesDirectory.appendingPathComponent(entry.value)) {
                pasteboard.setData(data, forType: .png)
            }
        }
    }

    // Call just before Spidey itself rewrites the pasteboard (e.g. plain-text
    // conversion), so the change is not re-recorded into history.
    func ignoreNextPasteboardChange() {
        ignoreNextChange = true
    }

    func imageURL(for entry: ClipEntry) -> URL? {
        guard entry.kind == .image else { return nil }
        return imagesDirectory.appendingPathComponent(entry.value)
    }

    func clear() {
        for entry in entries where entry.kind == .image {
            try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(entry.value))
        }
        entries = []
        save()
    }

    // Caps unpinned entries at the history limit (pinned entries are exempt),
    // keeps pinned entries above unpinned ones, and persists the result.
    private func trimAndSort() {
        let limit = max(10, limitOverride ?? SettingsStore.shared.clipboardLimit)
        var pinned = entries.filter(\.pinned)
        var unpinned = entries.filter { !$0.pinned }
        // Newest-first within each group, so an unpinned entry falls back to
        // its date slot and refreshed pins bubble up.
        pinned.sort { $0.date > $1.date }
        unpinned.sort { $0.date > $1.date }
        if unpinned.count > limit {
            for removed in unpinned[limit...] where removed.kind == .image {
                try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(removed.value))
            }
            unpinned = Array(unpinned.prefix(limit))
        }
        entries = pinned + unpinned
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: historyFile),
              let decoded = try? JSONDecoder().decode([ClipEntry].self, from: data) else { return }
        entries = decoded.filter(\.pinned) + decoded.filter { !$0.pinned }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: historyFile)
    }
}
