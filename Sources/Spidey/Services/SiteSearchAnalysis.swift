import Foundation

// Pure logic behind InteractiveSearchProber: turning observed requests, JSON
// payloads, and links into reusable search and title-page templates.
enum SiteSearchAnalysis {

    // Typing moved the page to a URL containing the query: that URL is a
    // search results page and becomes an ordinary search template.
    static func pageTemplate(finalURL: String, homepage: URL, probeQuery: String) -> String? {
        guard !finalURL.isEmpty, containsQuery(finalURL, probeQuery) else { return nil }
        guard let host = URL(string: finalURL)?.host, host == homepage.host else { return nil }
        return replacingQuery(in: finalURL, query: probeQuery)
    }

    // Requests whose URL carries the typed query are the site's search
    // endpoints. Asset fetches are noise; the site's own endpoints come
    // before third-party ones (they outlive any embedded API keys).
    static func apiTemplates(recordedURLs: [String], probeQuery: String, host: String) -> [String] {
        let assetMarkers = ["/_next/image", ".js", ".css", ".png", ".jpg", ".jpeg", ".svg",
                            ".ico", ".woff", ".webp", ".gif", ".mp4"]
        var seen = Set<String>()
        let hits = recordedURLs.filter { url in
            containsQuery(url, probeQuery)
                && !assetMarkers.contains(where: { url.lowercased().contains($0) })
                && seen.insert(replacingQuery(in: url, query: probeQuery)).inserted
        }
        let templates = hits.map { replacingQuery(in: $0, query: probeQuery) }
        return templates.sorted { a, b in
            let aOwn = URL(string: a.replacingOccurrences(
                of: CustomMediaSite.queryPlaceholder, with: "q"))?.host == host
            let bOwn = URL(string: b.replacingOccurrences(
                of: CustomMediaSite.queryPlaceholder, with: "q"))?.host == host
            if aOwn != bOwn { return aOwn }
            return templates.firstIndex(of: a)! < templates.firstIndex(of: b)!
        }
    }

    // The direct route: many search APIs hand back each result's page URL as
    // a field (nepu.to's /ajax/posts returns "url": "https://nepu.to/movie/
    // interstellar-2014-173049"). A same-site URL field on the top result is
    // the title link, no pattern inference needed.
    static func urlFieldTitleTemplate(searchBody: String, host: String) -> String? {
        guard let first = firstResultsArray(inJSON: searchBody)?.first else { return nil }
        for key in first.keys.sorted() {
            guard let value = first[key] as? String, let url = URL(string: value),
                  url.host == host, url.path.count > 1 else { continue }
            return "{r.\(key)}"
        }
        return nil
    }

    // Learn how the site links to a title page by correlating the JSON it
    // fetched with the links it rendered: a link like /watch/movie/1288445
    // whose segments match one JSON object's fields ({id: 1288445,
    // media_type: "movie"}) yields the pattern /watch/{r.media_type}/{r.id}.
    // The same pattern must fit at least two different links, so a
    // coincidental match cannot invent one.
    static func titleTemplate(jsonBodies: [String], routes: [String], host: String) -> String? {
        var objects: [[String: Any]] = []
        for body in jsonBodies {
            guard let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            collectObjects(in: json, into: &objects)
        }
        guard !objects.isEmpty else { return nil }

        var routesByTemplate: [String: Set<String>] = [:]
        for route in Set(routes) {
            guard let components = URLComponents(string: route),
                  components.host == nil || components.host == host else { continue }
            let segments = components.path.split(separator: "/").map(String.init)
            guard segments.count >= 2 else { continue }

            var best: (template: String, placeholders: Int)?
            for object in objects {
                var usedKeys = Set<String>()
                var placeholders = 0
                let rebuilt = segments.map { segment -> String in
                    let match = object.keys.sorted().first { key in
                        guard !usedKeys.contains(key), let value = stringValue(object[key]!),
                              value.count >= 2 else { return false }
                        return value.caseInsensitiveCompare(segment) == .orderedSame
                    }
                    guard let match else { return segment }
                    usedKeys.insert(match)
                    placeholders += 1
                    return "{r.\(match)}"
                }
                if placeholders > (best?.placeholders ?? 0) {
                    best = ("https://\(host)/" + rebuilt.joined(separator: "/"), placeholders)
                }
            }
            if let best {
                routesByTemplate[best.template, default: []].insert(components.path)
            }
        }
        return routesByTemplate
            .filter { $0.value.count >= 2 }
            .max { a, b in
                (a.value.count, b.key.count) < (b.value.count, a.key.count)
            }?
            .key
    }

    // Fill a learned title template from one search result object.
    static func fill(titleTemplate: String, result: [String: Any]) -> String? {
        // A template that is one bare placeholder names a URL field; its
        // value is already the finished link.
        if titleTemplate.range(
            of: #"^\{r\.[A-Za-z0-9_]+\}$"#, options: .regularExpression
        ) != nil {
            let key = String(titleTemplate.dropFirst(3).dropLast(1))
            return result[key] as? String
        }
        var filled = titleTemplate
        while let range = filled.range(of: #"\{r\.[A-Za-z0-9_]+\}"#, options: .regularExpression) {
            let key = String(filled[range].dropFirst(3).dropLast(1))
            guard let raw = result[key], let value = stringValue(raw),
                  let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            else { return nil }
            filled.replaceSubrange(range, with: encoded)
        }
        return filled
    }

    // The first non-empty array of objects in a JSON payload is taken as the
    // results list, wherever the site nests it.
    static func firstResultsArray(inJSON text: String) -> [[String: Any]]? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return firstObjectArray(in: json)
    }

    // True for any well-formed JSON payload - the shape a search API answers
    // with, and never the shape of an anti-bot interstitial page.
    static func isJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    static func resultsText(_ results: [[String: Any]]) -> String {
        results.flatMap { object in
            object.keys.sorted().compactMap { stringValue(object[$0]!) }
        }.joined(separator: " ")
    }

    // MARK: - Internals

    private static func containsQuery(_ url: String, _ query: String) -> Bool {
        url.range(of: query, options: .caseInsensitive) != nil
            || url.range(of: BrowserLauncher.encodeQuery(query), options: .caseInsensitive) != nil
    }

    private static func replacingQuery(in url: String, query: String) -> String {
        var result = url
        for needle in [BrowserLauncher.encodeQuery(query), query] {
            while let range = result.range(of: needle, options: .caseInsensitive) {
                result.replaceSubrange(range, with: CustomMediaSite.queryPlaceholder)
            }
        }
        return result
    }

    private static func firstObjectArray(in json: Any) -> [[String: Any]]? {
        if let array = json as? [Any] {
            if let objects = array as? [[String: Any]], !objects.isEmpty { return objects }
            for element in array {
                if let found = firstObjectArray(in: element) { return found }
            }
        }
        if let object = json as? [String: Any] {
            for key in object.keys.sorted() {
                if let found = firstObjectArray(in: object[key]!) { return found }
            }
        }
        return nil
    }

    private static func collectObjects(in json: Any, into objects: inout [[String: Any]]) {
        guard objects.count < 600 else { return }
        if let array = json as? [Any] {
            for element in array { collectObjects(in: element, into: &objects) }
        } else if let object = json as? [String: Any] {
            objects.append(object)
            for key in object.keys.sorted() { collectObjects(in: object[key]!, into: &objects) }
        }
    }

    private static func stringValue(_ value: Any) -> String? {
        if let string = value as? String {
            return string.isEmpty ? nil : string
        }
        if let number = value as? NSNumber {
            // Booleans bridge to NSNumber too; "1"/"0" would match nothing useful.
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
            let double = number.doubleValue
            if double == double.rounded(), abs(double) < 1e15 {
                return String(number.int64Value)
            }
            return number.stringValue
        }
        return nil
    }
}

// Opens the best destination for a query on a site whose search only exists
// as an internal API: ask the API, jump straight to the top matching title's
// page, and fall back to the homepage when nothing matches.
enum SiteSearchOpener {
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    static func openTopMatch(
        apiTemplate: String, titleTemplate: String, query: String, homepage: URL?
    ) {
        let openHomepage = {
            DispatchQueue.main.async {
                if let homepage { BrowserLauncher.open(homepage) }
            }
        }
        guard let url = URL(string: apiTemplate.replacingOccurrences(
            of: CustomMediaSite.queryPlaceholder, with: BrowserLauncher.encodeQuery(query)
        )) else {
            openHomepage()
            return
        }
        let openFromBody = { (text: String?) -> Bool in
            guard let text,
                  let top = SiteSearchAnalysis.firstResultsArray(inJSON: text)?.first,
                  let filled = SiteSearchAnalysis.fill(titleTemplate: titleTemplate, result: top),
                  let titleURL = URL(string: filled)
            else { return false }
            DispatchQueue.main.async { BrowserLauncher.open(titleURL) }
            return true
        }
        // Fast path first; sites behind an anti-bot wall answer a plain
        // request with a challenge page instead of JSON, and for those the
        // hidden web view (which holds the clearance cookies) asks again.
        fetchJSONText(url: url) { text in
            if !openFromBody(text) { openHomepage() }
        }
    }

    // Prove a learned search API still works: the probe film must come back
    // in a results list, the nonsense query must not.
    static func verify(apiTemplate: String, completion: @escaping (Bool) -> Void) {
        let filled = { (query: String) in
            URL(string: apiTemplate.replacingOccurrences(
                of: CustomMediaSite.queryPlaceholder, with: BrowserLauncher.encodeQuery(query)
            ))
        }
        guard let probeURL = filled(InteractiveSearchProber.probeTitle),
              let controlURL = filled(InteractiveSearchProber.controlQuery) else {
            completion(false)
            return
        }
        fetchJSONText(url: probeURL) { probeText in
            guard let probeText,
                  let probe = SiteSearchAnalysis.firstResultsArray(inJSON: probeText),
                  SiteSearchAnalysis.resultsText(probe)
                      .localizedCaseInsensitiveContains(InteractiveSearchProber.probeTitle)
            else {
                completion(false)
                return
            }
            fetchJSONText(url: controlURL) { controlText in
                let control = controlText.flatMap(SiteSearchAnalysis.firstResultsArray) ?? []
                let text = SiteSearchAnalysis.resultsText(control)
                completion(
                    !text.localizedCaseInsensitiveContains(InteractiveSearchProber.probeTitle)
                        && text != SiteSearchAnalysis.resultsText(probe)
                )
            }
        }
    }

    // Plain request first, hidden web view second (for anti-bot walls).
    // Completion arrives on the main thread.
    private static func fetchJSONText(url: URL, completion: @escaping (String?) -> Void) {
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let text = data.flatMap({ String(data: $0, encoding: .utf8) }),
               SiteSearchAnalysis.isJSON(text) {
                DispatchQueue.main.async { completion(text) }
                return
            }
            DispatchQueue.main.async {
                WebViewFetcher.shared.fetchText(url: url, completion: completion)
            }
        }.resume()
    }
}
