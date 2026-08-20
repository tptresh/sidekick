import Foundation

// Works out a plain custom link's real search URL so queries land on the
// site's own search page instead of a site-scoped Google search.
// Classic sites expose an HTML search form we can parse; single-page apps
// ship no form markup, so for those we look for a /search route mentioned
// in the page or in the site's sitemap.
enum SearchTemplateFinder {

    static func discover(
        homepage: URL, session: URLSession, completion: @escaping (String?) -> Void
    ) {
        fetch(homepage, session: session) { html in
            if let html {
                // A schema.org SearchAction is the site's own declaration of
                // its search URL, so it beats every heuristic.
                if let template = searchActionTemplate(fromHTML: html, baseURL: homepage) {
                    completion(template)
                    return
                }
                if let template = template(fromHTML: html, baseURL: homepage) {
                    completion(template)
                    return
                }
                if mentionsSearchRoute(html) {
                    completion(searchPathTemplate(for: homepage))
                    return
                }
            }
            let sitemap = homepage.appendingPathComponent("sitemap.xml")
            fetch(sitemap, session: session) { xml in
                if let xml, mentionsSearchRoute(xml) {
                    completion(searchPathTemplate(for: homepage))
                } else {
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Pure helpers (unit tested)

    // schema.org SearchAction markup spells out the search URL directly:
    // "urlTemplate": "https://site/search?query={search_term_string}".
    // The JSON-LD often ships escaped inside framework payloads, so the
    // surrounding chunk is unescaped before the URL is pulled out.
    static func searchActionTemplate(fromHTML html: String, baseURL: URL) -> String? {
        let placeholder = "{search_term_string}"
        var searchStart = html.startIndex
        while let found = html.range(of: placeholder, range: searchStart..<html.endIndex) {
            let chunkStart = html.index(
                found.lowerBound, offsetBy: -400, limitedBy: html.startIndex
            ) ?? html.startIndex
            let chunkEnd = html.index(
                found.upperBound, offsetBy: 100, limitedBy: html.endIndex
            ) ?? html.endIndex
            let chunk = String(html[chunkStart..<chunkEnd]).replacingOccurrences(of: "\\", with: "")
            if let template = searchTarget(in: chunk, placeholder: placeholder, baseURL: baseURL) {
                return template
            }
            searchStart = found.upperBound
        }
        return nil
    }

    // Expand outwards from the placeholder over URL characters to recover the
    // full target, then normalise it into a {query} template.
    private static func searchTarget(
        in text: String, placeholder: String, baseURL: URL
    ) -> String? {
        guard let placeholderRange = text.range(of: placeholder) else { return nil }
        let urlChars = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
            + "-._~:/?#[]@!$&()*+,;=%{}"
        )
        func isURLChar(_ character: Character) -> Bool {
            character.unicodeScalars.count == 1 && urlChars.contains(character.unicodeScalars[
                character.unicodeScalars.startIndex
            ])
        }
        var start = placeholderRange.lowerBound
        while start > text.startIndex, isURLChar(text[text.index(before: start)]) {
            start = text.index(before: start)
        }
        var end = placeholderRange.upperBound
        while end < text.endIndex, isURLChar(text[end]) {
            end = text.index(after: end)
        }
        var candidate = String(text[start..<end])
            .replacingOccurrences(of: placeholder, with: CustomMediaSite.queryPlaceholder)
        // Some sites emit "https://host//search"; collapse the doubled slash.
        if let schemeRange = candidate.range(of: "://") {
            candidate = candidate[..<schemeRange.upperBound]
                + candidate[schemeRange.upperBound...].replacingOccurrences(of: "//", with: "/")
        }
        if candidate.lowercased().hasPrefix("http") { return candidate }
        if candidate.hasPrefix("/"), let host = baseURL.host {
            return "https://\(host)\(candidate)"
        }
        return nil
    }

    // Parse the first GET form that has a search-style text input, e.g.
    // WordPress's <form action="/"><input name="s"></form> becomes
    // "https://host/?s={query}". Hidden inputs keep their fixed values.
    static func template(fromHTML html: String, baseURL: URL) -> String? {
        let formPattern = "<form\\b([^>]*)>(.*?)</form>"
        guard let formRegex = try? NSRegularExpression(
            pattern: formPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        for match in formRegex.matches(in: html, range: range) {
            guard let attrsRange = Range(match.range(at: 1), in: html),
                  let bodyRange = Range(match.range(at: 2), in: html) else { continue }
            let attrs = String(html[attrsRange])
            let body = String(html[bodyRange])

            if let method = attribute("method", in: attrs),
               method.lowercased() != "get" { continue }

            var queryName: String?
            var fixedParams: [(String, String)] = []
            for input in matches("<input\\b[^>]*>", in: body) {
                guard let name = attribute("name", in: input) else { continue }
                let type = attribute("type", in: input)?.lowercased() ?? "text"
                if type == "hidden" {
                    fixedParams.append((name, attribute("value", in: input) ?? ""))
                } else if queryName == nil, ["text", "search"].contains(type),
                          searchyNames.contains(name.lowercased()) {
                    queryName = name
                }
            }
            guard let queryName else { continue }

            let action = attribute("action", in: attrs) ?? ""
            guard let actionURL = action.isEmpty
                ? baseURL
                : URL(string: action, relativeTo: baseURL)?.absoluteURL
            else { continue }
            var params = fixedParams.map { "\($0.0)=\($0.1)" }
            params.append("\(queryName)=\(CustomMediaSite.queryPlaceholder)")
            let separator = actionURL.absoluteString.contains("?") ? "&" : "?"
            return actionURL.absoluteString + separator + params.joined(separator: "&")
        }
        return nil
    }

    // True when the text references a /search route ("/search" not followed
    // by more word characters, so /searchengine does not count).
    static func mentionsSearchRoute(_ text: String) -> Bool {
        var start = text.startIndex
        while let found = text.range(of: "/search", range: start..<text.endIndex) {
            if found.upperBound == text.endIndex { return true }
            let next = text[found.upperBound]
            if !(next.isLetter || next.isNumber || next == "_" || next == "-") { return true }
            start = found.upperBound
        }
        return false
    }

    static func searchPathTemplate(for homepage: URL) -> String? {
        guard let host = homepage.host else { return nil }
        return "https://\(host)/search?q=\(CustomMediaSite.queryPlaceholder)"
    }

    // MARK: - Internals

    private static let searchyNames = [
        "q", "s", "query", "search", "keyword", "keywords", "term", "phrase",
    ]

    private static func attribute(_ name: String, in tag: String) -> String? {
        let pattern = "\(name)\\s*=\\s*[\"']([^\"']*)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
              let valueRange = Range(match.range(at: 1), in: tag)
        else { return nil }
        return String(tag[valueRange])
    }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }

    private static func fetch(
        _ url: URL, session: URLSession, completion: @escaping (String?) -> Void
    ) {
        session.dataTask(with: url) { data, _, _ in
            guard let data else {
                completion(nil)
                return
            }
            completion(String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1))
        }.resume()
    }
}
