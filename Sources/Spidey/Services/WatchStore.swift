import Foundation

// Where you got to in a show: "The Pitt, season 1 episode 6, on hydrahd.sx",
// with the exact page so one Return picks it straight back up. One entry per
// show, newest first, kept in
// ~/Library/Application Support/Spidey/watching.json.
struct WatchEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var show: String
    var season: Int?
    var episode: Int
    // Host the episode was watched on, e.g. "hydrahd.sx". Nil when the entry
    // was typed in rather than picked up from a tab.
    var site: String?
    var url: String?
    var updated: Date

    var key: String { WatchStore.normalize(show) }

    // "Season 1, Episode 6" - spelled out for result rows.
    var positionLabel: String {
        guard let season else { return "Episode \(episode)" }
        return "Season \(season), Episode \(episode)"
    }

    var nextPositionLabel: String {
        guard let season else { return "Episode \(episode + 1)" }
        return "Season \(season), Episode \(episode + 1)"
    }

    // The same page one episode on, when the site's URL spells the number out.
    var nextEpisodeURL: String? {
        url.flatMap { EpisodeParser.advancedURL($0, toEpisode: episode + 1) }
    }

    var siteLabel: String { site ?? "no site saved" }

    // Entries written before the newer fields existed decode with defaults.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        show = try container.decode(String.self, forKey: .show)
        season = try container.decodeIfPresent(Int.self, forKey: .season)
        episode = try container.decode(Int.self, forKey: .episode)
        site = try container.decodeIfPresent(String.self, forKey: .site)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        updated = try container.decodeIfPresent(Date.self, forKey: .updated) ?? Date()
    }

    init(
        id: UUID = UUID(), show: String, season: Int?, episode: Int,
        site: String? = nil, url: String? = nil, updated: Date = Date()
    ) {
        self.id = id
        self.show = show
        self.season = season
        self.episode = episode
        self.site = site
        self.url = url
        self.updated = updated
    }
}

final class WatchStore {
    static let shared = WatchStore()
    // Enough to cover everything on the go without the file growing forever;
    // the least recently watched entry falls off the end.
    static let maxEntries = 50

    private let fileURL: URL
    // nil until first access; the file is only read when a query needs it.
    private var cached: [WatchEntry]?

    // Tests inject a temp directory so they never touch the real store.
    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Spidey", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("watching.json")
    }

    // Newest first, which is also the order the list is shown in.
    var entries: [WatchEntry] {
        if let cached { return cached }
        let loaded = (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONDecoder().decode([WatchEntry].self, from: $0) } ?? []
        let sorted = loaded.sorted { $0.updated > $1.updated }
        cached = sorted
        return sorted
    }

    // One entry per show: watching a new episode moves the same show forward
    // rather than piling up. The newest save wins the spelling of the name,
    // so a tidy typed name replaces a slug picked out of a URL.
    @discardableResult
    func record(
        show: String, season: Int?, episode: Int, site: String? = nil, url: String? = nil,
        at date: Date = Date()
    ) -> WatchEntry? {
        let name = EpisodeParser.collapse(show)
        guard name.count >= 2, episode > 0 else { return nil }
        let key = Self.normalize(name)
        var all = entries
        let existing = all.first { $0.key == key }
        all.removeAll { $0.key == key }
        let entry = WatchEntry(
            id: existing?.id ?? UUID(),
            show: name,
            season: season ?? existing?.season,
            episode: episode,
            site: site ?? existing?.site,
            url: url ?? existing?.url,
            updated: date
        )
        all.insert(entry, at: 0)
        cached = Array(all.prefix(Self.maxEntries))
        save()
        return entry
    }

    func remove(id: UUID) {
        var all = entries
        all.removeAll { $0.id == id }
        cached = all
        save()
    }

    func entry(forShow show: String) -> WatchEntry? {
        let key = Self.normalize(show)
        return entries.first { $0.key == key }
    }

    // Shows whose name matches what was typed, best match first.
    func matches(for query: String, minimum: Double = 0.7) -> [(entry: WatchEntry, score: Double)] {
        let typed = EpisodeParser.collapse(query)
        guard typed.count >= 2 else { return [] }
        return entries
            .compactMap { entry -> (entry: WatchEntry, score: Double)? in
                let direct = Fuzzy.score(query: typed, candidate: entry.show) ?? 0
                // Also match the name with "the" and punctuation taken off,
                // so "pitt" finds "The Pitt".
                let bare = Fuzzy.score(
                    query: Self.normalize(typed), candidate: Self.normalize(entry.show)
                ) ?? 0
                let score = max(direct, bare)
                return score >= minimum ? (entry, score) : nil
            }
            .sorted { $0.score > $1.score }
    }

    // "The Pitt (2025)" and "the-pitt" are the same show.
    static func normalize(_ show: String) -> String {
        let folded = show.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let letters = String(folded.map { $0.isLetter || $0.isNumber ? $0 : " " })
        var words = letters.split(separator: " ").map(String.init)
        if words.count > 1, words.first == "the" { words.removeFirst() }
        // A release year tacked on the end is the site's, not the show's.
        if words.count > 1, let last = words.last, last.count == 4, Int(last) != nil,
           last.hasPrefix("19") || last.hasPrefix("20") {
            words.removeLast()
        }
        return words.joined(separator: " ")
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(cached ?? []) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
