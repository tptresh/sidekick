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
}
