import Foundation

struct Bookmark: Equatable {
    let name: String
    let url: String
    let host: String

    init(name: String, url: String) {
        self.name = name
        self.url = url
        self.host = URL(string: url)?.host ?? ""
    }
}

// Reads Chromium-family bookmark files (Brave first, then Chrome, then Edge)
// across the Default and "Profile N" profiles, merged and de-duplicated by URL.
// Files are parsed off the main thread and cached in memory; they are re-read
// only when a file's modification date changes.
final class BookmarkStore {
    static let shared = BookmarkStore()

    private var bookmarks: [Bookmark] = []
    private var stamps: [String: Date] = [:]
    private var lastCheck = Date.distantPast
    private var loading = false
    private let queue = DispatchQueue(label: "spidey.bookmarks", qos: .utility)

    private init() {
        reloadIfNeeded(force: true)
    }

    // Main thread only. Returns the cached list, refreshing in the background
    // when any bookmark file has changed since the last look.
    func entries() -> [Bookmark] {
        reloadIfNeeded(force: false)
        return bookmarks
    }

    private func reloadIfNeeded(force: Bool) {
        guard !loading, force || Date().timeIntervalSince(lastCheck) > 30 else { return }
        lastCheck = Date()
        loading = true
        let known = stamps
        queue.async {
            let files = Self.bookmarkFiles()
            var current: [String: Date] = [:]
            for file in files {
                let mtime = (try? FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate]) as? Date
                current[file.path] = mtime ?? .distantPast
            }
            if !force, current == known {
                DispatchQueue.main.async { self.loading = false }
                return
            }
            var found: [Bookmark] = []
            for file in files {
                guard let data = try? Data(contentsOf: file) else { continue }
                found += Self.parse(data)
            }
            let merged = Self.dedupe(found)
            DispatchQueue.main.async {
                self.bookmarks = merged
                self.stamps = current
                self.loading = false
            }
        }
    }

    // Brave outranks Chrome outranks Edge: dedupe keeps the first occurrence.
    private static func bookmarkFiles() -> [URL] {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let roots = [
            "BraveSoftware/Brave-Browser",
            "Google/Chrome",
            "Microsoft Edge",
        ]
        let fm = FileManager.default
        var files: [URL] = []
        for root in roots {
            let base = appSupport.appendingPathComponent(root, isDirectory: true)
            var profiles = ["Default"]
            if let names = try? fm.contentsOfDirectory(atPath: base.path) {
                profiles += names.filter { $0.hasPrefix("Profile ") }.sorted()
            }
            for profile in profiles {
                let file = base.appendingPathComponent(profile).appendingPathComponent("Bookmarks")
                if fm.fileExists(atPath: file.path) {
                    files.append(file)
                }
            }
        }
        return files
    }

    static func parse(_ data: Data) -> [Bookmark] {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let roots = json["roots"] as? [String: Any] else { return [] }
        var found: [Bookmark] = []
        for key in ["bookmark_bar", "other", "synced"] {
            if let node = roots[key] as? [String: Any] {
                collect(node, into: &found)
            }
        }
        return found
    }

    private static func collect(_ node: [String: Any], into found: inout [Bookmark]) {
        if node["type"] as? String == "url",
           let name = node["name"] as? String,
           let url = node["url"] as? String {
            found.append(Bookmark(name: name, url: url))
        } else if let children = node["children"] as? [[String: Any]] {
            for child in children {
                collect(child, into: &found)
            }
        }
    }

    static func dedupe(_ bookmarks: [Bookmark]) -> [Bookmark] {
        var seen = Set<String>()
        return bookmarks.filter { seen.insert($0.url).inserted }
    }
}
