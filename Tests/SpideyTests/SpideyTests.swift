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
