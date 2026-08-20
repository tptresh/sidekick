import AppKit

final class AppProvider {
    static let shared = AppProvider()

    struct AppEntry {
        let name: String
        let url: URL
        // Other names people type for this app, e.g. "Apple TV" for TV.app.
        let aliases: [String]
    }

    private var apps: [AppEntry] = []
    private var iconCache: [URL: NSImage] = [:]
    private let scanQueue = DispatchQueue(label: "spidey.appscan", qos: .utility)

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
            aliases: aliases(name: name, displayName: display, bundleIdentifier: bundle?.bundleIdentifier)
        )
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

    func results(for query: String) -> [ResultItem] {
        guard !query.isEmpty else { return [] }
        var items: [ResultItem] = []
        for app in apps {
            guard let match = Self.matchScore(query: query, name: app.name, aliases: app.aliases) else { continue }
            let url = app.url
            items.append(ResultItem(
                title: app.name,
                subtitle: "Open application",
                icon: .appIcon(icon(for: url)),
                score: 600 + match * 300,
                dragFileURL: url,
                secondaryAction: { NSWorkspace.shared.activateFileViewerSelecting([url]) },
                action: { NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) }
            ))
        }
        return items.sorted { $0.score > $1.score }.prefix(6).map { $0 }
    }

    private func icon(for url: URL) -> NSImage {
        if let cached = iconCache[url] { return cached }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)
        iconCache[url] = icon
        return icon
    }
}
