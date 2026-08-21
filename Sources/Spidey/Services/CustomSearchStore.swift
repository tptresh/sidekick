import Foundation

// A user-defined search keyword from ~/Library/Application Support/Spidey/searches.json,
// in the spirit of Alfred custom searches: "yt lofi beats" opens YouTube results.
struct CustomSearch: Equatable {
    let keyword: String
    let name: String
    let urlTemplate: String

    static let queryPlaceholder = "{query}"

    // Braces are invalid in URLs, so stand in a dummy term before parsing.
    static func host(of template: String) -> String? {
        let parseable = template
            .replacingOccurrences(of: queryPlaceholder, with: "q")
            .replacingOccurrences(of: "%s", with: "q")
        return URL(string: parseable)?.host
    }

    var host: String? { Self.host(of: urlTemplate) }

    var homepageURLString: String {
        guard let host else { return urlTemplate }
        return "https://\(host)"
    }

    func searchURL(for query: String) -> URL? {
        let encoded = BrowserLauncher.encodeQuery(query)
        let filled = urlTemplate
            .replacingOccurrences(of: Self.queryPlaceholder, with: encoded)
            .replacingOccurrences(of: "%s", with: encoded)
        return URL(string: filled)
    }
}

// Reads searches.json, mapping keyword -> {name, url} (or a bare URL string,
// with the name derived from the host). Reloads when the file's mtime changes.
final class CustomSearchStore {
    static let shared = CustomSearchStore()

    let fileURL: URL
    private var cached: [String: CustomSearch] = [:]
    private var lastModified: Date?
    private var hasLoaded = false

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = base.appendingPathComponent("Spidey/searches.json")
        }
    }

    var fileExists: Bool { FileManager.default.fileExists(atPath: fileURL.path) }

    func searches() -> [String: CustomSearch] {
        reloadIfNeeded()
        return cached
    }

    func search(for keyword: String) -> CustomSearch? {
        searches()[keyword.lowercased()]
    }

    private func reloadIfNeeded() {
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        let modified = attributes?[.modificationDate] as? Date
        if hasLoaded, modified == lastModified { return }
        lastModified = modified
        hasLoaded = true
        guard let data = try? Data(contentsOf: fileURL) else {
            cached = [:]
            return
        }
        cached = Self.parse(data)
    }

    // Tolerant of both entry forms, comments (JSON5), and junk entries.
    static func parse(_ data: Data) -> [String: CustomSearch] {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: [.json5Allowed]),
              let dict = object as? [String: Any] else { return [:] }
        var result: [String: CustomSearch] = [:]
        for (rawKeyword, value) in dict {
            let keyword = rawKeyword.trimmingCharacters(in: .whitespaces).lowercased()
            guard !keyword.isEmpty else { continue }
            var name = ""
            let template: String
            if let url = value as? String {
                template = url.trimmingCharacters(in: .whitespaces)
            } else if let entry = value as? [String: Any], let url = entry["url"] as? String {
                template = url.trimmingCharacters(in: .whitespaces)
                name = (entry["name"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            } else {
                continue
            }
            guard template.contains(CustomSearch.queryPlaceholder) || template.contains("%s"),
                  let host = CustomSearch.host(of: template) else { continue }
            if name.isEmpty {
                name = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            }
            result[keyword] = CustomSearch(keyword: keyword, name: name, urlTemplate: template)
        }
        return result
    }

    static let exampleFileContent = """
    // Spidey custom searches: keyword -> search URL template.
    // {query} is replaced with whatever you type after the keyword,
    // so "yt lofi beats" opens the YouTube results for "lofi beats".
    // Two entry forms are accepted:
    //   "yt":  { "name": "YouTube", "url": "https://...{query}" }
    //   "ddg": "https://duckduckgo.com/?q={query}"
    {
        "yt": { "name": "YouTube", "url": "https://www.youtube.com/results?search_query={query}" },
        "ddg": "https://duckduckgo.com/?q={query}"
    }
    """

    @discardableResult
    func createExampleFile() -> URL? {
        guard !fileExists else { return fileURL }
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard (try? Self.exampleFileContent.write(to: fileURL, atomically: true, encoding: .utf8)) != nil
        else { return nil }
        return fileURL
    }
}
