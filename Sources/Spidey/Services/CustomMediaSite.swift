import Foundation

// A user-added media site from Preferences. The URL is either a search
// template containing {query} (or %s), or a plain address; for plain
// addresses Spidey learns how the site's search works by driving it in a
// hidden web view (see InteractiveSearchProber).
struct CustomMediaSite: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var urlString = ""
    // Custom sites tick on and off just like the built-in services.
    var enabled = true
    // Search results page URL learned for plain links, so queries hit the
    // site's own search page.
    var discoveredTemplate: String?
    // For sites whose search never has its own URL: the internal search API
    // observed while typing into the site's own search box, plus the learned
    // pattern of its title-page links, filled from the API's top result.
    var discoveredAPITemplate: String?
    var discoveredTitleTemplate: String?

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
        discoveredAPITemplate = try container.decodeIfPresent(
            String.self, forKey: .discoveredAPITemplate)
        discoveredTitleTemplate = try container.decodeIfPresent(
            String.self, forKey: .discoveredTitleTemplate)
    }

    init(
        id: UUID = UUID(), name: String = "", urlString: String = "",
        enabled: Bool = true, discoveredTemplate: String? = nil,
        discoveredAPITemplate: String? = nil, discoveredTitleTemplate: String? = nil
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.enabled = enabled
        self.discoveredTemplate = discoveredTemplate
        self.discoveredAPITemplate = discoveredAPITemplate
        self.discoveredTitleTemplate = discoveredTitleTemplate
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

    // Like the discovered page template, the learned API pair only counts
    // while the title-page pattern still points at the entered host, so
    // editing the link invalidates a stale discovery.
    var activeDiscoveredAPI: (apiTemplate: String, titleTemplate: String)? {
        guard !hasSearchTemplate, activeDiscoveredTemplate == nil,
              let discoveredAPITemplate, let discoveredTitleTemplate,
              let titleURL = URL(string: discoveredTitleTemplate.replacingOccurrences(
                of: #"\{r\.[A-Za-z0-9_]+\}"#, with: "q", options: .regularExpression
              )),
              titleURL.host == host
        else { return nil }
        return (discoveredAPITemplate, discoveredTitleTemplate)
    }

    // True when queries open a search results URL on the site itself.
    var searchesDirectly: Bool {
        hasSearchTemplate || activeDiscoveredTemplate != nil
    }

    // encodedQuery must already be percent-encoded. Nil when the site has no
    // known results-page URL; callers then search through the learned API or
    // fall back to the homepage.
    func searchURL(encodedQuery: String) -> URL? {
        guard host != nil else { return nil }
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
        return nil
    }
}
