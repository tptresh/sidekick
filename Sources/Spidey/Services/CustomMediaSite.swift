import Foundation

// A user-added media site from Preferences. The URL is either a search
// template containing {query} (or %s), or a plain address; plain addresses
// are searched with a site-scoped Google query so Spidey never has to know
// the site's own search URL scheme.
struct CustomMediaSite: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var urlString = ""
    // Custom sites tick on and off just like the built-in services.
    var enabled = true

    static let queryPlaceholder = "{query}"

    // "flickystream.dad" becomes "https://flickystream.dad".
    var normalizedURLString: String {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        return trimmed.contains("://") ? trimmed : "https://" + trimmed
    }

    var hasSearchTemplate: Bool {
        normalizedURLString.contains(Self.queryPlaceholder) || normalizedURLString.contains("%s")
    }

    var host: String? {
        // Braces are invalid in URLs, so stand in a dummy term before parsing.
        let parseable = normalizedURLString
            .replacingOccurrences(of: Self.queryPlaceholder, with: "q")
            .replacingOccurrences(of: "%s", with: "q")
        return URL(string: parseable)?.host
    }

    var isValid: Bool { host != nil }

    var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if !trimmedName.isEmpty { return trimmedName }
        guard let host else { return "Custom site" }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    var homepageURL: URL? {
        guard let host else { return nil }
        return URL(string: "https://\(host)")
    }

    // Sites saved before the enabled flag existed decode as enabled.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        urlString = try container.decode(String.self, forKey: .urlString)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }

    init(id: UUID = UUID(), name: String = "", urlString: String = "", enabled: Bool = true) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.enabled = enabled
    }

    // encodedQuery must already be percent-encoded.
    func searchURL(encodedQuery: String) -> URL? {
        guard let host else { return nil }
        if hasSearchTemplate {
            let filled = normalizedURLString
                .replacingOccurrences(of: Self.queryPlaceholder, with: encodedQuery)
                .replacingOccurrences(of: "%s", with: encodedQuery)
            return URL(string: filled)
        }
        return URL(string: "https://www.google.com/search?q=site:\(host)+\(encodedQuery)")
    }
}
