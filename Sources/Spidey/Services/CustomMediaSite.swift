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
    // Search URL worked out by SearchTemplateFinder for plain links, so
    // queries hit the site's own search instead of a Google fallback.
    var discoveredTemplate: String?

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

    // Sites saved before the newer flags existed decode with their defaults.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        urlString = try container.decode(String.self, forKey: .urlString)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        discoveredTemplate = try container.decodeIfPresent(String.self, forKey: .discoveredTemplate)
    }

    init(
        id: UUID = UUID(), name: String = "", urlString: String = "",
        enabled: Bool = true, discoveredTemplate: String? = nil
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.enabled = enabled
        self.discoveredTemplate = discoveredTemplate
    }

    // The discovered template only counts while it still matches the entered
    // host, so editing the link automatically invalidates a stale discovery.
    var activeDiscoveredTemplate: String? {
        guard !hasSearchTemplate, let discoveredTemplate,
              let templateURL = URL(string: discoveredTemplate.replacingOccurrences(
                of: Self.queryPlaceholder, with: "q"
              )),
              templateURL.host == host
        else { return nil }
        return discoveredTemplate
    }

    // True when queries go to the site's own search rather than via Google.
    var searchesDirectly: Bool {
        hasSearchTemplate || activeDiscoveredTemplate != nil
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
        if let template = activeDiscoveredTemplate {
            return URL(string: template.replacingOccurrences(
                of: Self.queryPlaceholder, with: encodedQuery
            ))
        }
        return URL(string: "https://www.google.com/search?q=site:\(host)+\(encodedQuery)")
    }
}
