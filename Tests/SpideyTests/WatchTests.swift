import XCTest
@testable import Spidey

final class EpisodeParserTests: XCTestCase {
    func testSeasonAndEpisodeSpelledOutInTitle() {
        let episode = EpisodeParser.parse(
            title: "Watch The Pitt Season 1 Episode 6 Online Free | HydraHD",
            url: "https://hydrahd.sx/watch-tv/the-pitt/1/6"
        )
        XCTAssertEqual(episode, EpisodeParser.Episode(show: "The Pitt", season: 1, episode: 6))
    }

    func testShortFormInTitle() {
        let episode = EpisodeParser.parse(
            title: "The Pitt - S01E06 - Watch Online",
            url: "https://example.to/the-pitt-season-1-episode-6"
        )
        XCTAssertEqual(episode, EpisodeParser.Episode(show: "The Pitt", season: 1, episode: 6))
    }

    func testCrossFormInTitle() {
        let episode = EpisodeParser.parse(
            title: "The Pitt 1x06 | FreeStream",
            url: "https://example.com/play/9931"
        )
        XCTAssertEqual(episode, EpisodeParser.Episode(show: "The Pitt", season: 1, episode: 6))
    }

    func testTitleLeadingWithTheEpisodeNumber() {
        let episode = EpisodeParser.parse(
            title: "Episode 6 - The Pitt - Season 1 | FlickyStream",
            url: "https://flicky.example/play/9931"
        )
        XCTAssertEqual(episode, EpisodeParser.Episode(show: "The Pitt", season: 1, episode: 6))
    }

    func testShowNameFallsBackToTheURLSlug() {
        let episode = EpisodeParser.parse(
            title: "FlickyStream",
            url: "https://flicky.example/watch/the-pitt/season-1/episode-6"
        )
        XCTAssertEqual(episode, EpisodeParser.Episode(show: "The Pitt", season: 1, episode: 6))
    }

    func testQueryStringSeasonAndEpisode() {
        let episode = EpisodeParser.parse(
            title: "The Pitt",
            url: "https://example.com/player?id=814&s=2&e=3"
        )
        XCTAssertEqual(episode, EpisodeParser.Episode(show: "The Pitt", season: 2, episode: 3))
    }

    func testEpisodeWithoutASeason() {
        let episode = EpisodeParser.parse(
            title: "One Piece Episode 1089 English Subbed",
            url: "https://example.com/one-piece-1089"
        )
        XCTAssertEqual(episode?.show, "One Piece")
        XCTAssertEqual(episode?.episode, 1089)
    }

    func testShowPageWithNoEpisodeIsNotAnEpisode() {
        XCTAssertNil(EpisodeParser.parse(
            title: "Watch The Pitt | Netflix", url: "https://www.netflix.com/title/81736384"
        ))
        XCTAssertNil(EpisodeParser.parse(
            title: "Spidey - a launcher for macOS", url: "https://github.com/spidey"
        ))
    }

    func testResolutionsAreNotEpisodeNumbers() {
        XCTAssertNil(EpisodeParser.parse(
            title: "Sample video 1920x1080", url: "https://example.com/sample"
        ))
    }

    func testTypedQueries() {
        XCTAssertEqual(
            EpisodeParser.parseTyped("the pitt s1e6"),
            EpisodeParser.Episode(show: "the pitt", season: 1, episode: 6)
        )
        XCTAssertEqual(
            EpisodeParser.parseTyped("the pitt season 2 episode 11"),
            EpisodeParser.Episode(show: "the pitt", season: 2, episode: 11)
        )
        XCTAssertEqual(
            EpisodeParser.parseTyped("severance ep 4"),
            EpisodeParser.Episode(show: "severance", season: nil, episode: 4)
        )
        XCTAssertNil(EpisodeParser.parseTyped("the pitt"))
    }

    func testNextEpisodeURL() {
        XCTAssertEqual(
            EpisodeParser.advancedURL("https://hydrahd.sx/watch-tv/the-pitt/1/6", toEpisode: 7),
            "https://hydrahd.sx/watch-tv/the-pitt/1/7"
        )
        // The site's zero padding is kept.
        XCTAssertEqual(
            EpisodeParser.advancedURL("https://example.to/the-pitt.s01e06", toEpisode: 7),
            "https://example.to/the-pitt.s01e07"
        )
        // An opaque player id gives nothing to advance, so nothing is guessed.
        XCTAssertNil(EpisodeParser.advancedURL("https://example.com/play/9931", toEpisode: 7))
    }

    func testDeslug() {
        XCTAssertEqual(EpisodeParser.deslug("the-pitt-2025"), "The Pitt")
        XCTAssertEqual(EpisodeParser.deslug("the-100"), "The 100")
        XCTAssertEqual(EpisodeParser.deslug("watch-tv"), "")
    }
}

final class WatchStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WatchTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testRoundTrip() {
        let store = WatchStore(directory: directory)
        store.record(show: "The Pitt", season: 1, episode: 6, site: "hydrahd.sx", url: "https://hydrahd.sx/1/6")

        let reloaded = WatchStore(directory: directory)
        let entry = reloaded.entry(forShow: "the pitt")
        XCTAssertEqual(entry?.show, "The Pitt")
        XCTAssertEqual(entry?.season, 1)
        XCTAssertEqual(entry?.episode, 6)
        XCTAssertEqual(entry?.site, "hydrahd.sx")
    }

    func testOneEntryPerShow() {
        let store = WatchStore(directory: directory)
        store.record(show: "The Pitt", season: 1, episode: 6)
        store.record(show: "the-pitt", season: 1, episode: 7)
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.episode, 7)
        // The newest save also decides how the name is spelled.
        XCTAssertEqual(store.entries.first?.show, "the-pitt")
    }

    func testMissingFieldsKeepTheOldOnes() {
        let store = WatchStore(directory: directory)
        store.record(show: "The Pitt", season: 2, episode: 6, site: "hydrahd.sx", url: "https://hydrahd.sx/2/6")
        // Typing "watching the pitt ep 7" names no season or site.
        store.record(show: "The Pitt", season: nil, episode: 7)
        let entry = store.entry(forShow: "The Pitt")
        XCTAssertEqual(entry?.season, 2)
        XCTAssertEqual(entry?.site, "hydrahd.sx")
        XCTAssertEqual(entry?.episode, 7)
    }

    func testNormalizeIgnoresLeadingTheAndPunctuation() {
        XCTAssertEqual(WatchStore.normalize("The Pitt (2025)"), WatchStore.normalize("the-pitt"))
        XCTAssertEqual(WatchStore.normalize("Pitt"), WatchStore.normalize("The Pitt"))
    }

    func testMatchesFindsShowsByName() {
        let store = WatchStore(directory: directory)
        store.record(show: "The Pitt", season: 1, episode: 6)
        store.record(show: "Severance", season: 2, episode: 3)
        XCTAssertEqual(store.matches(for: "pitt").first?.entry.show, "The Pitt")
        XCTAssertEqual(store.matches(for: "sever").first?.entry.show, "Severance")
        XCTAssertTrue(store.matches(for: "quarterly forecast").isEmpty)
    }

    func testEntriesAreCapped() {
        let store = WatchStore(directory: directory)
        for index in 1...(WatchStore.maxEntries + 5) {
            store.record(show: "Show \(index)", season: 1, episode: index)
        }
        XCTAssertEqual(store.entries.count, WatchStore.maxEntries)
    }

    func testShortNamesAreRejected() {
        let store = WatchStore(directory: directory)
        XCTAssertNil(store.record(show: "x", season: 1, episode: 2))
        XCTAssertTrue(store.entries.isEmpty)
    }

    func testPositionLabels() {
        let withSeason = WatchEntry(show: "The Pitt", season: 1, episode: 6)
        XCTAssertEqual(withSeason.positionLabel, "Season 1, Episode 6")
        XCTAssertEqual(withSeason.nextPositionLabel, "Season 1, Episode 7")
        let without = WatchEntry(show: "One Piece", season: nil, episode: 89)
        XCTAssertEqual(without.positionLabel, "Episode 89")
    }
}

final class WatchProviderTests: XCTestCase {
    private var directory: URL!
    private var store: WatchStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WatchProviderTests-\(UUID().uuidString)", isDirectory: true)
        store = WatchStore(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func results(_ query: String, open: [WatchCapture.Candidate] = []) -> [ResultItem] {
        WatchProvider.results(for: query, store: store, openEpisodes: { open })
    }

    func testTypedEpisodeOffersASave() {
        let items = results("watching the pitt s1e6")
        // Typed in lower case, saved the way it is written.
        XCTAssertEqual(items.first?.title, "Save The Pitt - Season 1, Episode 6")
        items.first?.action()
        XCTAssertEqual(store.entry(forShow: "the pitt")?.show, "The Pitt")
        XCTAssertEqual(store.entry(forShow: "the pitt")?.episode, 6)
    }

    func testOpenEpisodeOffersASave() {
        let candidate = WatchCapture.Candidate(
            episode: .init(show: "The Pitt", season: 1, episode: 6),
            url: "https://hydrahd.sx/watch-tv/the-pitt/1/6",
            site: "hydrahd.sx"
        )
        let items = results("watching", open: [candidate])
        XCTAssertEqual(items.first?.title, "Save The Pitt - Season 1, Episode 6")
        XCTAssertTrue(items.first?.subtitle.contains("hydrahd.sx") == true)
    }

    func testAlreadySavedEpisodeIsNotOfferedAgain() {
        store.record(show: "The Pitt", season: 1, episode: 6, site: "hydrahd.sx")
        let candidate = WatchCapture.Candidate(
            episode: .init(show: "The Pitt", season: 1, episode: 6),
            url: "https://hydrahd.sx/watch-tv/the-pitt/1/6",
            site: "hydrahd.sx"
        )
        let items = results("watching", open: [candidate])
        XCTAssertFalse(items.contains { $0.title.hasPrefix("Save ") })
        XCTAssertEqual(items.first?.title, "The Pitt - Season 1, Episode 6")
    }

    func testListingAndForgetting() {
        store.record(show: "The Pitt", season: 1, episode: 6)
        store.record(show: "Severance", season: 2, episode: 3)
        let items = results("watching")
        XCTAssertEqual(items.count, 2)
        // Newest first.
        XCTAssertEqual(items.first?.title, "Severance - Season 2, Episode 3")
        items.first?.secondaryAction?()
        XCTAssertEqual(store.entries.count, 1)
    }

    func testEmptyState() {
        let items = results("watching")
        XCTAssertEqual(items.first?.title, "Nothing saved yet")
    }

    func testResumeStaysOutOfTheWayUntilItHasSomethingToSay() {
        // "resume" on its own is someone looking for their CV, not a show.
        XCTAssertTrue(results("resume").isEmpty)
        XCTAssertTrue(results("resume the pitt").isEmpty)
        XCTAssertTrue(store.entries.isEmpty)

        store.record(show: "The Pitt", season: 1, episode: 6)
        XCTAssertEqual(results("resume the pitt").first?.title, "The Pitt - Season 1, Episode 6")
        // Still nothing for the CV.
        XCTAssertTrue(results("resume").isEmpty)
    }

    func testShowNameOffersResumeAndNextEpisode() {
        store.record(
            show: "The Pitt", season: 1, episode: 6, site: "hydrahd.sx",
            url: "https://hydrahd.sx/watch-tv/the-pitt/1/6"
        )
        let items = WatchProvider.resumeResults(for: "the pitt", store: store)
        XCTAssertEqual(items.first?.title, "Resume The Pitt - Season 1, Episode 6")
        XCTAssertEqual(items.last?.title, "Next up: The Pitt - Season 1, Episode 7")
        // Resuming must outrank the "Watch ... on Netflix" rows (200).
        XCTAssertGreaterThan(items.first?.score ?? 0, 200)
    }

    func testUnrelatedQueriesAreLeftAlone() {
        store.record(show: "The Pitt", season: 1, episode: 6)
        XCTAssertTrue(WatchProvider.resumeResults(for: "pitch deck", store: store).isEmpty)
        XCTAssertTrue(WatchProvider.resumeResults(for: "chrome", store: store).isEmpty)
        // The keyword form is handled by results(), not by the bare-name path.
        XCTAssertTrue(WatchProvider.resumeResults(for: "watching the pitt", store: store).isEmpty)
    }

    func testSearchAndBlankTabsAreIgnored() {
        let tabs = [
            TabsProvider.Tab(
                windowIndex: 1, tabIndex: 1,
                title: "the pitt season 1 episode 6 - Google Search",
                url: "https://www.google.com/search?q=the+pitt+season+1+episode+6"
            ),
            TabsProvider.Tab(windowIndex: 1, tabIndex: 2, title: "New Tab", url: "chrome://newtab"),
        ]
        XCTAssertTrue(WatchCapture.candidates(from: tabs).isEmpty)
    }

    func testMoreRealTabTitles() {
        let cases: [(String, String, String, Int?, Int)] = [
            ("The Pitt (2025) - Season 1 Episode 6 - Watch Online Free | HDToday",
             "https://hdtoday.example/watch-tv/the-pitt-2025/1-6", "The Pitt", 1, 6),
            ("Severance Season 2 Episode 3 Full HD - Fmovies",
             "https://fmovies.example/film/severance/2-3", "Severance", 2, 3),
            ("Watch Breaking Bad S05E14 Online",
             "https://soap.example/tv/breaking-bad/s05e14", "Breaking Bad", 5, 14),
            ("Naruto Shippuden Episode 500 English Dubbed | AnimeSuge",
             "https://animesuge.example/naruto-shippuden/ep-500", "Naruto Shippuden", nil, 500),
        ]
        for (title, url, show, season, episode) in cases {
            let parsed = EpisodeParser.parse(title: title, url: url)
            XCTAssertEqual(parsed?.show, show, title)
            XCTAssertEqual(parsed?.season, season, title)
            XCTAssertEqual(parsed?.episode, episode, title)
        }
    }

    func testEverydayTabsAreNotEpisodes() {
        let cases = [
            ("Rick Astley - Never Gonna Give You Up (Official Video) - YouTube", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
            ("Inbox (12) - tanush@example.com - Gmail", "https://mail.google.com/mail/u/0"),
            ("Spidey: a launcher for macOS", "https://github.com/example/spidey"),
            ("Trainers, Clothing & Accessories", "https://www.nike.com/gb/"),
        ]
        for (title, url) in cases {
            XCTAssertNil(EpisodeParser.parse(title: title, url: url), title)
        }
    }

    func testMoviePagesAreRecognised() {
        let movie = EpisodeParser.parseMovie(
            title: "Stream The Amazing Spider-Man (2012) Online Free Watch Full Now HD - HydraHD",
            url: "https://hydrahd.ws/movie/52128-watch-the-amazing-spider-man-2012-online"
        )
        XCTAssertEqual(movie, EpisodeParser.Episode(show: "The Amazing Spider-Man", season: nil, episode: 0))
        // No year in the title: the URL slug names it.
        XCTAssertEqual(
            EpisodeParser.parseMovie(title: "HydraHD", url: "https://hydrahd.ws/movie/123-watch-dune-part-two")?.show,
            "Dune Part Two"
        )
        // Not filed under a movie path, not a movie.
        XCTAssertNil(EpisodeParser.parseMovie(
            title: "Rick Astley - Never Gonna Give You Up (1987)", url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        ))
    }

    func testOpenMovieIsOfferedSavedAndResumed() {
        let tabs = [TabsProvider.Tab(
            windowIndex: 1, tabIndex: 1,
            title: "Stream The Amazing Spider-Man (2012) Online Free Watch Full Now HD - HydraHD",
            url: "https://hydrahd.ws/movie/52128-watch-the-amazing-spider-man-2012-online"
        )]
        let open = WatchCapture.candidates(from: tabs)
        XCTAssertEqual(open.count, 1)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WatchMovie-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WatchStore(directory: directory)
        let items = WatchProvider.results(for: "watching", store: store, openEpisodes: { open })
        XCTAssertEqual(items.first?.title, "Save The Amazing Spider-Man")
        items.first?.action()
        XCTAssertEqual(store.entries.first?.url, tabs[0].url)
        XCTAssertTrue(WatchCapture.isAlreadySaved(open[0], store: store))

        let resume = WatchProvider.resumeResults(for: "the amazing spider-man", store: store)
        XCTAssertEqual(resume.map(\.title), ["Resume The Amazing Spider-Man"])
    }

    func testCandidatesAreOnePerShow() {
        let tabs = [
            TabsProvider.Tab(windowIndex: 1, tabIndex: 1, title: "The Pitt S01E06 | Hydra", url: "https://hydrahd.sx/watch-tv/the-pitt/1/6"),
            TabsProvider.Tab(windowIndex: 1, tabIndex: 2, title: "The Pitt S01E06 mirror", url: "https://other.example/the-pitt/1/6"),
            TabsProvider.Tab(windowIndex: 1, tabIndex: 3, title: "Inbox (12)", url: "https://mail.google.com"),
        ]
        let candidates = WatchCapture.candidates(from: tabs)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.site, "hydrahd.sx")
        XCTAssertEqual(candidates.first?.episode.show, "The Pitt")
    }
}
