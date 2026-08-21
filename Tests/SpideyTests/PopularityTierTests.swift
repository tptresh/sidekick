import XCTest
@testable import Spidey

// The popularity prior: typing a famous retailer or brand name means the
// website with far higher probability than a show title, so tiered site rows
// must outrank the "Watch ... on Netflix" streaming rows.
final class PopularityTierTests: XCTestCase {
    private var usageDirectory: URL!

    override func setUpWithError() throws {
        usageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PopularityTierTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: usageDirectory)
    }

    // A UsageStore with no history, isolated from the real usage.json.
    private func makeUsage() -> UsageStore {
        UsageStore(directory: usageDirectory)
    }

    // MARK: - Tier lookup

    func testTierAssignments() {
        XCTAssertEqual(SiteDirectoryProvider.tier(forName: "google"), 3)
        XCTAssertEqual(SiteDirectoryProvider.tier(forName: "best buy"), 3)
        XCTAssertEqual(SiteDirectoryProvider.tier(forName: "amazon"), 3)
        XCTAssertEqual(SiteDirectoryProvider.tier(forName: "cartier"), 2)
        XCTAssertEqual(SiteDirectoryProvider.tier(forName: "rimowa"), 2)
        XCTAssertEqual(SiteDirectoryProvider.tier(forName: "grand seiko"), 2)
        // Built-in but not curated into a set: tier 1.
        XCTAssertEqual(SiteDirectoryProvider.tier(forName: "hodinkee"), 1)
        XCTAssertEqual(SiteDirectoryProvider.tier(forName: "citymapper"), 1)
        // Unknown names (user sites.json entries): tier 0.
        XCTAssertEqual(SiteDirectoryProvider.tier(forName: "my cool blog"), 0)
        XCTAssertEqual(SiteDirectoryProvider.tier(forName: "flickystream"), 0)
    }

    func testEveryCuratedTierNameIsLowercase() {
        for name in SiteDirectoryProvider.tier3.union(SiteDirectoryProvider.tier2) {
            XCTAssertEqual(name, name.lowercased(), "\(name) must be lowercase to match directory keys")
        }
    }

    func testCuratedTiersDoNotOverlap() {
        XCTAssertTrue(SiteDirectoryProvider.tier3.intersection(SiteDirectoryProvider.tier2).isEmpty)
    }

    // MARK: - Matching

    func testSpaceInsensitiveMatching() {
        // "bestbuy" must strongly match the "best buy" directory entry.
        XCTAssertEqual(SiteDirectoryProvider.matchScore(query: "bestbuy", name: "best buy"), 1.0)
        XCTAssertEqual(SiteDirectoryProvider.matchScore(query: "best buy", name: "best buy"), 1.0)
        XCTAssertNil(SiteDirectoryProvider.matchScore(query: "zzzz", name: "best buy"))
    }

    func testStrongMatchRequiresExactOrDeliberatePrefix() {
        XCTAssertTrue(SiteDirectoryProvider.isStrongMatch(1.0, queryLength: 2))
        XCTAssertTrue(SiteDirectoryProvider.isStrongMatch(0.92, queryLength: 4))
        // Two-character prefixes are too ambiguous for the big boost.
        XCTAssertFalse(SiteDirectoryProvider.isStrongMatch(0.92, queryLength: 2))
        XCTAssertFalse(SiteDirectoryProvider.isStrongMatch(0.7, queryLength: 10))
    }

    func testPopularityTierMatchingQueries() {
        XCTAssertEqual(SiteDirectoryProvider.popularityTier(matching: "best buy"), 3)
        XCTAssertEqual(SiteDirectoryProvider.popularityTier(matching: "bestbuy"), 3)
        XCTAssertEqual(SiteDirectoryProvider.popularityTier(matching: "cartier"), 2)
        XCTAssertNil(SiteDirectoryProvider.popularityTier(matching: "dark crystal age of resistance"))
    }

    // MARK: - Score bands

    func testScoreBandsStayBelowKeywordCommands() {
        let tier3Exact = SiteDirectoryProvider.score(match: 1.0, tier: 3, queryLength: 7)
        let tier2Exact = SiteDirectoryProvider.score(match: 1.0, tier: 2, queryLength: 7)
        let tier1Exact = SiteDirectoryProvider.score(match: 1.0, tier: 1, queryLength: 7)
        // Static ceiling stays under keyword commands (~950-960), leaving
        // headroom for the engine's learned frecency boost on top.
        XCTAssertLessThanOrEqual(tier3Exact, 960)
        XCTAssertGreaterThan(tier3Exact, tier2Exact)
        XCTAssertGreaterThan(tier2Exact, tier1Exact)
        // Weak fuzzy matches never receive the tier boost.
        XCTAssertEqual(
            SiteDirectoryProvider.score(match: 0.7, tier: 3, queryLength: 7),
            SiteDirectoryProvider.score(match: 0.7, tier: 1, queryLength: 7)
        )
    }

    // MARK: - Site vs streaming ranking

    func testBestBuyOutranksStreamingRows() {
        for query in ["best buy", "bestbuy"] {
            let site = SiteDirectoryProvider.results(for: query)
                .first { $0.title == "Open Best Buy" }
            XCTAssertNotNil(site, "\(query) should surface the Best Buy site row")
            let siteScore = site?.score ?? 0
            XCTAssertGreaterThan(siteScore, 900)

            XCTAssertTrue(StreamingProvider.shouldDemoteShows(for: query))
            let watchRows = StreamingProvider.results(for: query, usage: makeUsage())
                .filter { $0.title.hasPrefix("Watch ") }
            for row in watchRows {
                XCTAssertLessThan(row.score, siteScore, "\(row.title) must rank below the site")
                XCTAssertLessThan(row.score, 100, "demoted rows sink below the Google fallback")
            }
        }
    }

    func testCartierOutranksStreamingRows() {
        let site = SiteDirectoryProvider.results(for: "cartier")
            .first { $0.title == "Open Cartier" }
        XCTAssertNotNil(site)
        XCTAssertGreaterThan(site?.score ?? 0, 830)
        XCTAssertTrue(StreamingProvider.shouldDemoteShows(for: "cartier"))
        for row in StreamingProvider.results(for: "cartier", usage: makeUsage()) where row.title.hasPrefix("Watch ") {
            XCTAssertLessThan(row.score, site?.score ?? 0)
        }
    }

    func testObscureShowQueriesKeepNormalStreamingRank() {
        XCTAssertFalse(StreamingProvider.shouldDemoteShows(for: "dark crystal age of resistance"))
        let rows = StreamingProvider.results(for: "dark crystal age of resistance", usage: makeUsage())
            .filter { $0.title.hasPrefix("Watch ") }
        if let top = rows.map(\.score).max() {
            XCTAssertEqual(top, 200, accuracy: 0.001)
        }
    }

    func testShowLikeQueriesEscapeDemotionEvenOnBrandMatch() {
        // Media words or long phrases read as titles, not site names.
        XCTAssertTrue(StreamingProvider.looksShowLike("target season 2"))
        XCTAssertTrue(StreamingProvider.looksShowLike("the grand seiko documentary"))
        XCTAssertFalse(StreamingProvider.looksShowLike("best buy"))
        XCTAssertFalse(StreamingProvider.looksShowLike("cartier"))
        XCTAssertFalse(StreamingProvider.shouldDemoteShows(for: "target season 2"))
    }

    // MARK: - Learned ranking keys and demotion rescue

    func testSiteAndStreamRowsCarryRankingKeys() {
        let site = SiteDirectoryProvider.results(for: "cartier")
            .first { $0.title == "Open Cartier" }
        XCTAssertEqual(site?.rankingKey, "site:www.cartier.com")

        let watchRows = StreamingProvider.results(for: "dark crystal age of resistance", usage: makeUsage())
            .filter { $0.title.hasPrefix("Watch ") }
        XCTAssertFalse(watchRows.isEmpty)
        for row in watchRows {
            XCTAssertEqual(row.rankingKey?.hasPrefix("stream:"), true)
        }
    }

    func testRescueThresholdOutOfGlobalBoostReach() {
        // Global-only usage (no query association) can never cancel a demotion.
        XCTAssertFalse(StreamingProvider.rescuesDemotion(boost: UsageStore.maxGlobalBoost))
        XCTAssertTrue(StreamingProvider.rescuesDemotion(boost: StreamingProvider.rescueBoostThreshold))
    }

    func testLearnedAssociationRescuesDemotedService() {
        let usage = makeUsage()
        // Two picks just now: association boost ~185, past the rescue threshold.
        usage.recordSelection(query: "cartier", rankingKey: "stream:netflix")
        usage.recordSelection(query: "cartier", rankingKey: "stream:netflix")

        XCTAssertTrue(StreamingProvider.shouldDemoteShows(for: "cartier"))
        let rows = StreamingProvider.results(for: "cartier", usage: usage)
            .filter { $0.title.hasPrefix("Watch ") }
        let netflix = rows.first { $0.rankingKey == "stream:netflix" }
        XCTAssertNotNil(netflix, "netflix row should be present")
        XCTAssertGreaterThan(netflix?.score ?? 0, 100, "habitual service keeps its normal rank")
        for row in rows where row.rankingKey != "stream:netflix" {
            XCTAssertLessThan(row.score, 100, "other services stay demoted")
        }

        // Even with the engine's maximum learned boost on top, the rescued row
        // stays below the strongly matched tier-2 site row (documented ceiling).
        let site = SiteDirectoryProvider.results(for: "cartier")
            .first { $0.title == "Open Cartier" }
        XCTAssertGreaterThan(
            site?.score ?? 0,
            (netflix?.score ?? 0) + UsageStore.maxAssociationBoost
        )
    }

    func testTierOneSitesDoNotDemoteStreaming() {
        // hodinkee is built-in but tier 1: a plausible-but-niche name should
        // not push show rows down.
        XCTAssertFalse(StreamingProvider.shouldDemoteShows(for: "hodinkee"))
    }

    func testDirectoryHasURLForEveryCuratedBuiltInTier() {
        // Guard against typos: curated names either exist in the built-in
        // directory or are known external names handled elsewhere
        // (MediaProvider homepages, streaming services, user sites).
        let handledElsewhere: Set<String> = ["netflix", "youtube", "crunchyroll", "hulu"]
        for name in SiteDirectoryProvider.tier3.union(SiteDirectoryProvider.tier2) {
            XCTAssertTrue(
                SiteDirectoryProvider.builtIn[name] != nil || handledElsewhere.contains(name),
                "curated tier name \(name) has no URL in the built-in directory"
            )
        }
    }
}
