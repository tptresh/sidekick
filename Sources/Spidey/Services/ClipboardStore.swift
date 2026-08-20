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

    @Published private(set) var entries: [ClipEntry] = []

    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    // Set while Spidey itself writes to the pasteboard, so we do not re-record it.
    private var ignoreNextChange = false

    private let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Spidey", isDirectory: true)
    }()
    private var historyFile: URL { directory.appendingPathComponent("clipboard.json") }
    private var imagesDirectory: URL { directory.appendingPathComponent("images", isDirectory: true) }

    private init() {
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
        // De-duplicate consecutive copies of the same value.
        entries.removeAll { $0.kind == entry.kind && $0.value == entry.value }
        entries.insert(entry, at: 0)
        let limit = max(10, SettingsStore.shared.clipboardLimit)
        if entries.count > limit {
            for removed in entries[limit...] where removed.kind == .image {
                try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(removed.value))
            }
            entries = Array(entries.prefix(limit))
        }
        save()
    }

    func recordDroppedFile(_ url: URL) {
        record(ClipEntry(id: UUID(), kind: .file, date: Date(), value: url.path))
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

    private func load() {
        guard let data = try? Data(contentsOf: historyFile),
              let decoded = try? JSONDecoder().decode([ClipEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: historyFile)
    }
}
