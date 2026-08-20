import Foundation

struct Snippet: Codable, Identifiable, Equatable {
    var id: UUID
    var keyword: String
    var name: String
    var content: String
    var dateAdded: Date

    // One-line preview for result subtitles.
    var preview: String {
        let flattened = content.replacingOccurrences(of: "\n", with: " ")
        return flattened.count > 60 ? String(flattened.prefix(60)) + "…" : flattened
    }
}

final class SnippetStore {
    static let shared = SnippetStore()

    private let fileURL: URL
    // nil until first access; the file is only read when a query needs it.
    private var cached: [Snippet]?

    // Tests inject a temp directory so they never touch the real store.
    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Spidey", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("snippets.json")
    }

    var snippets: [Snippet] {
        if let cached { return cached }
        let loaded = (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONDecoder().decode([Snippet].self, from: $0) } ?? []
        cached = loaded
        return loaded
    }

    // Keywords match case-insensitively, so they are stored lowercased.
    // Re-adding an existing keyword replaces its content.
    @discardableResult
    func add(keyword: String, content: String) -> Snippet {
        let key = keyword.lowercased()
        var all = snippets
        all.removeAll { $0.keyword == key }
        let snippet = Snippet(id: UUID(), keyword: key, name: keyword, content: content, dateAdded: Date())
        all.insert(snippet, at: 0)
        cached = all
        save()
        return snippet
    }

    func remove(keyword: String) {
        let key = keyword.lowercased()
        var all = snippets
        all.removeAll { $0.keyword == key }
        cached = all
        save()
    }

    func snippet(forKeyword keyword: String) -> Snippet? {
        snippets.first { $0.keyword == keyword.lowercased() }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(cached ?? []) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
