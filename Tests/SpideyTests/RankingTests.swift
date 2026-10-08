import XCTest
@testable import Spidey

// Score bands that decide what shows first: intent rows (calculator,
// conversions) on top, then exact apps, then websites and fuzzy commands.
final class RankingTests: XCTestCase {
    func testCurrencyPairWithoutAmountMeansOne() throws {
        let parsed = try XCTUnwrap(ConvertProvider.parse("usd to gbp"))
        XCTAssertEqual(parsed.value, 1)
        XCTAssertEqual(parsed.from, "usd")
        XCTAssertEqual(parsed.to, "gbp")
        XCTAssertEqual(try XCTUnwrap(ConvertProvider.parse("km in miles")).value, 1)
    }

    func testOrdinaryPhrasesAreNotConversions() {
        for query in ["back to school", "time in tokyo", "welcome to the jungle", "go to bed"] {
            XCTAssertNil(ConvertProvider.parse(query), query)
        }
    }

    func testExactAppBeatsPopularWebsite() {
        let site = SiteDirectoryProvider.score(match: 1.0, tier: 3, queryLength: 7)
        XCTAssertGreaterThan(AppProvider.score(forMatch: 1.0), site)
        // Intent rows still win over any app.
        XCTAssertLessThan(AppProvider.score(forMatch: 1.0), 985)
    }

    func testPartialCommandMatchesDoNotBeatAppPrefixes() {
        let appPrefix = AppProvider.score(forMatch: 0.92)
        XCTAssertLessThan(ToggleProvider.score(exact: false), appPrefix)
        XCTAssertLessThan(WindowProvider.score(forMatch: 0.92), appPrefix)
        XCTAssertGreaterThanOrEqual(ToggleProvider.score(exact: true), 950)
        XCTAssertGreaterThanOrEqual(WindowProvider.score(forMatch: 1.0), 950)
    }

    func testLearnedBoostNeverLiftsAboveIntentRows() {
        XCTAssertLessThan(UsageStore.boostedScore(base: 960, boost: 350), 985)
        XCTAssertGreaterThan(UsageStore.boostedScore(base: 876, boost: 100), 876)
        // Resume-watching rows live above the intent band and keep their boost.
        XCTAssertEqual(UsageStore.boostedScore(base: 1300, boost: 50), 1350)
    }

    func testTypedAddressOpensThatSite() {
        XCTAssertEqual(SiteDirectoryProvider.typedAddress("github.com")?.absoluteString, "https://github.com")
        XCTAssertEqual(
            SiteDirectoryProvider.typedAddress("https://news.ycombinator.com/item?id=1")?.absoluteString,
            "https://news.ycombinator.com/item?id=1"
        )
        XCTAssertEqual(SiteDirectoryProvider.typedAddress("bbc.co.uk")?.host, "bbc.co.uk")
        for query in ["hello world", "2.5", "notes.txt", "report.pdf", "github"] {
            XCTAssertNil(SiteDirectoryProvider.typedAddress(query), query)
        }
        XCTAssertNil(SiteDirectoryProvider.guessResult(for: "github.com"))
    }
}
