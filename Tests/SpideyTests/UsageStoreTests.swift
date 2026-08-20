import XCTest
@testable import Spidey

final class UsageStoreFrecencyTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testRecencyBuckets() {
        // Within the hour x4, today x2, this week x1, older x0.5.
        XCTAssertEqual(UsageStore.frecency(count: 3, lastUsed: now.addingTimeInterval(-60), now: now), 12)
        XCTAssertEqual(UsageStore.frecency(count: 3, lastUsed: now.addingTimeInterval(-7_200), now: now), 6)
        XCTAssertEqual(UsageStore.frecency(count: 3, lastUsed: now.addingTimeInterval(-2 * 86_400), now: now), 3)
        XCTAssertEqual(UsageStore.frecency(count: 3, lastUsed: now.addingTimeInterval(-30 * 86_400), now: now), 1.5)
        XCTAssertEqual(UsageStore.frecency(count: 0, lastUsed: now, now: now), 0)
    }

    func testBoostCurveSaturatesBelowCeiling() {
        XCTAssertEqual(UsageStore.boost(frecency: 0, ceiling: 300, halfPoint: 5), 0)
        XCTAssertEqual(UsageStore.boost(frecency: 5, ceiling: 300, halfPoint: 5), 150)
        let single = UsageStore.boost(frecency: 4, ceiling: 300, halfPoint: 5)
        let habitual = UsageStore.boost(frecency: 40, ceiling: 300, halfPoint: 5)
        XCTAssertGreaterThan(habitual, single)
        XCTAssertLessThan(habitual, 300)
        XCTAssertGreaterThan(habitual, 250, "a habitual pick should approach full strength")
    }

    func testMatchQuality() {
        XCTAssertEqual(UsageStore.matchQuality(stored: "chr", typed: "chr"), 1.0)
        XCTAssertEqual(UsageStore.matchQuality(stored: "chr", typed: "c"), UsageStore.prefixMatchFactor)
        XCTAssertEqual(UsageStore.matchQuality(stored: "chr", typed: "chrome"), UsageStore.prefixMatchFactor)
        XCTAssertNil(UsageStore.matchQuality(stored: "chr", typed: "safari"))
        XCTAssertNil(UsageStore.matchQuality(stored: "", typed: "chr"))
    }
}

final class UsageStoreLookupTests: XCTestCase {
    var tempDir: URL!
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("spidey-usage-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testAssociationBoostBeatsGlobalAndDecaysForPrefix() {
        let store = UsageStore(directory: tempDir)
        store.recordSelection(query: "Chr", rankingKey: "app:com.google.Chrome", now: now.addingTimeInterval(-120))
        store.recordSelection(query: "chr", rankingKey: "app:com.google.Chrome", now: now.addingTimeInterval(-60))

        let exact = store.boosts(for: "chr", now: now)["app:com.google.Chrome"] ?? 0
        let prefix = store.boosts(for: "c", now: now)["app:com.google.Chrome"] ?? 0
        let unrelated = store.boosts(for: "safari", now: now)["app:com.google.Chrome"] ?? 0

        // Two selections within the hour: frecency 8 -> assoc ~184, + global.
        XCTAssertGreaterThan(exact, 150)
        XCTAssertLessThanOrEqual(exact, UsageStore.maxAssociationBoost)
        XCTAssertGreaterThan(exact, prefix, "prefix-only match earns a discounted boost")
        XCTAssertGreaterThan(prefix, unrelated)
        // Unrelated query still gets the small global prior, never more.
        XCTAssertGreaterThan(unrelated, 0)
        XCTAssertLessThanOrEqual(unrelated, UsageStore.maxGlobalBoost)
    }

    func testRepeatedSelectionsCanOutrankStaticScores() {
        let store = UsageStore(directory: tempDir)
        for i in 0..<10 {
            store.recordSelection(query: "note", rankingKey: "app:com.apple.Notes", now: now.addingTimeInterval(Double(-i * 60)))
        }
        let boost = store.boosts(for: "note", now: now)["app:com.apple.Notes"] ?? 0
        // A mid-list app (600 + 0.82*300 = 846) plus this boost must clear a
        // perfect static competitor (900).
        XCTAssertGreaterThan(846 + boost, 900)
        XCTAssertLessThanOrEqual(boost, UsageStore.maxAssociationBoost)
    }

    func testOldSelectionsFade() {
        let store = UsageStore(directory: tempDir)
        store.recordSelection(query: "mail", rankingKey: "app:com.apple.mail", now: now.addingTimeInterval(-30 * 86_400))
        let stale = store.boosts(for: "mail", now: now)["app:com.apple.mail"] ?? 0
        store.recordSelection(query: "mail", rankingKey: "app:com.apple.mail", now: now.addingTimeInterval(-60))
        let fresh = store.boosts(for: "mail", now: now)["app:com.apple.mail"] ?? 0
        XCTAssertGreaterThan(fresh, stale)
        XCTAssertGreaterThan(stale, 0, "old history decays but is not forgotten")
    }

    func testEmptyQueryLearnsNothingAndBoostsNothing() {
        let store = UsageStore(directory: tempDir)
        store.recordSelection(query: "   ", rankingKey: "app:x", now: now)
        XCTAssertTrue(store.boosts(for: "", now: now).isEmpty)
        // The whitespace query recorded only global usage, no association.
        XCTAssertLessThanOrEqual(store.boosts(for: "x", now: now)["app:x"] ?? 0, UsageStore.maxGlobalBoost)
    }

    func testPersistenceAcrossInstances() {
        let first = UsageStore(directory: tempDir)
        first.recordSelection(query: "term", rankingKey: "app:com.apple.Terminal", now: now.addingTimeInterval(-60))
        let second = UsageStore(directory: tempDir)
        let boost = second.boosts(for: "term", now: now)["app:com.apple.Terminal"] ?? 0
        XCTAssertGreaterThan(boost, 100)
    }

    func testAssociationCapPrunesLeastRecent() {
        let store = UsageStore(directory: tempDir)
        for i in 0..<(UsageStore.maxAssociations + 20) {
            store.recordSelection(query: "q\(i)", rankingKey: "key\(i)", now: now.addingTimeInterval(Double(i)))
        }
        // The oldest associations are gone, the newest survive.
        XCTAssertTrue(store.boosts(for: "q0", now: now.addingTimeInterval(600)).isEmpty
            || (store.boosts(for: "q0", now: now.addingTimeInterval(600))["key0"] ?? 0) <= UsageStore.maxGlobalBoost)
        let newest = "q\(UsageStore.maxAssociations + 19)"
        let newestKey = "key\(UsageStore.maxAssociations + 19)"
        XCTAssertGreaterThan(store.boosts(for: newest, now: now.addingTimeInterval(600))[newestKey] ?? 0, 100)
        // The persisted file honors the cap too.
        let data = try! Data(contentsOf: tempDir.appendingPathComponent("usage.json"))
        let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let associations = json["associations"] as! [[String: Any]]
        XCTAssertLessThanOrEqual(associations.count, UsageStore.maxAssociations)
        let global = json["global"] as! [String: Any]
        XCTAssertLessThanOrEqual(global.count, UsageStore.maxGlobalKeys)
    }
}

final class AppAliasTests: XCTestCase {
    func testParseUserAliases() {
        let data = #"{"ps": "Photoshop", " VS ": " Visual Studio Code ", "": "x", "bad": ""}"#.data(using: .utf8)!
        let parsed = AppProvider.parseUserAliases(data)
        XCTAssertEqual(parsed, ["ps": "Photoshop", "vs": "Visual Studio Code"])
        XCTAssertEqual(AppProvider.parseUserAliases(Data("not json".utf8)), [:])
    }

    func testAliasScoresAsExactMatch() {
        // "ps" alone barely matches "Adobe Photoshop 2024" (subsequence), but
        // with the alias pointing at "Photoshop" it becomes an exact match.
        let plain = AppProvider.effectiveMatch(
            query: "ps", aliasTarget: nil, name: "Adobe Photoshop 2024", aliases: []
        )
        let aliased = AppProvider.effectiveMatch(
            query: "ps", aliasTarget: "Photoshop", name: "Adobe Photoshop 2024", aliases: []
        )
        XCTAssertEqual(aliased, 1.0)
        XCTAssertLessThan(plain ?? 0, 1.0)
        // The alias does not lift apps its target doesn't match.
        let other = AppProvider.effectiveMatch(
            query: "ps", aliasTarget: "Photoshop", name: "Pages", aliases: []
        )
        XCTAssertNotEqual(other, 1.0)
    }
}
