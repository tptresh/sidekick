import AppKit

final class AppProvider {
    static let shared = AppProvider()

    struct AppEntry {
        let name: String
        let url: URL
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
                        found.append(AppEntry(
                            name: (item as NSString).deletingPathExtension,
                            url: URL(fileURLWithPath: path)
                        ))
                    } else if (try? fm.contentsOfDirectory(atPath: path)) != nil, !item.hasPrefix(".") {
                        // One level of subfolders, e.g. /Applications/Utilities.
                        for sub in (try? fm.contentsOfDirectory(atPath: path)) ?? [] where sub.hasSuffix(".app") {
                            found.append(AppEntry(
                                name: (sub as NSString).deletingPathExtension,
                                url: URL(fileURLWithPath: path + "/" + sub)
                            ))
                        }
                    }
                }
            }
            DispatchQueue.main.async {
                self.apps = found
            }
        }
    }

    func results(for query: String) -> [ResultItem] {
        guard !query.isEmpty else { return [] }
        var items: [ResultItem] = []
        for app in apps {
            guard let match = Fuzzy.score(query: query, candidate: app.name) else { continue }
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
