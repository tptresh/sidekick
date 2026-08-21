import XCTest
@testable import Spidey

final class CalculatorTests: XCTestCase {
    func testBasicArithmetic() {
        XCTAssertEqual(Calculator.evaluate("2+2"), 4)
        XCTAssertEqual(Calculator.evaluate("10 - 4 * 2"), 2)
        XCTAssertEqual(Calculator.evaluate("(10 - 4) * 2"), 12)
        XCTAssertEqual(Calculator.evaluate("7 / 2"), 3.5)
        XCTAssertEqual(Calculator.evaluate("10 % 3"), 1)
        XCTAssertEqual(Calculator.evaluate("-5 + 3"), -2)
    }

    func testInvalidInput() {
        XCTAssertNil(Calculator.evaluate("2 +"))
        XCTAssertNil(Calculator.evaluate("(2 + 3"))
        XCTAssertNil(Calculator.evaluate(""))
        XCTAssertNil(Calculator.evaluate("1/0")?.isFinite == true ? Calculator.evaluate("1/0") : nil)
    }

    func testExpressionDetection() {
        XCTAssertTrue(Calculator.looksLikeExpression("2+2"))
        XCTAssertTrue(Calculator.looksLikeExpression("(3*4)/2"))
        XCTAssertFalse(Calculator.looksLikeExpression("safari"))
        XCTAssertFalse(Calculator.looksLikeExpression("death note"))
        XCTAssertFalse(Calculator.looksLikeExpression("42"))
    }

    func testFormat() {
        XCTAssertEqual(Calculator.format(4), "4")
        XCTAssertEqual(Calculator.format(3.5), "3.5")
    }
}

final class FuzzyTests: XCTestCase {
    func testExactAndPrefix() {
        XCTAssertEqual(Fuzzy.score(query: "safari", candidate: "Safari"), 1.0)
        XCTAssertEqual(Fuzzy.score(query: "saf", candidate: "Safari"), 0.92)
    }

    func testWordBoundaryAndInitials() {
        XCTAssertEqual(Fuzzy.score(query: "chrome", candidate: "Google Chrome"), 0.82)
        XCTAssertEqual(Fuzzy.score(query: "gc", candidate: "Google Chrome"), 0.68)
    }

    func testNoMatch() {
        XCTAssertNil(Fuzzy.score(query: "xyz", candidate: "Safari"))
    }

    func testRankingOrder() {
        let prefix = Fuzzy.score(query: "gra", candidate: "grand seiko")!
        let substring = Fuzzy.score(query: "seiko", candidate: "grand seiko")!
        XCTAssertGreaterThan(prefix, substring)
    }
}

final class AppProviderTests: XCTestCase {
    func testAppleAliasForFirstPartyApps() {
        XCTAssertEqual(
            AppProvider.aliases(name: "TV", displayName: "TV", bundleIdentifier: "com.apple.TV"),
            ["Apple TV"]
        )
        XCTAssertEqual(
            AppProvider.aliases(name: "Music", displayName: nil, bundleIdentifier: "com.apple.Music"),
            ["Apple Music"]
        )
    }

    func testNoAppleAliasForThirdPartyOrAlreadyApple() {
        XCTAssertEqual(
            AppProvider.aliases(name: "Slack", displayName: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap"),
            []
        )
        XCTAssertEqual(
            AppProvider.aliases(name: "AppleScript Editor", displayName: nil, bundleIdentifier: "com.apple.ScriptEditor2"),
            []
        )
    }

    func testDisplayNameBecomesAlias() {
        XCTAssertEqual(
            AppProvider.aliases(name: "zoom.us", displayName: "Zoom", bundleIdentifier: "us.zoom.xos"),
            ["Zoom"]
        )
    }

    func testAppleTVQueryMatchesTVApp() {
        let score = AppProvider.matchScore(query: "apple tv", name: "TV", aliases: ["Apple TV"])
        XCTAssertNotNil(score)
        XCTAssertGreaterThan(score!, 0.9)
        XCTAssertNil(AppProvider.matchScore(query: "apple tv", name: "TV", aliases: []))
    }

    func testRealNameStillWinsExactTies() {
        let direct = AppProvider.matchScore(query: "tv", name: "TV", aliases: ["Apple TV"])!
        let viaAlias = AppProvider.matchScore(query: "apple tv", name: "TV", aliases: ["Apple TV"])!
        XCTAssertGreaterThan(direct, viaAlias)
    }
}

final class FileProviderTests: XCTestCase {
    func testSpotlightQuerySingleWord() {
        XCTAssertEqual(FileProvider.spotlightQuery(for: "invoice"), "kMDItemFSName = \"*invoice*\"cd")
    }

    func testSpotlightQueryMultiWord() {
        XCTAssertEqual(
            FileProvider.spotlightQuery(for: "auracare deck"),
            "kMDItemFSName = \"*auracare*\"cd && kMDItemFSName = \"*deck*\"cd"
        )
    }

    func testSpotlightQueryEscapesQuotesAndStripsWildcards() {
        XCTAssertEqual(FileProvider.spotlightQuery(for: "a\"b"), "kMDItemFSName = \"*a\\\"b*\"cd")
        XCTAssertEqual(FileProvider.spotlightQuery(for: "inv*"), "kMDItemFSName = \"*inv*\"cd")
        XCTAssertNil(FileProvider.spotlightQuery(for: "*"))
        XCTAssertNil(FileProvider.spotlightQuery(for: "   "))
    }

    func testNoiseFilter() {
        XCTAssertTrue(FileProvider.isNoise("/Users/me/Library/Caches/thing.db"))
        XCTAssertTrue(FileProvider.isNoise("/System/Volumes/Data/foo"))
        XCTAssertTrue(FileProvider.isNoise("/Applications/Safari.app"))
        XCTAssertTrue(FileProvider.isNoise("/Users/me/proj/node_modules/pkg/index.js"))
        XCTAssertTrue(FileProvider.isNoise("/Users/me/.config/settings.json"))
        XCTAssertFalse(FileProvider.isNoise("/Users/me/Documents/invoice.pdf"))
        XCTAssertFalse(FileProvider.isNoise("/Volumes/Backup/photos/trip.jpg"))
    }

    func testExactNameBeatsPartial() {
        let exact = FileProvider.matchScore(query: "invoice", path: "/Users/me/Documents/invoice.pdf")
        let partial = FileProvider.matchScore(query: "invoice", path: "/Users/me/Documents/old-invoices-2019.pdf")
        XCTAssertEqual(exact, 1.0)
        XCTAssertGreaterThan(exact, partial)
    }

    func testMultiWordScoring() {
        let both = FileProvider.matchScore(query: "auracare deck", path: "/Users/me/Documents/auracare-deck.pdf")
        let one = FileProvider.matchScore(query: "auracare deck", path: "/Users/me/deck/auracare-notes.txt")
        XCTAssertGreaterThan(both, one)
    }

    func testShallowPathWinsTies() {
        let shallow = FileProvider.matchScore(query: "notes", path: "/Users/me/notes.md")
        let deep = FileProvider.matchScore(query: "notes", path: "/Users/me/archive/2019/projects/misc/notes copy 3.md")
        XCTAssertGreaterThan(shallow, deep)
    }
}

final class ClaudeProviderTests: XCTestCase {
    func testDeepLinkURL() {
        let url = ClaudeProvider.deepLinkURL(
            prompt: "fix the spelling issue", directory: "/Users/me/project"
        )
        XCTAssertEqual(
            url?.absoluteString,
            "claude://code/new?q=fix%20the%20spelling%20issue&folder=/Users/me/project"
        )
    }

    func testDeepLinkURLEscapesSpecialCharacters() throws {
        let url = try XCTUnwrap(ClaudeProvider.deepLinkURL(
            prompt: "what does a & b = c mean?", directory: "/Users/me/my project"
        ))
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.queryItems?.first { $0.name == "q" }?.value, "what does a & b = c mean?")
        XCTAssertEqual(components?.queryItems?.first { $0.name == "folder" }?.value, "/Users/me/my project")
    }
}

final class URLBuildingTests: XCTestCase {
    func testYouTubeSearchURL() {
        let url = MediaProvider.youtubeSearchURL("lofi beats")
        XCTAssertEqual(url.absoluteString, "https://www.youtube.com/results?search_query=lofi%20beats")
    }

    func testWebSearchKeyword() {
        let url = WebSearchProvider.searchURL(trigger: "amazon", query: "death note manga")
        XCTAssertEqual(url?.absoluteString, "https://www.amazon.co.uk/s?k=death%20note%20manga")
    }

    func testSiteGuess() {
        XCTAssertEqual(SiteDirectoryProvider.guessURL(for: "grand seiko")?.absoluteString, "https://www.grandseiko.com")
        XCTAssertEqual(SiteDirectoryProvider.guessURL(for: "Some-Brand!")?.absoluteString, "https://www.somebrand.com")
    }

    func testBuiltInDirectoryHasUserRequestedSites() {
        XCTAssertNotNil(SiteDirectoryProvider.builtIn["vinted"])
        XCTAssertNotNil(SiteDirectoryProvider.builtIn["rimowa"])
        XCTAssertNotNil(SiteDirectoryProvider.builtIn["grand seiko"])
        XCTAssertNotNil(SiteDirectoryProvider.builtIn["outlook"])
    }

    func testMainSiteRanksAboveStreamingSuggestions() {
        // A known site name must sort above the "Watch on ..." rows (score 200).
        let outlook = SiteDirectoryProvider.results(for: "outlook")
        XCTAssertEqual(outlook.first?.title, "Open Outlook")
        XCTAssertGreaterThan(outlook.first?.score ?? 0, 200)

        // A single-word unknown name reads as a site, so its homepage guess
        // also outranks streaming; multi-word queries read as show titles.
        let single = SiteDirectoryProvider.results(for: "kagi")
        XCTAssertGreaterThan(single.first?.score ?? 0, 200)
        let multi = SiteDirectoryProvider.results(for: "the last of us")
        if let guess = multi.first(where: { $0.title.hasPrefix("Open www.") }) {
            XCTAssertLessThan(guess.score, 200)
        }
    }

    func testNoEmDashInBuiltInSites() {
        for (name, url) in SiteDirectoryProvider.builtIn {
            XCTAssertFalse(name.contains("\u{2014}"))
            XCTAssertFalse(url.contains("\u{2014}"))
        }
    }
}

final class CustomMediaSiteTests: XCTestCase {
    func testPlainAddressHasNoSearchURLUntilOneIsLearned() {
        // A plain link cannot be searched by URL until discovery learns how;
        // its result row opens the homepage in the meantime.
        let site = CustomMediaSite(name: "", urlString: "https://flickystream.dad/")
        XCTAssertNil(site.searchURL(encodedQuery: "big%20bang%20theory"))
        XCTAssertEqual(site.homepageURL?.absoluteString, "https://flickystream.dad")
    }

    func testTemplateSubstitution() {
        let braces = CustomMediaSite(name: "Example", urlString: "https://example.com/search?q={query}")
        XCTAssertEqual(
            braces.searchURL(encodedQuery: "death%20note")?.absoluteString,
            "https://example.com/search?q=death%20note"
        )
        let percent = CustomMediaSite(name: "Example", urlString: "https://example.com/?s=%s")
        XCTAssertEqual(
            percent.searchURL(encodedQuery: "death%20note")?.absoluteString,
            "https://example.com/?s=death%20note"
        )
    }

    func testSchemeIsAddedWhenMissing() {
        let site = CustomMediaSite(name: "", urlString: "flickystream.dad")
        XCTAssertEqual(site.normalizedURLString, "https://flickystream.dad")
        XCTAssertEqual(site.homepageURL?.absoluteString, "https://flickystream.dad")
        XCTAssertTrue(site.isValid)
    }

    func testDisplayNameFallsBackToHostWithoutWWW() {
        XCTAssertEqual(
            CustomMediaSite(name: "", urlString: "https://www.paramountplus.com").displayName,
            "paramountplus.com"
        )
        XCTAssertEqual(
            CustomMediaSite(name: "Paramount+", urlString: "https://www.paramountplus.com").displayName,
            "Paramount+"
        )
    }

    func testEmptyOrBrokenEntriesAreInvalid() {
        XCTAssertFalse(CustomMediaSite(name: "", urlString: "").isValid)
        XCTAssertFalse(CustomMediaSite(name: "x", urlString: "   ").isValid)
    }
}

final class MediaOrderTests: XCTestCase {
    private let allEnabled = Set(StreamingService.all.map(\.id))

    func testDefaultOrderKeepsServicesFirstThenCustomSites() {
        let site = CustomMediaSite(name: "Flicky", urlString: "https://flickystream.dad")
        let entries = SettingsStore.orderedMediaEntries(
            order: [], services: StreamingService.all, customSites: [site],
            enabledServices: allEnabled
        )
        XCTAssertEqual(entries.map(\.id), StreamingService.all.map(\.id) + [site.id.uuidString])
    }

    func testStoredOrderWinsAndStaleIdsAreDropped() {
        let site = CustomMediaSite(name: "Flicky", urlString: "https://flickystream.dad")
        let order = [site.id.uuidString, "disneyplus", "removed-long-ago", "netflix"]
        let entries = SettingsStore.orderedMediaEntries(
            order: order, services: StreamingService.all, customSites: [site],
            enabledServices: allEnabled
        )
        XCTAssertEqual(
            Array(entries.map(\.id).prefix(3)),
            [site.id.uuidString, "disneyplus", "netflix"]
        )
        // Ids missing from the stored order still show up, after the ordered ones.
        XCTAssertEqual(
            Set(entries.map(\.id)),
            Set(StreamingService.all.map(\.id) + [site.id.uuidString])
        )
    }

    func testUntickedCustomSitesSinkLikeServices() {
        let site = CustomMediaSite(name: "Flicky", urlString: "https://flickystream.dad", enabled: false)
        let entries = SettingsStore.orderedMediaEntries(
            order: [site.id.uuidString] + StreamingService.all.map(\.id),
            services: StreamingService.all, customSites: [site],
            enabledServices: allEnabled
        )
        XCTAssertEqual(entries.last?.id, site.id.uuidString)
    }

    func testSitesSavedBeforeEnabledFlagDecodeAsEnabled() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Old","urlString":"https://old.example"}"#
        let site = try JSONDecoder().decode(CustomMediaSite.self, from: Data(json.utf8))
        XCTAssertTrue(site.enabled)
    }

    func testDisabledServicesSinkBelowEnabledOnesAndCustomSites() {
        let site = CustomMediaSite(name: "Flicky", urlString: "https://flickystream.dad")
        let order = ["netflix", "primevideo", "crunchyroll", site.id.uuidString, "disneyplus"]
        let entries = SettingsStore.orderedMediaEntries(
            order: order, services: StreamingService.all, customSites: [site],
            enabledServices: ["netflix", "crunchyroll", "disneyplus"]
        )
        // Prime Video is unticked, so it drops to the bottom; everything else
        // keeps its stored order.
        XCTAssertEqual(
            entries.map(\.id),
            ["netflix", "crunchyroll", site.id.uuidString, "disneyplus", "primevideo"]
        )
        // Re-ticking it restores the stored slot.
        let restored = SettingsStore.orderedMediaEntries(
            order: order, services: StreamingService.all, customSites: [site],
            enabledServices: allEnabled
        )
        XCTAssertEqual(restored.map(\.id), order)
    }
}

final class SearchTemplateFinderTests: XCTestCase {
    func testWordPressStyleFormBecomesTemplate() {
        let html = #"<header><form role="search" method="get" action="/"><input type="text" name="s" placeholder="Search…"></form></header>"#
        let template = SearchTemplateFinder.template(
            fromHTML: html, baseURL: URL(string: "https://example.com")!
        )
        XCTAssertEqual(template, "https://example.com/?s={query}")
    }

    func testFormWithSearchActionAndHiddenInputs() {
        let html = #"<form action="/search"><input type="hidden" name="type" value="all"><input type="search" name="q"></form>"#
        let template = SearchTemplateFinder.template(
            fromHTML: html, baseURL: URL(string: "https://example.com")!
        )
        XCTAssertEqual(template, "https://example.com/search?type=all&q={query}")
    }

    func testPostFormsAndNonSearchInputsAreIgnored() {
        let html = #"<form method="post" action="/login"><input type="text" name="q"></form><form action="/subscribe"><input type="email" name="email"></form>"#
        XCTAssertNil(SearchTemplateFinder.template(
            fromHTML: html, baseURL: URL(string: "https://example.com")!
        ))
    }

    func testSearchRouteDetectionForSinglePageApps() {
        XCTAssertTrue(SearchTemplateFinder.mentionsSearchRoute(
            #"<loc>https://flickystream.ru/search</loc>"#
        ))
        XCTAssertTrue(SearchTemplateFinder.mentionsSearchRoute(#"{label:"Search",to:"/search"}"#))
        XCTAssertFalse(SearchTemplateFinder.mentionsSearchRoute("all about /searchengines here"))
        XCTAssertFalse(SearchTemplateFinder.mentionsSearchRoute("plain page"))
        XCTAssertEqual(
            SearchTemplateFinder.searchPathTemplate(for: URL(string: "https://flickystream.dad")!),
            "https://flickystream.dad/search?q={query}"
        )
    }

    func testSearchActionMarkupInEscapedJSONWins() {
        // Framework payloads ship the JSON-LD escaped, with a sloppy double
        // slash in the path - as 1shows.org does.
        let html = #"lAction\\\":[{\\\"@type\\\":\\\"SearchAction\\\",\\\"target\\\":{\\\"@type\\\":\\\"EntryPoint\\\",\\\"urlTemplate\\\":\\\"https://www.1shows.org//search?query={search_term_string}\\\"},\\\"query-input\\\":..."#
        let template = SearchTemplateFinder.searchActionTemplate(
            fromHTML: html, baseURL: URL(string: "https://www.1shows.org")!
        )
        XCTAssertEqual(template, "https://www.1shows.org/search?query={query}")
    }

    func testSearchActionWithRelativeTarget() {
        let html = #"<script type="application/ld+json">{"@type":"WebSite","potentialAction":{"@type":"SearchAction","target":"/find?keyword={search_term_string}"}}</script>"#
        let template = SearchTemplateFinder.searchActionTemplate(
            fromHTML: html, baseURL: URL(string: "https://example.com")!
        )
        XCTAssertEqual(template, "https://example.com/find?keyword={query}")
    }

    func testMirrorDomainCandidatesAreRehostedToTheEnteredLink() {
        // 67movies.nl's markup declares its search on the canonical .net
        // domain; a foreign-host template can never activate, so candidates
        // must come back on the host the user entered.
        let html = #"{"@type":"SearchAction","target":"https://67movies.net/search?q={search_term_string}"}"#
        let candidates = SearchTemplateFinder.candidateTemplates(
            fromHTML: html, sitemap: nil, homepage: URL(string: "https://67movies.nl")!
        )
        XCTAssertEqual(candidates.first, "https://67movies.nl/search?q={query}")
        XCTAssertFalse(candidates.contains { $0.contains("67movies.net") })
    }

    func testRehostingLeavesPathQueryAndPlaceholderAlone() {
        XCTAssertEqual(
            SearchTemplateFinder.rehosted(
                "https://mirror.example/find?keyword={query}&lang=en", to: "site.example"
            ),
            "https://site.example/find?keyword={query}&lang=en"
        )
        // Already on the right host: unchanged.
        XCTAssertEqual(
            SearchTemplateFinder.rehosted("https://site.example/?s={query}", to: "site.example"),
            "https://site.example/?s={query}"
        )
    }

    func testNoSearchActionMarkupReturnsNil() {
        XCTAssertNil(SearchTemplateFinder.searchActionTemplate(
            fromHTML: "<p>just a page mentioning /search</p>",
            baseURL: URL(string: "https://example.com")!
        ))
    }

    func testCandidatesRankSearchActionFirstThenGuesses() {
        let html = #"{"urlTemplate":"https://example.com/search?query={search_term_string}"} plus a /search link"#
        let candidates = SearchTemplateFinder.candidateTemplates(
            fromHTML: html, sitemap: nil, homepage: URL(string: "https://example.com")!
        )
        XCTAssertEqual(candidates.first, "https://example.com/search?query={query}")
        XCTAssertTrue(candidates.contains("https://example.com/search?q={query}"))
        XCTAssertLessThanOrEqual(candidates.count, 5)
        // Deduped: the SearchAction template must not repeat among the guesses.
        XCTAssertEqual(candidates, Array(Set(candidates)).sorted { a, b in
            candidates.firstIndex(of: a)! < candidates.firstIndex(of: b)!
        })
    }

    func testCandidatesWithoutAnyHintsStillOfferGenericGuesses() {
        let candidates = SearchTemplateFinder.candidateTemplates(
            fromHTML: "<p>nothing here</p>", sitemap: nil,
            homepage: URL(string: "https://example.com")!
        )
        XCTAssertEqual(candidates, [
            "https://example.com/?s={query}",
            "https://example.com/search?q={query}",
        ])
    }

    func testSitemapMentionAddsSearchRouteGuesses() {
        let candidates = SearchTemplateFinder.candidateTemplates(
            fromHTML: nil, sitemap: "<loc>https://example.com/search</loc>",
            homepage: URL(string: "https://example.com")!
        )
        XCTAssertEqual(candidates.first, "https://example.com/search?q={query}")
        XCTAssertTrue(candidates.contains("https://example.com/search?query={query}"))
    }

    func testDiscoveredTemplateIsUsedForSearches() {
        let site = CustomMediaSite(
            name: "FD", urlString: "https://flickystream.dad",
            discoveredTemplate: "https://flickystream.dad/search?q={query}"
        )
        XCTAssertTrue(site.searchesDirectly)
        XCTAssertEqual(
            site.searchURL(encodedQuery: "big%20bang")?.absoluteString,
            "https://flickystream.dad/search?q=big%20bang"
        )
    }

    func testStaleDiscoveryIsDroppedWhenLinkChanges() {
        // The link was edited to a different site after discovery ran.
        let site = CustomMediaSite(
            name: "FD", urlString: "https://newsite.example",
            discoveredTemplate: "https://flickystream.dad/search?q={query}"
        )
        XCTAssertNil(site.activeDiscoveredTemplate)
        XCTAssertFalse(site.searchesDirectly)
        XCTAssertNil(site.searchURL(encodedQuery: "test"))
    }

    func testDiscoveredAPIPairIsActiveOnlyWhileHostMatches() {
        let site = CustomMediaSite(
            name: "movie", urlString: "https://67movies.nl/",
            discoveredAPITemplate: "https://67movies.nl/api/semantic-search?q={query}",
            discoveredTitleTemplate: "https://67movies.nl/watch/{r.media_type}/{r.id}"
        )
        XCTAssertNotNil(site.activeDiscoveredAPI)
        XCTAssertFalse(site.searchesDirectly)
        XCTAssertNil(site.searchURL(encodedQuery: "test"))

        let edited = CustomMediaSite(
            name: "movie", urlString: "https://othersite.example",
            discoveredAPITemplate: "https://67movies.nl/api/semantic-search?q={query}",
            discoveredTitleTemplate: "https://67movies.nl/watch/{r.media_type}/{r.id}"
        )
        XCTAssertNil(edited.activeDiscoveredAPI)
    }

    func testExplicitTemplateBeatsDiscoveredOne() {
        let site = CustomMediaSite(
            name: "FD", urlString: "https://flickystream.dad/browse?find={query}",
            discoveredTemplate: "https://flickystream.dad/search?q={query}"
        )
        XCTAssertEqual(
            site.searchURL(encodedQuery: "test")?.absoluteString,
            "https://flickystream.dad/browse?find=test"
        )
    }
}

final class SiteSearchAnalysisTests: XCTestCase {
    // The shapes below mirror what the probe observed on 67movies.nl: the
    // overlay queries a search API, and homepage links pair TMDB-style JSON
    // objects with /watch/{media_type}/{id} routes.

    func testAPITemplatesPickRequestsCarryingTheQuery() {
        let recorded = [
            "https://67movies.nl/_next/image?url=poster.jpg&w=256",
            "https://api.themoviedb.org/3/trending/all/day?api_key=k",
            "https://api.themoviedb.org/3/search/multi?api_key=k&query=Interstellar",
            "https://67movies.nl/api/semantic-search?q=Interstellar",
        ]
        let templates = SiteSearchAnalysis.apiTemplates(
            recordedURLs: recorded, probeQuery: "Interstellar", host: "67movies.nl"
        )
        // The site's own endpoint outranks the third-party one.
        XCTAssertEqual(templates.first, "https://67movies.nl/api/semantic-search?q={query}")
        XCTAssertTrue(templates.contains(
            "https://api.themoviedb.org/3/search/multi?api_key=k&query={query}"
        ))
        XCTAssertFalse(templates.contains { $0.contains("_next/image") })
    }

    func testAPITemplatesMatchPercentEncodedQueries() {
        let templates = SiteSearchAnalysis.apiTemplates(
            recordedURLs: ["https://site.example/api/search?q=big%20bang"],
            probeQuery: "big bang", host: "site.example"
        )
        XCTAssertEqual(templates, ["https://site.example/api/search?q={query}"])
    }

    func testTitleTemplateLearnedFromLinksAndJSON() {
        let trending = #"{"results":[{"id":1288445,"media_type":"movie","title":"Mutiny"},"#
            + #"{"id":108978,"media_type":"tv","name":"Reacher"}]}"#
        let template = SiteSearchAnalysis.titleTemplate(
            jsonBodies: [trending],
            routes: ["/watch/movie/1288445", "/watch/tv/108978"],
            host: "67movies.nl"
        )
        XCTAssertEqual(template, "https://67movies.nl/watch/{r.media_type}/{r.id}")
    }

    func testTitleTemplateNeedsTwoAgreeingLinks() {
        // One coincidental match must not invent a pattern.
        let trending = #"{"results":[{"id":1288445,"media_type":"movie"}]}"#
        XCTAssertNil(SiteSearchAnalysis.titleTemplate(
            jsonBodies: [trending], routes: ["/watch/movie/1288445"], host: "67movies.nl"
        ))
    }

    func testTitleTemplateIgnoresForeignHostRoutes() {
        let trending = #"{"results":[{"id":1,"media_type":"movie"},{"id":2,"media_type":"tv"}]}"#
        XCTAssertNil(SiteSearchAnalysis.titleTemplate(
            jsonBodies: [trending],
            routes: ["https://cdn.example/watch/movie/1", "https://cdn.example/watch/tv/2"],
            host: "67movies.nl"
        ))
    }

    func testFillBuildsTheTitleURLFromTheTopResult() {
        let json = #"{"page":1,"results":[{"id":1418,"media_type":"tv","name":"The Big Bang Theory"}]}"#
        let top = SiteSearchAnalysis.firstResultsArray(inJSON: json)?.first
        XCTAssertNotNil(top)
        XCTAssertEqual(
            SiteSearchAnalysis.fill(
                titleTemplate: "https://67movies.nl/watch/{r.media_type}/{r.id}", result: top!
            ),
            "https://67movies.nl/watch/tv/1418"
        )
    }

    func testFillFailsWhenAFieldIsMissing() {
        XCTAssertNil(SiteSearchAnalysis.fill(
            titleTemplate: "https://site.example/watch/{r.media_type}/{r.id}",
            result: ["id": 42]
        ))
    }

    func testFirstResultsArrayFindsNestedLists() {
        XCTAssertEqual(
            SiteSearchAnalysis.firstResultsArray(
                inJSON: #"{"data":{"hits":[{"id":7,"name":"Seven"}]},"total":1}"#
            )?.count,
            1
        )
        XCTAssertEqual(SiteSearchAnalysis.firstResultsArray(inJSON: #"{"results":[]}"#)?.count, nil)
        XCTAssertNil(SiteSearchAnalysis.firstResultsArray(inJSON: "not json"))
    }

    func testPageTemplateFromNavigation() {
        XCTAssertEqual(
            SiteSearchAnalysis.pageTemplate(
                finalURL: "https://site.example/search?q=Interstellar",
                homepage: URL(string: "https://site.example")!,
                probeQuery: "Interstellar"
            ),
            "https://site.example/search?q={query}"
        )
        // Staying on the homepage teaches nothing.
        XCTAssertNil(SiteSearchAnalysis.pageTemplate(
            finalURL: "https://site.example/",
            homepage: URL(string: "https://site.example")!,
            probeQuery: "Interstellar"
        ))
        // A navigation off-site is not this site's search.
        XCTAssertNil(SiteSearchAnalysis.pageTemplate(
            finalURL: "https://elsewhere.example/search?q=Interstellar",
            homepage: URL(string: "https://site.example")!,
            probeQuery: "Interstellar"
        ))
    }
}

final class SearchTemplateVerifierTests: XCTestCase {
    private let chrome = "Home Movies TV Shows Trending My List Login Terms Privacy DMCA Footer"

    func testEchoOfNonsenseQueryPassesEvenWithoutTheProbeFilm() {
        // A niche site without the probe film still passes because it echoes
        // whatever was searched.
        let probe = "\(chrome) No results found for Interstellar"
        let control = "\(chrome) No results found for \(SearchTemplateVerifier.controlQuery)"
        XCTAssertTrue(SearchTemplateVerifier.searchWorks(probeText: probe, controlText: control))
    }

    func testProbeFilmRenderingOnlyForRealSearchPasses() {
        let probe = "\(chrome) Interstellar 2014 Sci-Fi"
        let control = "\(chrome) Nothing matched your search"
        XCTAssertTrue(SearchTemplateVerifier.searchWorks(probeText: probe, controlText: control))
    }

    func testIdenticalDefaultContentForBothQueriesFails() {
        // The 1shows ?q= bug: parameter ignored, same default page each time.
        let junk = "\(chrome) Trending Now Breaking Bad Interstellar Wednesday The Boys"
        XCTAssertFalse(SearchTemplateVerifier.searchWorks(probeText: junk, controlText: junk))
    }

    func testSubstantiallyDifferentPagesPassWithoutEchoOrFilm() {
        // Site with neither the film nor an echo: a real search still swaps
        // most of the page content compared to a no-results page.
        let probe = "\(chrome) Space Odyssey Gravity Moon Sunshine Arrival Contact Apollo Thirteen First Man Ad Astra Proxima Stowaway"
        let control = "\(chrome) Nothing here"
        XCTAssertTrue(SearchTemplateVerifier.searchWorks(probeText: probe, controlText: control))
        XCTAssertTrue(SearchTemplateVerifier.substantiallyDifferent(probe, control))
    }

    func testEmptyPagesFail() {
        XCTAssertFalse(SearchTemplateVerifier.searchWorks(probeText: "", controlText: ""))
    }
}

final class LinkCheckerTests: XCTestCase {
    func testChecksRunEveryTwoDaysAsAdvertised() {
        XCTAssertEqual(LinkChecker.checkInterval, 2 * 24 * 60 * 60)
    }

    func testReachabilityClassification() {
        XCTAssertTrue(LinkChecker.isReachable(statusCode: 200))
        XCTAssertTrue(LinkChecker.isReachable(statusCode: 301))
        // Auth walls and bot blockers still prove the site is alive.
        XCTAssertTrue(LinkChecker.isReachable(statusCode: 403))
        XCTAssertTrue(LinkChecker.isReachable(statusCode: 429))
        XCTAssertFalse(LinkChecker.isReachable(statusCode: 404))
        XCTAssertFalse(LinkChecker.isReachable(statusCode: 410))
        XCTAssertFalse(LinkChecker.isReachable(statusCode: 503))
    }

    func testTargetsCoverServicesAndCustomSites() {
        let site = CustomMediaSite(name: "Flicky", urlString: "https://flickystream.dad")
        let targets = LinkChecker.targets(services: StreamingService.all, customSites: [site])
        XCTAssertEqual(targets.count, StreamingService.all.count + 1)
        XCTAssertTrue(targets.contains { $0.url.absoluteString == "https://www.netflix.com" })
        XCTAssertTrue(targets.contains { $0.key == site.id.uuidString && $0.url.absoluteString == "https://flickystream.dad" })
    }
}

final class FocusProviderTests: XCTestCase {
    func testModeNameParsing() {
        XCTAssertEqual(FocusProvider.modeName(fromShortcut: "Focus: Do Not Disturb"), "Do Not Disturb")
        XCTAssertEqual(FocusProvider.modeName(fromShortcut: "focus: work"), "work")
        XCTAssertEqual(FocusProvider.modeName(fromShortcut: "  Focus: Off  "), "Off")
        XCTAssertNil(FocusProvider.modeName(fromShortcut: "Focus:"))
        XCTAssertNil(FocusProvider.modeName(fromShortcut: "Weather"))
        XCTAssertNil(FocusProvider.modeName(fromShortcut: "My Focus: Work"))
    }

    func testDNDAliasMatches() {
        let candidates = FocusProvider.candidates(for: "Do Not Disturb")
        let best = candidates.compactMap { Fuzzy.score(query: "dnd", candidate: $0) }.max()
        XCTAssertNotNil(best)
        XCTAssertGreaterThanOrEqual(best ?? 0, 0.65)
    }

    func testGenericFocusQueryMatchesEveryMode() {
        for mode in ["Work", "Sleep", "Off"] {
            let best = FocusProvider.candidates(for: mode)
                .compactMap { Fuzzy.score(query: "focus", candidate: $0) }.max()
            XCTAssertGreaterThanOrEqual(best ?? 0, 0.65, "mode \(mode) should match a bare focus query")
        }
    }

    func testSymbolMapping() {
        XCTAssertEqual(FocusProvider.symbol(for: "Do Not Disturb"), "moon.fill")
        XCTAssertEqual(FocusProvider.symbol(for: "Off"), "slash.circle.fill")
        XCTAssertEqual(FocusProvider.symbol(for: "Deep Work"), "briefcase.fill")
        XCTAssertEqual(FocusProvider.symbol(for: "Custom Thing"), "moon.fill")
    }

    func testBuiltInsMatchPlainDoNotDisturbQueries() {
        for query in ["do not disturb", "dnd", "do not", "focus"] {
            for command in FocusProvider.builtIns {
                let best = command.matchNames
                    .compactMap { Fuzzy.score(query: query, candidate: $0) }.max()
                XCTAssertGreaterThanOrEqual(
                    best ?? 0, 0.65,
                    "\(command.title) should match the query \(query)"
                )
            }
        }
    }

    func testDNDOnRanksAboveOffForBareQuery() {
        let on = FocusProvider.builtIns.first { $0.enabled }!
        let off = FocusProvider.builtIns.first { !$0.enabled }!
        for query in ["dnd", "do not disturb"] {
            let onScore = on.baseScore + (on.matchNames.compactMap { Fuzzy.score(query: query, candidate: $0) }.max() ?? 0) * 60
            let offScore = off.baseScore + (off.matchNames.compactMap { Fuzzy.score(query: query, candidate: $0) }.max() ?? 0) * 60
            XCTAssertGreaterThan(onScore, offScore)
        }
        // "dnd off" must surface only the off command.
        XCTAssertNil(on.matchNames.compactMap { Fuzzy.score(query: "dnd off", candidate: $0) }.max())
        XCTAssertNotNil(off.matchNames.compactMap { Fuzzy.score(query: "dnd off", candidate: $0) }.max())
    }

    func testGeneratedWorkflowPlist() throws {
        for enabled in [true, false] {
            let data = try FocusProvider.workflowData(enabled: enabled)
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
            let root = try XCTUnwrap(plist as? [String: Any])
            let actions = try XCTUnwrap(root["WFWorkflowActions"] as? [[String: Any]])
            XCTAssertEqual(actions.count, 1)
            XCTAssertEqual(actions[0]["WFWorkflowActionIdentifier"] as? String, "is.workflow.actions.dnd.set")
            let params = try XCTUnwrap(actions[0]["WFWorkflowActionParameters"] as? [String: Any])
            XCTAssertEqual(params["Enabled"] as? Int, enabled ? 1 : 0)
            let modes = try XCTUnwrap(params["FocusModes"] as? [String: Any])
            XCTAssertEqual(modes["Identifier"] as? String, "com.apple.donotdisturb.mode.default")
        }
    }
}

final class ConvertProviderTests: XCTestCase {
    func testParse() {
        let currency = ConvertProvider.parse("100 usd to gbp")
        XCTAssertEqual(currency?.value, 100)
        XCTAssertEqual(currency?.from, "usd")
        XCTAssertEqual(currency?.to, "gbp")

        let attached = ConvertProvider.parse("5km in miles")
        XCTAssertEqual(attached?.value, 5)
        XCTAssertEqual(attached?.from, "km")
        XCTAssertEqual(attached?.to, "miles")

        let symbol = ConvertProvider.parse("$100 in gbp")
        XCTAssertEqual(symbol?.from, "usd")

        XCTAssertNil(ConvertProvider.parse("hello world"))
        XCTAssertNil(ConvertProvider.parse("100 to gbp"))
    }

    func testUnitConversion() throws {
        let km = try XCTUnwrap(ConvertProvider.parse("5km in miles"))
        guard case .value(let miles, _, _)? = ConvertProvider.convert(km) else {
            return XCTFail("expected a value")
        }
        XCTAssertEqual(miles, 3.10686, accuracy: 0.001)

        let weight = try XCTUnwrap(ConvertProvider.parse("10 lb to kg"))
        guard case .value(let kg, _, _)? = ConvertProvider.convert(weight) else {
            return XCTFail("expected a value")
        }
        XCTAssertEqual(kg, 4.53592, accuracy: 0.001)
    }

    func testTemperature() throws {
        let parsed = try XCTUnwrap(ConvertProvider.parse("72f to c"))
        guard case .value(let celsius, let label, _)? = ConvertProvider.convert(parsed) else {
            return XCTFail("expected a value")
        }
        XCTAssertEqual(celsius, 22.222, accuracy: 0.01)
        XCTAssertEqual(label, "°C")

        let kelvin = try XCTUnwrap(ConvertProvider.parse("0c to k"))
        guard case .value(let k, _, _)? = ConvertProvider.convert(kelvin) else {
            return XCTFail("expected a value")
        }
        XCTAssertEqual(k, 273.15, accuracy: 0.01)
    }

    func testMismatchedDimensionsFail() throws {
        let parsed = try XCTUnwrap(ConvertProvider.parse("5 km to kg"))
        XCTAssertNil(ConvertProvider.convert(parsed))
    }
}

final class TimeProviderTests: XCTestCase {
    func testAliasAndIdentifierMatch() {
        XCTAssertEqual(TimeProvider.matches(for: "nyc").first, "America/New_York")
        XCTAssertEqual(TimeProvider.matches(for: "tokyo").first, "Asia/Tokyo")
        XCTAssertTrue(TimeProvider.matches(for: "zzzzz").isEmpty)
    }
}

final class ColorProviderTests: XCTestCase {
    func testHexParsing() {
        let color = ColorProvider.parse("#E02128")
        XCTAssertEqual(color?.red, 224)
        XCTAssertEqual(color?.green, 33)
        XCTAssertEqual(color?.blue, 40)
        XCTAssertEqual(color?.hex, "#E02128")

        let short = ColorProvider.parse("#f0a")
        XCTAssertEqual(short?.hex, "#FF00AA")

        XCTAssertNil(ColorProvider.parse("decade"))
        XCTAssertNil(ColorProvider.parse("#12345"))
    }

    func testRGBParsing() {
        let color = ColorProvider.parse("rgb(224, 33, 40)")
        XCTAssertEqual(color?.hex, "#E02128")
        XCTAssertNil(ColorProvider.parse("rgb(300, 0, 0)"))
    }

    func testHSL() {
        let white = ColorProvider.ParsedColor(red: 255, green: 255, blue: 255)
        XCTAssertEqual(white.hsl.lightness, 100)
        let red = ColorProvider.ParsedColor(red: 255, green: 0, blue: 0)
        XCTAssertEqual(red.hsl.hue, 0)
        XCTAssertEqual(red.hsl.saturation, 100)
    }
}

final class PasswordProviderTests: XCTestCase {
    func testParse() {
        XCTAssertEqual(PasswordProvider.parse("pw"), 20)
        XCTAssertEqual(PasswordProvider.parse("pw 24"), 24)
        XCTAssertEqual(PasswordProvider.parse("password 300"), 128)
        XCTAssertEqual(PasswordProvider.parse("pw 2"), 6)
        XCTAssertNil(PasswordProvider.parse("pwned"))
        XCTAssertNil(PasswordProvider.parse("passwords"))
    }

    func testGenerate() {
        let password = PasswordProvider.generate(length: 32, includeSymbols: true)
        XCTAssertEqual(password.count, 32)
        let simple = PasswordProvider.generate(length: 32, includeSymbols: false)
        XCTAssertTrue(simple.allSatisfy { $0.isLetter || $0.isNumber })
        XCTAssertNotEqual(
            PasswordProvider.generate(length: 32, includeSymbols: true),
            PasswordProvider.generate(length: 32, includeSymbols: true)
        )
    }
}

final class TimerParseTests: XCTestCase {
    func testDurations() {
        XCTAssertEqual(TimerCenter.parse("10m tea")?.seconds, 600)
        XCTAssertEqual(TimerCenter.parse("10m tea")?.label, "tea")
        XCTAssertEqual(TimerCenter.parse("1h30m pasta")?.seconds, 5400)
        XCTAssertEqual(TimerCenter.parse("90s")?.seconds, 90)
        XCTAssertEqual(TimerCenter.parse("90s")?.label, "Timer")
        XCTAssertEqual(TimerCenter.parse("10 laundry")?.seconds, 600)
        XCTAssertEqual(TimerCenter.parse("10 minutes laundry")?.seconds, 600)
        XCTAssertNil(TimerCenter.parse("tea"))
        XCTAssertNil(TimerCenter.parse(""))
    }
}

final class EmojiProviderTests: XCTestCase {
    func testSearch() {
        XCTAssertEqual(EmojiProvider.search("fire").first?.char, "🔥")
        XCTAssertTrue(EmojiProvider.search("heart").contains { $0.char == "❤️" })
        XCTAssertTrue(EmojiProvider.search("zzzzzz").isEmpty)
    }

    func testNoEmptyEntries() {
        for entry in EmojiProvider.entries {
            XCTAssertFalse(entry.name.isEmpty)
            XCTAssertFalse(entry.char.isEmpty)
        }
    }
}

final class FindMyProviderTests: XCTestCase {
    func testParseRecognizedPhrases() {
        XCTAssertEqual(FindMyProvider.parse("ping my iphone"), FindMyProvider.Parsed(term: "iphone"))
        XCTAssertEqual(FindMyProvider.parse("Ping AirPods"), FindMyProvider.Parsed(term: "airpods"))
        XCTAssertEqual(FindMyProvider.parse("find my keys"), FindMyProvider.Parsed(term: "keys"))
        XCTAssertEqual(FindMyProvider.parse("where is my ipad"), FindMyProvider.Parsed(term: "ipad"))
        XCTAssertEqual(FindMyProvider.parse("ping"), FindMyProvider.Parsed(term: nil))
        XCTAssertEqual(FindMyProvider.parse("ping my"), FindMyProvider.Parsed(term: nil))
    }

    func testParseRejectsOtherQueries() {
        XCTAssertNil(FindMyProvider.parse("pingpong"))
        XCTAssertNil(FindMyProvider.parse("find myself"))
        XCTAssertNil(FindMyProvider.parse("safari"))
        XCTAssertNil(FindMyProvider.parse("finder"))
    }

    func testKindMatching() {
        XCTAssertEqual(FindMyProvider.kindMatching("iphone")?.title, "iPhone")
        XCTAssertEqual(FindMyProvider.kindMatching("phone")?.title, "iPhone")
        XCTAssertEqual(FindMyProvider.kindMatching("airpods pro")?.title, "AirPods")
        XCTAssertEqual(FindMyProvider.kindMatching("macbook")?.title, "Mac")
        // A custom device name falls through to the literal search term.
        XCTAssertNil(FindMyProvider.kindMatching("tanush's keys"))
    }

    func testItemsFirst() {
        XCTAssertTrue(FindMyProvider.itemsFirst("keys"))
        XCTAssertTrue(FindMyProvider.itemsFirst("airtag"))
        XCTAssertFalse(FindMyProvider.itemsFirst("iphone"))
    }

    func testNormalization() {
        // Find My row labels use curly apostrophes; typed queries use straight ones.
        XCTAssertEqual(FindMyProvider.normalized("Tanush\u{2019}s Keys, Home , 9 min ago"),
                       "tanush's keys, home , 9 min ago")
        XCTAssertTrue(FindMyProvider.normalized("Tanush\u{2019}s iPhone")
            .contains(FindMyProvider.normalized("tanush's iphone")))
    }
}

final class ClipEntryTests: XCTestCase {
    func testHistorySavedBeforeScreenshotsStillDecodes() throws {
        // Old entries have no isScreenshot key at all.
        let old = #"[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","kind":"text","date":0,"value":"hello"}]"#
        let decoded = try JSONDecoder().decode([ClipEntry].self, from: Data(old.utf8))
        XCTAssertEqual(decoded.first?.value, "hello")
        XCTAssertFalse(decoded.first?.fromScreenshot ?? true)
    }

    func testScreenshotFlagRoundTrips() throws {
        let entry = ClipEntry(id: UUID(), kind: .file, date: Date(), value: "/tmp/shot.png", isScreenshot: true)
        let data = try JSONEncoder().encode([entry])
        let decoded = try JSONDecoder().decode([ClipEntry].self, from: data)
        XCTAssertTrue(decoded.first?.fromScreenshot ?? false)
    }
}

final class ThemeProviderTests: XCTestCase {
    func testSpideyTriggersSpiderManTheme() {
        for query in ["spidey", "spider", "spiderman", "Spider-Man", "spi"] {
            XCTAssertTrue(
                ThemeProvider.results(for: query).contains { $0.title.contains("Spider-Man") },
                "expected a Spider-Man theme row for \(query)"
            )
        }
    }

    func testBatTriggersBatmanTheme() {
        for query in ["the bat", "batman", "bat", "gotham", "dark knight"] {
            XCTAssertTrue(
                ThemeProvider.results(for: query).contains { $0.title.contains("Batman") },
                "expected a Batman theme row for \(query)"
            )
        }
    }

    func testOrdinaryQueriesDoNotOfferThemes() {
        for query in ["the", "the weeknd", "battery", "batman movie", "spider solitaire", "sp"] {
            XCTAssertTrue(
                ThemeProvider.results(for: query).isEmpty,
                "did not expect a theme row for \(query)"
            )
        }
    }
}
