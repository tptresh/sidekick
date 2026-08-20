import AppKit

// File search: Spotlight (mdfind) across every indexed volume, merged with a
// direct index of Documents, Downloads, and Desktop. The direct index exists
// because macOS hides those folders from Spotlight results until the user
// grants Spidey folder access, and reading them is what triggers the one-time
// permission prompts.
enum FileProvider {
    enum Mode {
        // Mixed into the normal result list alongside apps and sites.
        case ambient
        // The "find" keyword: files are the only results, so dig deeper.
        case dedicated
        // The "in" keyword: match file CONTENTS (kMDItemTextContent) instead
        // of file names, e.g. `in quarterly forecast`.
        case content
    }

    private static var currentProcess: Process?

    // MARK: - Direct index of the classic user folders

    static let indexedFolders = ["Documents", "Downloads", "Desktop"]

    private static let indexLock = NSLock()
    private static var indexedPaths: [String] = []
    private static var indexBuiltAt: Date?
    private static var indexBuilding = false

    // Kick off the first index build (and the macOS folder permission prompts)
    // without waiting for the first search.
    static func warmUp() {
        DispatchQueue.global(qos: .utility).async { refreshIndexIfStale() }
    }

    private static func refreshIndexIfStale() {
        indexLock.lock()
        let stale = indexBuiltAt.map { Date().timeIntervalSince($0) > 300 } ?? true
        let shouldBuild = stale && !indexBuilding
        if shouldBuild { indexBuilding = true }
        indexLock.unlock()
        guard shouldBuild else { return }

        let fm = FileManager.default
        var found: [String] = []
        for folder in indexedFolders {
            let root = URL(fileURLWithPath: NSHomeDirectory() + "/" + folder)
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            for case let url as URL in enumerator {
                let path = url.path
                if path.hasSuffix("/node_modules") || path.hasSuffix("/Library") {
                    enumerator.skipDescendants()
                    continue
                }
                found.append(path)
                if found.count >= 50_000 { break }
            }
        }
        indexLock.lock()
        indexedPaths = found
        indexBuiltAt = Date()
        indexBuilding = false
        indexLock.unlock()
    }

    private static func indexMatches(for query: String) -> [String] {
        let tokens = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return [] }
        indexLock.lock()
        let paths = indexedPaths
        indexLock.unlock()
        return paths.filter { path in
            let name = (path as NSString).lastPathComponent.lowercased()
            return tokens.allSatisfy { name.contains($0) }
        }
    }

    // MARK: - Query building and ranking

    // Builds a raw Spotlight query where every whitespace-separated word must
    // appear in the file name, so "auracare deck" finds "auracare-deck.pdf".
    static func spotlightQuery(for query: String) -> String? {
        let clauses = query.split(whereSeparator: \.isWhitespace).compactMap { token -> String? in
            let escaped = token
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "*", with: "")
            guard !escaped.isEmpty else { return nil }
            return "kMDItemFSName = \"*\(escaped)*\"cd"
        }
        guard !clauses.isEmpty else { return nil }
        return clauses.joined(separator: " && ")
    }

    // Builds a raw Spotlight query matching the phrase against extracted file
    // text, so `in quarterly forecast` finds documents CONTAINING that phrase.
    static func contentQuery(for phrase: String) -> String? {
        let escaped = phrase
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !escaped.isEmpty else { return nil }
        return "kMDItemTextContent = \"*\(escaped)*\"cd"
    }

    // Paths that are technically files but never what a person is looking for.
    static func isNoise(_ path: String) -> Bool {
        if path.contains("/Library/") || path.contains("/.") || path.contains("/node_modules/") {
            return true
        }
        // Apps and their bundle contents are AppProvider territory.
        if path.hasSuffix(".app") || path.contains(".app/") {
            return true
        }
        let systemRoots = ["/System/", "/private/", "/usr/", "/bin/", "/sbin/", "/opt/", "/etc/", "/Applications/", "/cores/"]
        return systemRoots.contains { path.hasPrefix($0) }
    }

    // 0...1 relevance of a path for the query, judged on the file name with a
    // tiny penalty for deeply buried paths so shallow files win ties.
    static func matchScore(query: String, path: String) -> Double {
        let name = (path as NSString).lastPathComponent
        let stem = (name as NSString).deletingPathExtension
        let lowered = query.lowercased()
        if stem.lowercased() == lowered || name.lowercased() == lowered {
            return 1.0
        }
        let tokens = lowered.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return 0 }
        // Sources already matched the name, but diacritic folding can hide the
        // match from Fuzzy, so unmatched tokens still get a floor score.
        let total = tokens.reduce(0.0) { sum, token in
            sum + (Fuzzy.score(query: token, candidate: name) ?? 0.15)
        }
        return max(0, total / Double(tokens.count) - Double(path.count) * 0.0002)
    }

    // MARK: - Search

    static func search(_ query: String, mode: Mode = .ambient, completion: @escaping ([ResultItem]) -> Void) {
        currentProcess?.terminate()
        let rawQuery = mode == .content ? contentQuery(for: query) : spotlightQuery(for: query)
        guard query.count >= 2, let spotlight = rawQuery else {
            completion([])
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = [spotlight]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        currentProcess = process

        // The explicit keyword modes are the only results on screen, so dig
        // deeper and rank them above everything else.
        let limit = mode == .ambient ? 10 : 40
        let baseScore = mode == .ambient ? 320.0 : 500.0
        let spread = mode == .ambient ? 140.0 : 400.0
        // Content queries scan extracted document text and run longer.
        let deadline: TimeInterval = mode == .content ? 3.5 : 2.5

        DispatchQueue.global(qos: .userInitiated).async {
            var paths: [String] = []
            do {
                try process.run()
                // Give slow queries a hard stop.
                DispatchQueue.global().asyncAfter(deadline: .now() + deadline) {
                    if process.isRunning { process.terminate() }
                }
                refreshIndexIfStale()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                paths = String(decoding: data, as: UTF8.self)
                    .split(separator: "\n")
                    .map(String.init)
            } catch {
                paths = []
            }
            // The direct folder index only knows file names, so it can't
            // vouch for content matches.
            if mode != .content {
                paths += indexMatches(for: query)
            }

            var seen = Set<String>()
            let ranked = paths
                .filter { !isNoise($0) && seen.insert($0).inserted }
                .map { (path: $0, match: matchScore(query: query, path: $0)) }
                .sorted { $0.match > $1.match }
                .prefix(limit)

            let items: [ResultItem] = ranked.map { path, match in
                let url = URL(fileURLWithPath: path)
                let icon = NSWorkspace.shared.icon(forFile: path)
                icon.size = NSSize(width: 32, height: 32)
                let shortPath = path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
                let subtitle = mode == .content
                    ? "Contains \"\(query)\" — \(shortPath)"
                    : shortPath + "  (⌘↩ reveals, ⌘Y previews)"
                return ResultItem(
                    title: url.lastPathComponent,
                    subtitle: subtitle,
                    icon: .appIcon(icon),
                    score: baseScore + match * spread,
                    dragFileURL: url,
                    secondaryAction: { NSWorkspace.shared.activateFileViewerSelecting([url]) },
                    action: { NSWorkspace.shared.open(url) }
                )
            }
            DispatchQueue.main.async { completion(items) }
        }
    }
}
