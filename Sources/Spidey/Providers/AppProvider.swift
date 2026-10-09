import AppKit

final class AppProvider {
    static let shared = AppProvider()

    struct AppEntry {
        let name: String
        let url: URL
        let bundleID: String?
        // Other names people type for this app, e.g. "Apple TV" for TV.app.
        let aliases: [String]

        // Stable identity for learned ranking; bundle id survives the app
        // moving, the path is the fallback for bundle-less apps.
        var rankingKey: String { "app:" + (bundleID ?? url.path) }
    }

    private var apps: [AppEntry] = []
    // Tests set this so ranking checks do not depend on what this Mac has installed.
    var appsOverride: [AppEntry]?
    private var iconCache: [URL: NSImage] = [:]
    private let scanQueue = DispatchQueue(label: "spidey.appscan", qos: .utility)

    // User-defined launch aliases from Application Support/Spidey/aliases.json,
    // e.g. {"ps": "Photoshop"}. Keys are stored lowercased.
    private var userAliases: [String: String] = [:]
    private var userAliasesMTime: Date?

    private init() {
        rescan()
        // Pick up newly installed apps every few minutes.
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.rescan()
        }
    }

    func rescan() {
        scanQueue.async {
            var found: [AppEntry] = []
            let roots = [
                "/Applications",
                "/System/Applications",
                "/System/Applications/Utilities",
                "/System/Library/CoreServices/Applications",
                NSHomeDirectory() + "/Applications",
            ]
            let fm = FileManager.default
            for root in roots {
                guard let items = try? fm.contentsOfDirectory(atPath: root) else { continue }
                for item in items {
                    let path = root + "/" + item
                    if item.hasSuffix(".app") {
                        found.append(Self.entry(forAppAt: path))
                    } else if (try? fm.contentsOfDirectory(atPath: path)) != nil, !item.hasPrefix(".") {
                        // One level of subfolders, e.g. /Applications/Utilities.
                        for sub in (try? fm.contentsOfDirectory(atPath: path)) ?? [] where sub.hasSuffix(".app") {
                            found.append(Self.entry(forAppAt: path + "/" + sub))
                        }
                    }
                }
            }
            DispatchQueue.main.async {
                self.apps = found
            }
        }
    }

    private static func entry(forAppAt path: String) -> AppEntry {
        let url = URL(fileURLWithPath: path)
        let name = url.deletingPathExtension().lastPathComponent
        let bundle = Bundle(url: url)
        let display = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
        return AppEntry(
            name: name,
            url: url,
            bundleID: bundle?.bundleIdentifier,
            aliases: aliases(name: name, displayName: display, bundleIdentifier: bundle?.bundleIdentifier)
        )
    }

    // MARK: - User aliases (aliases.json)

    static var userAliasesURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Spidey/aliases.json")
    }

    // {"ps": "Photoshop", "vs": "Visual Studio Code"} -> lowercased alias map.
    static func parseUserAliases(_ data: Data) -> [String: String] {
        guard let raw = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        var result: [String: String] = [:]
        for (alias, target) in raw {
            let key = alias.lowercased().trimmingCharacters(in: .whitespaces)
            let value = target.trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !value.isEmpty else { continue }
            result[key] = value
        }
        return result
    }

    // Re-reads aliases.json only when its modification date changes (a stat
    // per keystroke, a read only on edits). A deleted file clears the map.
    private func reloadUserAliasesIfNeeded() {
        let url = Self.userAliasesURL
        let mtime = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
        guard mtime != userAliasesMTime else { return }
        userAliasesMTime = mtime
        if mtime != nil, let data = try? Data(contentsOf: url) {
            userAliases = Self.parseUserAliases(data)
        } else {
            userAliases = [:]
        }
    }

    static func aliases(name: String, displayName: String?, bundleIdentifier: String?) -> [String] {
        var aliases: [String] = []
        if let displayName, displayName.caseInsensitiveCompare(name) != .orderedSame {
            aliases.append(displayName)
        }
        // Apple ships its apps under bare names, but people say "Apple TV",
        // "Apple Music", "Apple Notes". Give first-party apps that alias.
        if bundleIdentifier?.hasPrefix("com.apple.") == true,
           !name.localizedCaseInsensitiveContains("apple") {
            aliases.append("Apple " + name)
        }
        return aliases
    }

    static func matchScore(query: String, name: String, aliases: [String]) -> Double? {
        var best = Fuzzy.score(query: query, candidate: name)
        for alias in aliases {
            guard let score = Fuzzy.score(query: query, candidate: alias) else { continue }
            // A hair below the real name so it still wins exact-name ties.
            let discounted = score * 0.98
            if discounted > (best ?? 0) { best = discounted }
        }
        return best
    }

    // When the query (or its first word) is a user alias, the app the alias
    // points at is scored as an exact match. The target only has to match the
    // app reasonably well ("Photoshop" vs "Adobe Photoshop 2024" is a
    // word-boundary match at 0.82), so the threshold sits just under that.
    static func effectiveMatch(
        query: String, aliasTarget: String?, name: String, aliases: [String]
    ) -> Double? {
        let direct = matchScore(query: query, name: name, aliases: aliases)
        if let target = aliasTarget,
           let targetScore = matchScore(query: target, name: name, aliases: aliases),
           targetScore >= 0.8 {
            return 1.0
        }
        return direct
    }

    func results(for query: String) -> [ResultItem] {
        guard !query.isEmpty else { return [] }
        reloadUserAliasesIfNeeded()
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        let firstWord = lowered.split(separator: " ").first.map(String.init) ?? lowered
        let aliasTarget = userAliases[lowered] ?? userAliases[firstWord]
        var items: [ResultItem] = []
        for app in appsOverride ?? apps {
            guard let match = Self.effectiveMatch(
                query: query, aliasTarget: aliasTarget, name: app.name, aliases: app.aliases
            ) else { continue }
            let url = app.url
            items.append(ResultItem(
                title: app.name,
                subtitle: "Open application",
                icon: .appIcon(icon(for: url)),
                score: Self.score(forMatch: match),
                rankingKey: app.rankingKey,
                dragFileURL: url,
                secondaryAction: { NSWorkspace.shared.activateFileViewerSelecting([url]) },
                action: { NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) }
            ))
        }
        return items.sorted { $0.score > $1.score }.prefix(6).map { $0 }
    }

    // An exact name jumps above same-named websites (tier-3 sites top out at
    // 945) but stays under intent rows like conversions (985 and up).
    static func score(forMatch match: Double) -> Double {
        match >= 1.0 ? 960 : 600 + match * 300
    }

    private func icon(for url: URL) -> NSImage {
        if let cached = iconCache[url] { return cached }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)
        iconCache[url] = icon
        return icon
    }
}
