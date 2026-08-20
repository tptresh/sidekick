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
            NSWorkspace.shared.open(
                [url], withApplicationAt: brave,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    static var targetName: String { braveInstalled ? "Brave" : "your default browser" }

    static func encodeQuery(_ query: String) -> String {
        query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "&", with: "%26") ?? query
    }
}
