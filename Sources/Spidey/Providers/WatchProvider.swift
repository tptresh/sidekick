import AppKit

// "watching" is Spidey's memory of where you got to in a show: which season
// and episode, on which site, and the page that resumes it.
//
// Three ways in, so nobody has to remember to keep a list:
//  - type it: "watching the pitt s1e6"
//  - one Return on whatever episode page is open in the browser
//  - the Mac going to sleep, which saves the open episode by itself
// Getting it back out is just the show's name: "the pitt" puts a resume row
// on top of the usual "Watch ..." rows.
enum WatchProvider {
    static let keywords = ["watching", "watched", "resume", "continue"]

    // openEpisodes is injected so tests never shell out to AppleScript.
    static func results(
        for query: String, store: WatchStore = .shared,
        openEpisodes: () -> [WatchCapture.Candidate] = { WatchCapture.currentCandidates() }
    ) -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let lowered = trimmed.lowercased()
        guard let keyword = keywords.first(where: { lowered == $0 || lowered.hasPrefix($0 + " ") })
        else { return [] }
        let rest = EpisodeParser.collapse(String(trimmed.dropFirst(keyword.count)))
        // "resume" and "continue" only look things up; they never write. They
        // are also ordinary words (someone typing "resume" usually wants their
        // CV), so they answer only when they name a show that is actually
        // saved. "watching" and "watched" are explicit and always answer.
        let canSave = keyword == "watching" || keyword == "watched"
        if !canSave, rest.isEmpty || store.matches(for: rest).isEmpty { return [] }

        var items: [ResultItem] = []
        var handled: Set<String> = []

        // A season and episode in the query is an explicit save.
        if canSave, let typed = EpisodeParser.parseTyped(rest), typed.show.count >= 2 {
            handled.insert(WatchStore.normalize(typed.show))
            items.append(saveRow(typed, store: store, open: openEpisodes()))
        }

        // Whatever is playing in the browser right now, offered as one Return.
        if canSave {
            let open = openEpisodes().filter { candidate in
                let key = WatchStore.normalize(candidate.episode.show)
                guard !handled.contains(key), !WatchCapture.isAlreadySaved(candidate, store: store)
                else { return false }
                guard !rest.isEmpty else { return true }
                return (Fuzzy.score(query: rest, candidate: candidate.episode.show) ?? 0) >= 0.7
            }
            for (index, candidate) in open.prefix(4).enumerated() {
                handled.insert(WatchStore.normalize(candidate.episode.show))
                items.append(candidateRow(candidate, index: index, store: store))
            }
        }

        // What is already saved, narrowed to the show when one was named.
        let saved: [WatchEntry] = rest.isEmpty
            ? store.entries
            : store.matches(for: rest).map(\.entry)
        for (index, entry) in saved.prefix(12).enumerated() where !handled.contains(entry.key) {
            items.append(entryRow(entry, index: index, store: store))
            // The one show the query is about also gets a "next episode" row.
            if index == 0, !rest.isEmpty,
               let next = nextRow(entry, store: store, score: 950 - Double(index) * 2 - 1) {
                items.append(next)
            }
        }

        if items.isEmpty {
            items.append(emptyRow(for: rest, canSave: canSave))
        }
        return items
    }

    // A bare show name ("the pitt") puts resuming on top of the usual
    // "Watch ... on Netflix" rows. Only a near-exact name qualifies, so
    // ordinary searches are never hijacked.
    static func resumeResults(for query: String, store: WatchStore = .shared) -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let lowered = trimmed.lowercased()
        guard trimmed.count >= 3,
              !keywords.contains(where: { lowered == $0 || lowered.hasPrefix($0 + " ") }),
              let best = store.matches(for: trimmed, minimum: 0.9).first
        else { return [] }
        let score = 700 + best.score * 40
        var items = [entryRow(best.entry, index: 0, store: store, score: score, resuming: true)]
        if let next = nextRow(best.entry, store: store, score: score - 1) {
            items.append(next)
        }
        return items
    }

    // MARK: - Rows

    private static func saveRow(
        _ typed: EpisodeParser.Episode, store: WatchStore, open: [WatchCapture.Candidate]
    ) -> ResultItem {
        let existing = store.entry(forShow: typed.show)
        // If that show is open in the browser, save the real page with it, so
        // resuming later lands on the episode rather than a search.
        let candidate = open.first {
            WatchStore.normalize($0.episode.show) == WatchStore.normalize(typed.show)
        }
        // A name already spelled out by the site (or by an earlier save) beats
        // what was typed in lower case.
        let show = candidate?.episode.show ?? existing?.show ?? EpisodeParser.titleCased(typed.show)
        let position = label(season: typed.season ?? existing?.season, episode: typed.episode)
        let subtitle: String
        if let existing, existing.episode != typed.episode {
            subtitle = "Replaces \(existing.positionLabel). Type the show name any time to pick it up."
        } else {
            subtitle = "Remembers where you got to. Type the show name any time to pick it up."
        }
        return ResultItem(
            title: "Save \(show) - \(position)",
            subtitle: subtitle,
            icon: icon(for: candidate?.url ?? existing?.url),
            score: 980,
            action: {
                store.record(
                    show: show, season: typed.season, episode: typed.episode,
                    site: candidate?.site, url: candidate?.url
                )
            }
        )
    }

    private static func candidateRow(
        _ candidate: WatchCapture.Candidate, index: Int, store: WatchStore
    ) -> ResultItem {
        let episode = candidate.episode
        return ResultItem(
            title: "Save " + named(episode.show, label(season: episode.season, episode: episode.episode)),
            subtitle: "Open on \(candidate.site) in your browser right now. Return remembers it.",
            icon: icon(for: candidate.url),
            score: 970 - Double(index),
            action: { WatchCapture.save(candidate, store: store) }
        )
    }

    private static func entryRow(
        _ entry: WatchEntry, index: Int, store: WatchStore,
        score: Double? = nil, resuming: Bool = false
    ) -> ResultItem {
        let title = (resuming ? "Resume " : "") + named(entry.show, entry.positionLabel)
        let opens = entry.url == nil
            ? "Searches for it in \(BrowserLauncher.targetName)"
            : "Opens \(entry.siteLabel) in \(BrowserLauncher.targetName)"
        return ResultItem(
            title: title,
            subtitle: "\(opens), saved \(age(entry.updated)). ⌘⏎ forgets it.",
            icon: icon(for: entry.url),
            score: score ?? (950 - Double(index) * 2),
            rankingKey: "watch:\(entry.key)",
            secondaryAction: {
                store.remove(id: entry.id)
                NotificationCenter.default.post(name: .spideyFaviconLoaded, object: nil)
            },
            secondaryKeepsPanel: true,
            action: { open(entry, store: store) }
        )
    }

    // Only offered when the site's URL spells the episode number out, so the
    // guess is a real page rather than an invented one.
    private static func nextRow(_ entry: WatchEntry, store: WatchStore, score: Double) -> ResultItem? {
        guard let next = entry.nextEpisodeURL, let url = URL(string: next) else { return nil }
        return ResultItem(
            title: "Next up: \(entry.show) - \(entry.nextPositionLabel)",
            subtitle: "Opens \(entry.siteLabel) one episode on and saves it as where you are.",
            icon: icon(for: next),
            score: score,
            rankingKey: "watch:next:\(entry.key)",
            action: {
                store.record(
                    show: entry.show, season: entry.season, episode: entry.episode + 1,
                    site: entry.site, url: next
                )
                BrowserLauncher.open(url)
            }
        )
    }

    private static func emptyRow(for rest: String, canSave: Bool) -> ResultItem {
        if rest.isEmpty {
            return ResultItem(
                title: "Nothing saved yet",
                subtitle: "Type \"watching the pitt s1e6\", or open an episode or movie in Brave or Chrome and run this again",
                icon: .symbol("play.tv"),
                score: 940,
                action: {}
            )
        }
        return ResultItem(
            title: "Nothing saved for \"\(rest)\"",
            subtitle: canSave
                ? "Add the episode to save it, e.g. watching \(rest) s1e6"
                : "Save it first with watching \(rest) s1e6",
            icon: .symbol("play.tv"),
            score: 940,
            action: {}
        )
    }

    // MARK: - Helpers

    private static func open(_ entry: WatchEntry, store: WatchStore) {
        if let stored = entry.url, let url = URL(string: stored) {
            BrowserLauncher.open(url)
            // Opening it again is also the most recent thing watched.
            store.record(
                show: entry.show, season: entry.season, episode: entry.episode,
                site: entry.site, url: stored
            )
            return
        }
        let search = entry.isMovie ? entry.show : "\(entry.show) \(entry.positionLabel)"
        guard let url = URL(
            string: "https://www.google.com/search?q=\(BrowserLauncher.encodeQuery(search))"
        ) else { return }
        BrowserLauncher.open(url)
    }

    // A movie is just its name; a show carries where you are in it.
    private static func named(_ show: String, _ position: String) -> String {
        position == "Movie" ? show : "\(show) - \(position)"
    }

    private static func label(season: Int?, episode: Int) -> String {
        if episode == 0 { return "Movie" }
        guard let season else { return "Episode \(episode)" }
        return "Season \(season), Episode \(episode)"
    }

    private static func icon(for url: String?) -> ResultIcon {
        guard let url, !url.isEmpty else { return .symbol("play.tv.fill") }
        return FaviconStore.shared.resultIcon(for: url, fallbackSymbol: "play.tv.fill")
    }

    private static func age(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
