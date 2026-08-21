import XCTest
@testable import Spidey

final class SnippetStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnippetTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testRoundTrip() {
        let store = SnippetStore(directory: directory)
        store.add(keyword: "addr", content: "123 Main Street,\nSpringfield")
        store.add(keyword: "sig", content: "Best, Tanush")

        // A fresh instance re-reads the same file from disk.
        let reloaded = SnippetStore(directory: directory)
        XCTAssertEqual(reloaded.snippets.count, 2)
        XCTAssertEqual(reloaded.snippet(forKeyword: "addr")?.content, "123 Main Street,\nSpringfield")
        XCTAssertEqual(reloaded.snippet(forKeyword: "sig")?.content, "Best, Tanush")
    }

    func testKeywordsAreCaseInsensitive() {
        let store = SnippetStore(directory: directory)
        store.add(keyword: "Addr", content: "somewhere")
        XCTAssertEqual(store.snippet(forKeyword: "ADDR")?.content, "somewhere")
        XCTAssertEqual(store.snippets.first?.keyword, "addr")
    }

    func testReAddingReplacesAndRemoveDeletes() {
        let store = SnippetStore(directory: directory)
        store.add(keyword: "addr", content: "old")
        store.add(keyword: "addr", content: "new")
        XCTAssertEqual(store.snippets.count, 1)
        XCTAssertEqual(store.snippet(forKeyword: "addr")?.content, "new")

        store.remove(keyword: "ADDR")
        XCTAssertTrue(store.snippets.isEmpty)
        XCTAssertTrue(SnippetStore(directory: directory).snippets.isEmpty)
    }

    func testMissingFileLoadsEmpty() {
        XCTAssertTrue(SnippetStore(directory: directory).snippets.isEmpty)
    }
}

final class SnippetProviderTests: XCTestCase {
    func testParseList() {
        XCTAssertEqual(SnippetProvider.parse("snip"), .list(filter: ""))
        XCTAssertEqual(SnippetProvider.parse("snippets"), .list(filter: ""))
        XCTAssertEqual(SnippetProvider.parse("snip addr"), .list(filter: "addr"))
        XCTAssertEqual(SnippetProvider.parse("Snippets home addr"), .list(filter: "home addr"))
    }

    func testParseAdd() {
        XCTAssertEqual(
            SnippetProvider.parse("snip add addr 123 Main Street, Springfield"),
            .add(keyword: "addr", content: "123 Main Street, Springfield")
        )
        // Keyword lowercases; content keeps its casing and spacing.
        XCTAssertEqual(
            SnippetProvider.parse("snip add Sig Best,  Tanush"),
            .add(keyword: "sig", content: "Best,  Tanush")
        )
        XCTAssertEqual(SnippetProvider.parse("snip add"), .addHelp)
        XCTAssertEqual(SnippetProvider.parse("snip add addr"), .addHelp)
    }

    func testParseRemove() {
        XCTAssertEqual(SnippetProvider.parse("snip rm addr"), .remove(keyword: "addr"))
        XCTAssertEqual(SnippetProvider.parse("snip delete Addr"), .remove(keyword: "addr"))
        XCTAssertEqual(SnippetProvider.parse("snip rm"), .removeHelp)
    }

    func testParseRejectsOtherQueries() {
        XCTAssertNil(SnippetProvider.parse("safari"))
        XCTAssertNil(SnippetProvider.parse("snipe hunt"))
        XCTAssertNil(SnippetProvider.parse(""))
    }

    func testBareKeywordSurfacesSnippet() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnippetTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SnippetStore(directory: directory)
        store.add(keyword: "addr", content: "123 Main Street")

        let results = SnippetProvider.results(for: "addr", store: store)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "addr")
        XCTAssertEqual(results.first?.score, 900)
        XCTAssertNotNil(results.first?.secondaryAction)

        XCTAssertTrue(SnippetProvider.results(for: "nope", store: store).isEmpty)
        XCTAssertTrue(SnippetProvider.results(for: "addr extra", store: store).isEmpty)
    }

    func testListAndDeleteRows() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnippetTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SnippetStore(directory: directory)
        store.add(keyword: "addr", content: "123 Main Street")
        store.add(keyword: "sig", content: "Best, Tanush")

        XCTAssertEqual(SnippetProvider.results(for: "snip", store: store).count, 2)
        let filtered = SnippetProvider.results(for: "snip addr", store: store)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.title, "addr")

        let delete = SnippetProvider.results(for: "snip rm sig", store: store)
        XCTAssertEqual(delete.first?.title, "Delete snippet: sig")
        delete.first?.action()
        XCTAssertNil(store.snippet(forKeyword: "sig"))
    }
}
