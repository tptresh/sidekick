import AppKit

extension Notification.Name {
    static let spideyFaviconLoaded = Notification.Name("SpideyFaviconLoaded")
}

// Fetches real site logos (favicons) once, caches them on disk, and serves
// them from memory. Rows fall back to an SF Symbol until the logo arrives.
final class FaviconStore {
    static let shared = FaviconStore()

    private var cache: [String: NSImage] = [:]
    private var missing: Set<String> = []
    private var inFlight: Set<String> = []

    private let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Spidey/favicons", isDirectory: true)
    }()

    private init() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // Main thread only. Returns the cached logo, or nil while it downloads.
    func icon(for urlString: String) -> NSImage? {
        guard let host = URL(string: urlString)?.host else { return nil }
        if let cached = cache[host] { return cached }
        let file = directory.appendingPathComponent(host + ".png")
        if let image = NSImage(contentsOf: file) {
            image.size = NSSize(width: 32, height: 32)
            cache[host] = image
            return image
        }
        fetch(host: host)
        return nil
    }

    private func fetch(host: String) {
        guard !missing.contains(host), !inFlight.contains(host),
              let url = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64")
        else { return }
        inFlight.insert(host)
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                self.inFlight.remove(host)
                guard let data, !data.isEmpty, let image = NSImage(data: data) else {
                    self.missing.insert(host)
                    return
                }
                image.size = NSSize(width: 32, height: 32)
                try? data.write(to: self.directory.appendingPathComponent(host + ".png"))
                self.cache[host] = image
                NotificationCenter.default.post(name: .spideyFaviconLoaded, object: nil)
            }
        }.resume()
    }

    // Convenience for building a row icon with a symbol fallback.
    func resultIcon(for urlString: String, fallbackSymbol: String) -> ResultIcon {
        if let image = icon(for: urlString) {
            return .appIcon(image)
        }
        return .symbol(fallbackSymbol)
    }
}
