import XCTest
@testable import Spidey

// Everyday queries run through the real engine, checking what lands first.
// The app list is stubbed and learned ranking uses an empty store, so the
// answers do not depend on what this Mac has installed or has been used for.
// Rows that need a permission (Accessibility, Calendar) are matched on the
// words they always carry, granted or not.
final class SearchQueryRegressionTests: XCTestCase {
    static let appNames = [
        "Safari", "Google Chrome", "Notes", "Visual Studio Code", "Mail", "Messages", "Calendar",
        "Spotify", "Finder", "Terminal", "System Settings", "Music", "TV", "Photos", "Slack",
        "Brave Browser", "Preview", "Calculator", "Reminders", "Find My", "Activity Monitor",
        "Xcode", "Clock", "Weather", "Maps", "Notion", "Zoom", "WhatsApp", "Discord", "Obsidian",
    ]

    private var model: SpideyViewModel!

    override func setUp() {
        super.setUp()
        AppProvider.shared.appsOverride = Self.appNames.map {
            AppProvider.AppEntry(
                name: $0, url: URL(fileURLWithPath: "/Applications/\($0).app"),
                bundleID: "test.\($0.lowercased())", aliases: []
            )
        }
        model = SpideyViewModel()
        model.usageStore = UsageStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
    }

    override func tearDown() {
        AppProvider.shared.appsOverride = nil
        model = nil
        super.tearDown()
    }

    private func results(_ query: String) -> [ResultItem] {
        model.query = query
        return model.results
    }

    private func contains(_ text: String) -> (ResultItem) -> Bool {
        { $0.title.localizedCaseInsensitiveContains(text) }
    }

    private func titled(_ text: String) -> (ResultItem) -> Bool {
        { $0.title == text }
    }

    // (query, what the first row must satisfy, a label for the failure)
    private var cases: [(String, (ResultItem) -> Bool, String)] {
        [
            // Apps
            ("safari", titled("Safari"), "Safari app"),
            ("chrome", titled("Google Chrome"), "Chrome app"),
            ("notes", titled("Notes"), "Notes app"),
            ("vs code", titled("Visual Studio Code"), "VS Code app"),
            ("vscode", titled("Visual Studio Code"), "VS Code app"),
            ("mail", titled("Mail"), "Mail app"),
            ("messages", titled("Messages"), "Messages app"),
            ("calendar", titled("Calendar"), "Calendar app"),
            ("spotify", titled("Spotify"), "Spotify app"),
            ("terminal", titled("Terminal"), "Terminal app"),
            ("settings", titled("System Settings"), "System Settings app"),
            ("slack", titled("Slack"), "Slack app"),
            ("xcode", titled("Xcode"), "Xcode app"),
            ("zoom", titled("Zoom"), "Zoom app"),
            ("music", titled("Music"), "Music app"),
            ("maps", titled("Maps"), "Maps app"),
            ("find my", titled("Find My"), "Find My app"),
            ("whatsapp", titled("WhatsApp"), "WhatsApp app"),
            // Commands
            ("timer 10m tea", contains("timer"), "timer"),
            ("set a timer for 5 minutes", contains("timer"), "phrased timer"),
            ("ping my iphone", contains("iPhone"), "ping iPhone"),
            ("dnd", contains("Do Not Disturb"), "Focus"),
            ("do not disturb", contains("Do Not Disturb"), "Focus"),
            ("left half", contains("Left Half"), "window snap"),
            ("maximize", contains("Maximize"), "window snap"),
            ("100 usd to gbp", contains("GBP"), "currency"),
            ("5km in miles", contains("miles"), "units"),
            ("72f to c", contains("°C"), "temperature"),
            ("2+2*5", titled("= 12"), "calculator"),
            ("(3+4)/2", titled("= 3.5"), "calculator"),
            ("time in tokyo", contains("Tokyo"), "world clock"),
            ("tokyo time", contains("Tokyo"), "world clock"),
            ("define word", contains("Define"), "dictionary"),
            ("spell necessary", titled("necessary"), "spelling of a correct word"),
            ("emoji fire", contains("Fire"), "emoji"),
            ("#E02128", titled("#E02128"), "color"),
            ("lock", titled("Lock Screen"), "lock"),
            ("empty trash", titled("Empty Trash"), "trash"),
            ("dark mode", contains("Mode"), "appearance toggle"),
            ("wifi", contains("Wi-Fi"), "wifi toggle"),
            ("volume 50", contains("Volume"), "volume"),
            ("mute", titled("Mute"), "mute"),
            ("battery", contains("%"), "battery"),
            ("play", { !$0.title.localizedCaseInsensitiveContains("playstation") }, "music command over site prefix"),
            ("today", contains("event"), "calendar today"),
            ("amazon death note manga", contains("Search Amazon"), "amazon keyword"),
            ("google cats", titled("Search Google for \"cats\""), "google keyword"),
            ("wiki mars", contains("Wikipedia"), "wiki keyword"),
            ("github.com", titled("Open github.com"), "typed address"),
            ("qr hello", contains("QR code"), "qr"),
            ("large hello", contains("large type"), "large type"),
            ("b64 hello", titled("aGVsbG8="), "base64"),
            ("sha256 abc", { $0.title.hasPrefix("ba7816bf") }, "sha256"),
            ("uuid", { UUID(uuidString: $0.title) != nil }, "uuid"),
            ("pw", { $0.title.count == 20 }, "password"),
            ("pw 24", { $0.title.count == 24 }, "password length"),
            ("clip", { $0.subtitle.contains("Return copies") || $0.title.contains("empty") }, "clipboard"),
            ("snip", contains("snippet"), "snippets"),
            ("claude fix the bug", contains("Claude Code"), "claude"),
            ("caffeinate", contains("Awake"), "caffeinate"),
            ("youtube lofi beats", contains("Search YouTube"), "youtube search"),
            ("youtube", titled("Open YouTube"), "youtube home"),
            ("netflix", titled("Open Netflix"), "netflix home"),
            ("vinted", titled("Open Vinted"), "site directory"),
            ("best buy", titled("Open Best Buy"), "popular site"),
            ("cartier", titled("Open Cartier"), "popular brand"),
            ("the pitt", contains("the pitt"), "show search"),
            ("breaking bad", contains("breaking bad"), "show search"),
        ]
    }

    func testEverydayQueriesPutTheRightRowFirst() {
        var failures: [String] = []
        for (query, check, label) in cases {
            let first = results(query).first
            if let first, check(first) { continue }
            failures.append("\(query) [\(label)] got \(first?.title ?? "nothing")")
        }
        let total = cases.count
        print("SEARCH QUERY PASS RATE: \(total - failures.count)/\(total)")
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    // A recognised keyword is the whole answer; show-search rows for it are noise.
    func testKeywordQueriesDoNotOfferShowSearches() {
        for query in ["win mail", "bm news", "github.com", "https://bbc.co.uk/news"] {
            let watchRows = results(query).filter { $0.title.hasPrefix("Watch \"") }
            XCTAssertTrue(watchRows.isEmpty, "\(query): \(watchRows.map(\.title))")
        }
    }

    // Odd input must never crash and must never leave the list in a bad state.
    func testOddInputDoesNotCrash() {
        let long = String(repeating: "a", count: 2_000)
        let odd = [
            "", " ", "   ", "\t", "😀", "👨‍👩‍👧‍👦 family", "ñandú", "日本語", long, String(repeating: "(", count: 200),
            "1/0", "-", "%", "+", "time in ", "define ", "spell ", "pw -5", "pw 999999999999999999999",
            "qr ", "emoji ", "#", "rgb(", "ts 99999999999999999999", "b64d !!!", "100 usd to", "5 to 6",
            "timer 0m", "volume 999", "find ", "in ", "clip ", "bm ", "win ", "youtube ", "google ",
            "watching s99e99", "define 😀", "spell 😀", "time in 😀", "1e308*10", "9999999999999999999*9",
            "http://", "https://", ".com", "a.b", "...", "\"", "\\", "*", "%%%",
        ]
        for query in odd {
            let items = results(query)
            XCTAssertTrue(items.allSatisfy { $0.score.isFinite }, query)
            XCTAssertTrue(model.selectedIndex == 0 || model.results.indices.contains(model.selectedIndex), query)
        }
        XCTAssertTrue(results("   ").isEmpty)
    }
}

final class SearchHomepageGuessTests: XCTestCase {
    // A guess like www.ñandú.com shows up as unreadable punycode
    // (www.xn--and-6ma2c.com), so only plain ASCII names get a guess.
    func testNonLatinNamesGetNoHomepageGuess() {
        XCTAssertNil(SiteDirectoryProvider.guessResult(for: "ñandú"))
        XCTAssertNil(SiteDirectoryProvider.guessResult(for: "日本語"))
        XCTAssertEqual(SiteDirectoryProvider.guessResult(for: "grand seikoo")?.title, "Open www.grandseikoo.com")
    }
}
