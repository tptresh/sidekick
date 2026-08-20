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

final class ClaudeProviderTests: XCTestCase {
    func testShellEscaping() {
        XCTAssertEqual(ClaudeProvider.shellEscape("simple"), "'simple'")
        XCTAssertEqual(ClaudeProvider.shellEscape("it's here"), "'it'\\''s here'")
    }

    func testShellCommand() {
        let command = ClaudeProvider.shellCommand(
            prompt: "fix the spelling issue", directory: "/Users/me/project"
        )
        XCTAssertEqual(command, "cd '/Users/me/project' && claude 'fix the spelling issue'")
    }

    func testAppleScriptEscaping() {
        XCTAssertEqual(ClaudeProvider.appleScriptEscape("say \"hi\""), "say \\\"hi\\\"")
        XCTAssertEqual(ClaudeProvider.appleScriptEscape("back\\slash"), "back\\\\slash")
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
    }

    func testNoEmDashInBuiltInSites() {
        for (name, url) in SiteDirectoryProvider.builtIn {
            XCTAssertFalse(name.contains("\u{2014}"))
            XCTAssertFalse(url.contains("\u{2014}"))
        }
    }
}
