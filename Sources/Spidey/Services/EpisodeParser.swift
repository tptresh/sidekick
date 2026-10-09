import Foundation

// Works out "which show, which season, which episode" from a streaming site's
// browser tab (its title and its URL), and reads the same thing back out of
// what the user types ("the pitt s1e6", "the pitt season 1 episode 6").
//
// Every site writes this differently, so the patterns are ordered most
// specific first and the show name is whatever text sits beside the numbers
// once the site's own branding is trimmed off. Pure string work, so the
// guesses are covered by tests against real tab titles.
enum EpisodeParser {
    struct Episode: Equatable {
        var show: String
        var season: Int?
        // 0 for a movie, which has no episodes to count.
        var episode: Int

        var isMovie: Bool { episode == 0 }
    }

    // MARK: - Entry points

    // A browser tab. The title carries the readable show name, the URL is
    // the more reliable source of the numbers, so both are read and merged.
    static func parse(title: String, url: String) -> Episode? {
        let found = [parseTitle(title), parseURL(url)].compactMap { $0 }
        guard let primary = found.first else { return nil }
        // Players often carry the numbers in the URL and nothing but the show
        // name in the tab title, so that title is the last fallback.
        let show = found.first(where: { $0.show.count >= 2 })?.show
            ?? cleanShowName(collapse(title).components(separatedBy: "|").first ?? "")
        guard show.count >= 2 else { return nil }
        return Episode(
            show: show,
            season: primary.season ?? found.compactMap(\.season).first,
            episode: primary.episode
        )
    }

    // A movie page has no numbers to find, so it is only recognised when the
    // site files it under a movie path ("/movie/52128-the-amazing-spider-man").
    static func parseMovie(title: String, url: String) -> Episode? {
        let path = pathAndQuery(of: url.removingPercentEncoding ?? url)
        let segments = path.split(whereSeparator: { "/?#&".contains($0) }).map(String.init)
        guard let index = segments.firstIndex(where: { movieSegments.contains($0.lowercased()) })
        else { return nil }
        // Sites lead the slug with their database id: "52128-watch-...".
        let slug = segments.dropFirst(index + 1).first { $0.contains(where: \.isLetter) }?
            .replacingOccurrences(of: "^\\d+[-_]", with: "", options: .regularExpression)
        let name = movieNameBeforeYear(in: title)
            ?? slug.map(deslug)
            ?? cleanShowName(collapse(title).components(separatedBy: "|").first ?? "", preferFirstPiece: true)
        guard name.count >= 2 else { return nil }
        return Episode(show: name, season: nil, episode: 0)
    }

    private static let movieSegments: Set<String> = ["movie", "movies", "film", "films", "watch-movie"]

    // Movie tabs read "Stream The Amazing Spider-Man (2012) Online Free...",
    // so the text before the year is the cleanest name, hyphens and all.
    private static func movieNameBeforeYear(in title: String) -> String? {
        let text = collapse(title)
        guard let year = text.range(of: "\\((?:19|20)\\d{2}\\)", options: .regularExpression)
        else { return nil }
        let before = String(text[text.startIndex..<year.lowerBound])
        let piece = before.components(separatedBy: "|").last ?? before
        let name = cleanShowName(piece)
        return name.count >= 2 ? name : nil
    }

    // What the user typed after the keyword: "the pitt s1e6".
    static func parseTyped(_ text: String) -> Episode? {
        parseTitle(text)
    }

    static func parseTitle(_ raw: String) -> Episode? {
        let title = collapse(raw)
        guard !title.isEmpty else { return nil }
        // Sites brand the tab as "Show S1E6 | SiteName", so read the part
        // that actually holds the numbers.
        let segments = title.components(separatedBy: "|")
        let segment = segments.first(where: { find(titleMarkers, in: $0) != nil }) ?? title
        guard let found = find(titleMarkers, in: segment) else { return nil }
        let before = cleanShowName(String(segment[segment.startIndex..<found.range.lowerBound]))
        // Titles that lead with the numbers ("Episode 6 - The Pitt - Season 1")
        // put the name in the first piece after them, not all of it.
        let after = cleanShowName(
            String(segment[found.range.upperBound...]), preferFirstPiece: true
        )
        return Episode(
            show: before.isEmpty ? after : before,
            season: found.season ?? standaloneSeason(in: segment),
            episode: found.episode
        )
    }

    static func parseURL(_ raw: String) -> Episode? {
        let url = raw.removingPercentEncoding ?? raw
        guard let found = find(urlMarkers, in: url) else { return nil }
        return Episode(
            show: showSlug(in: url, before: found.range.lowerBound),
            // Only the path, so a host like s3.example.com is never read as a
            // season.
            season: found.season ?? standaloneSeason(in: pathAndQuery(of: url)),
            episode: found.episode
        )
    }

    private static func pathAndQuery(of url: String) -> String {
        guard let scheme = url.range(of: "://") else { return url }
        let afterScheme = url[scheme.upperBound...]
        return afterScheme.firstIndex(of: "/").map { String(afterScheme[$0...]) } ?? ""
    }

    // The same page one episode on, when the URL spells the episode out.
    // Nil for sites whose player hides the number behind an opaque id.
    static func advancedURL(_ raw: String, toEpisode number: Int) -> String? {
        guard number > 0, let found = find(urlMarkers, in: raw) else { return nil }
        let original = String(raw[found.episodeRange])
        // Keep the site's zero padding: 06 becomes 07, not 7.
        let replacement = original.count > 1 && original.hasPrefix("0")
            ? String(format: "%0\(original.count)d", number)
            : String(number)
        return raw.replacingCharacters(in: found.episodeRange, with: replacement)
    }

    // MARK: - Patterns

    private struct Marker {
        let regex: NSRegularExpression
        let seasonGroup: Int    // 0 when the pattern names no season
        let episodeGroup: Int
    }

    private struct Found {
        let range: Range<String.Index>
        let episodeRange: Range<String.Index>
        let season: Int?
        let episode: Int
    }

    private static func marker(_ pattern: String, season: Int, episode: Int) -> Marker? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        else { return nil }
        return Marker(regex: regex, seasonGroup: season, episodeGroup: episode)
    }

    // Compiled once. Most specific first: "S01E06" and "season 1 episode 6"
    // before "1x06", with a bare "episode 6" last so it only wins when
    // nothing named a season.
    private static let titleMarkers: [Marker] = [
        marker(
            "(?<![a-z0-9])s(?:eason)?\\s*(\\d{1,2})\\s*[.,:_x\\s-]?\\s*e(?:p(?:isode)?)?\\s*(\\d{1,4})(?![0-9])",
            season: 1, episode: 2
        ),
        marker("(?<![a-z0-9.])(\\d{1,2})\\s*x\\s*(\\d{1,3})(?![0-9])", season: 1, episode: 2),
        marker("(?<![a-z0-9])(?:episode|ep)\\.?\\s*(\\d{1,4})(?![0-9])", season: 0, episode: 1),
    ].compactMap { $0 }

    private static let urlMarkers: [Marker] = [
        marker(
            "season[-_/]?(\\d{1,2})[-_/]{1,3}(?:episode|ep|e)[-_/]?(\\d{1,4})(?![0-9])",
            season: 1, episode: 2
        ),
        marker("[-_/.]s(\\d{1,2})[-_/.]?e(\\d{1,3})(?![0-9])", season: 1, episode: 2),
        marker("[?&](?:season|s)=(\\d{1,2})&(?:episode|ep|e)=(\\d{1,3})(?![0-9])", season: 1, episode: 2),
        marker("/(\\d{1,2})/(\\d{1,4})/?(?:[?#].*)?$", season: 1, episode: 2),
        marker("(?:episode|ep)[-_/]?(\\d{1,4})(?![0-9])", season: 0, episode: 1),
        marker("[?&](?:episode|ep|e)=(\\d{1,4})(?![0-9])", season: 0, episode: 1),
    ].compactMap { $0 }

    // Only consulted once an episode number has been found, so a stray "s2"
    // somewhere in a tab title cannot invent a season on its own.
    private static let seasonOnly = try? NSRegularExpression(
        pattern: "(?<![a-z0-9])s(?:eason)?[-_/=\\s]*(\\d{1,2})(?![0-9])", options: [.caseInsensitive]
    )

    private static func find(_ markers: [Marker], in text: String) -> Found? {
        let whole = NSRange(text.startIndex..., in: text)
        for marker in markers {
            guard let match = marker.regex.firstMatch(in: text, options: [], range: whole),
                  let range = Range(match.range, in: text),
                  let episodeRange = Range(match.range(at: marker.episodeGroup), in: text),
                  let episode = Int(text[episodeRange]), episode > 0
            else { continue }
            var season: Int?
            if marker.seasonGroup > 0,
               let seasonRange = Range(match.range(at: marker.seasonGroup), in: text) {
                season = Int(text[seasonRange])
            }
            return Found(range: range, episodeRange: episodeRange, season: season, episode: episode)
        }
        return nil
    }

    private static func standaloneSeason(in text: String) -> Int? {
        guard let seasonOnly else { return nil }
        let whole = NSRange(text.startIndex..., in: text)
        guard let match = seasonOnly.firstMatch(in: text, options: [], range: whole),
              let range = Range(match.range(at: 1), in: text),
              let season = Int(text[range]), season > 0
        else { return nil }
        return season
    }

    // MARK: - Names

    // Deliberately short lists: stripping too eagerly would eat real titles
    // like "New Girl" or "Free Guy".
    private static let leadingNoise: Set<String> = [
        "watch", "watching", "stream", "streaming", "nonton",
    ]
    private static let trailingNoise: Set<String> = [
        "online", "free", "hd", "watch", "stream", "streaming",
        "sub", "subs", "subbed", "dub", "dubbed", "eng", "english",
    ]
    private static let slugNoise: Set<String> = [
        "watch", "watching", "tv", "series", "show", "shows", "movie", "movies",
        "video", "videos", "stream", "streaming", "online", "free", "full", "hd",
        "play", "player", "episode", "episodes", "season", "seasons", "anime",
        "drama", "title", "titles", "view", "home",
    ]
    // The long dash is added by code point (0x2014) because the repo bans
    // the character, and its escape, from source files.
    private static let edgePunctuation: CharacterSet = {
        var set = CharacterSet(charactersIn: " \t-:|,.;/\u{00B7}\u{2013}")
        set.insert(Unicode.Scalar(0x2014)!)
        return set
    }()

    // Words that describe where you are in a show rather than name it, so a
    // piece made only of these is the site's furniture, not the title.
    private static let structuralWords: Set<String> = leadingNoise.union(trailingNoise).union([
        "season", "seasons", "episode", "episodes", "ep", "eps", "part",
        "series", "full", "complete", "tv", "show", "now", "new",
    ])

    static func cleanShowName(_ raw: String, preferFirstPiece: Bool = false) -> String {
        // "(2025)" and other bracketed asides belong to the site, not the show.
        let stripped = collapse(raw)
            .replacingOccurrences(
                of: "\\((?:19|20)\\d{2}\\)", with: " ", options: [.regularExpression]
            )
        // Sites hang extra pieces off the name with dashes: "The Pitt -
        // Season 1", "HydraHD - The Pitt". Drop the pieces that only carry
        // furniture and keep the rest in order.
        let pieces = stripped
            .replacingOccurrences(of: " \u{2013} ", with: " - ")
            .components(separatedBy: " - ")
            .map { trimNoiseWords($0) }
            .filter { !$0.isEmpty && !isStructural($0) }
        guard let first = pieces.first else { return "" }
        return preferFirstPiece ? first : pieces.joined(separator: " - ")
    }

    private static func trimNoiseWords(_ raw: String) -> String {
        var words = collapse(raw).split(separator: " ").map(String.init)
        func bare(_ word: String) -> String {
            word.trimmingCharacters(in: edgePunctuation).lowercased()
        }
        while let first = words.first, bare(first).isEmpty || leadingNoise.contains(bare(first)) {
            words.removeFirst()
        }
        while let last = words.last, bare(last).isEmpty || trailingNoise.contains(bare(last)) {
            words.removeLast()
        }
        return words.joined(separator: " ").trimmingCharacters(in: edgePunctuation)
    }

    private static func isStructural(_ piece: String) -> Bool {
        let words = piece.split(separator: " ").map {
            $0.trimmingCharacters(in: edgePunctuation).lowercased()
        }
        guard !words.isEmpty else { return true }
        return words.allSatisfy { $0.isEmpty || structuralWords.contains($0) || Int($0) != nil }
    }

    // The path segment sitting in front of the numbers, e.g. "the-pitt" in
    // /watch-tv/the-pitt/1/6. The host is skipped so a site name can never
    // become the show name.
    private static func showSlug(in url: String, before index: String.Index) -> String {
        var path = pathAndQuery(of: String(url[url.startIndex..<index]))
        // Query parameters name ids and player settings, never the show.
        if let query = path.firstIndex(where: { $0 == "?" || $0 == "#" }) {
            path = String(path[path.startIndex..<query])
        }
        let segments = path.split(separator: "/").map(String.init)
        guard let slug = segments.last(where: { $0.contains(where: \.isLetter) }) else { return "" }
        return deslug(slug)
    }

    static func deslug(_ slug: String) -> String {
        let words = slug
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: "+", with: "-")
            .split(separator: "-")
            .map(String.init)
            .filter { word in
                if slugNoise.contains(word.lowercased()) { return false }
                // Years and database ids, not part of the name. Short numbers
                // stay so "the-100" survives.
                if word.allSatisfy(\.isNumber), word.count >= 4 { return false }
                return !word.isEmpty
            }
        guard !words.isEmpty else { return "" }
        return words
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    // "the pitt" typed in lower case reads better saved as "The Pitt". Words
    // carrying capitals of their own (iCarly, BoJack) are left alone.
    static func titleCased(_ text: String) -> String {
        collapse(text)
            .split(separator: " ")
            .map { word in
                word.contains(where: \.isUppercase)
                    ? String(word)
                    : word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }

    static func collapse(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: [.regularExpression])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
