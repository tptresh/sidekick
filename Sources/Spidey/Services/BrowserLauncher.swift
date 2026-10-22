import AppKit

enum BrowserLauncher {
    static let braveBundleID = "com.brave.Browser"

    static var braveURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: braveBundleID)
    }

    static var braveInstalled: Bool { braveURL != nil }

    // Opens in Brave when installed, otherwise falls back to the default browser.
    static func open(_ url: URL) {
        if let brave = braveURL {
            ScreenFollow.shared.expect(bundleID: braveBundleID)
            NSWorkspace.shared.open(
                [url], withApplicationAt: brave,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } else {
            let app = NSWorkspace.shared.urlForApplication(toOpen: url)
            ScreenFollow.shared.expect(bundleID: app.flatMap { Bundle(url: $0)?.bundleIdentifier })
            NSWorkspace.shared.open(url)
        }
    }

    static var targetName: String { braveInstalled ? "Brave" : "your default browser" }

    // Rows that just hand a URL to the browser show Brave's own icon. Looked up
    // once because the web-search fallback rebuilds on every keystroke.
    private static let cachedBraveIcon: ResultIcon? = {
        guard let brave = braveURL else { return nil }
        return .appIcon(NSWorkspace.shared.icon(forFile: brave.path))
    }()

    static func targetIcon(fallbackSymbol: String) -> ResultIcon {
        cachedBraveIcon ?? .symbol(fallbackSymbol)
    }

    static func encodeQuery(_ query: String) -> String {
        query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "&", with: "%26") ?? query
    }
}
