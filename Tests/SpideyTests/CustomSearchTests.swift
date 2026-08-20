import XCTest
@testable import Spidey

final class CustomSearchStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpideyCustomSearchTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func write(_ content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func testParseFullForm() {
        let json = """
        {"yt": {"name": "YouTube", "url": "https://www.youtube.com/results?search_query={query}"}}
        """
        let parsed = CustomSearchStore.parse(Data(json.utf8))
        XCTAssertEqual(parsed["yt"]?.name, "YouTube")
        XCTAssertEqual(parsed["yt"]?.urlTemplate, "https://www.youtube.com/results?search_query={query}")
    }

    func testParseStringFormDerivesNameFromHost() {
        let json = """
        {"ddg": "https://duckduckgo.com/?q={query}", "yt": "https://www.youtube.com/results?search_query={query}"}
        """
        let parsed = CustomSearchStore.parse(Data(json.utf8))
        XCTAssertEqual(parsed["ddg"]?.name, "duckduckgo.com")
        XCTAssertEqual(parsed["yt"]?.name, "youtube.com")
    }

    func testParseSkipsJunkEntries() {
        let json = """
        {
            "good": "https://example.com/?q={query}",
            "noplaceholder": "https://example.com/search",
            "notaurl": "not a url at all",
            "wrongtype": 42,
            "": "https://example.com/?q={query}"
        }
        """
        let parsed = CustomSearchStore.parse(Data(json.utf8))
        XCTAssertEqual(Array(parsed.keys), ["good"])
    }

    func testParseKeywordsAreLowercased() {
        let json = #"{"YT": "https://youtube.com/results?q={query}"}"#
        XCTAssertNotNil(CustomSearchStore.parse(Data(json.utf8))["yt"])
    }

    func testBadJSONTolerated() {
        XCTAssertTrue(CustomSearchStore.parse(Data("{not json".utf8)).isEmpty)
        XCTAssertTrue(CustomSearchStore.parse(Data("[1, 2, 3]".utf8)).isEmpty)
        XCTAssertTrue(CustomSearchStore.parse(Data()).isEmpty)
    }

    func testExampleFileContentParses() {
        let parsed = CustomSearchStore.parse(Data(CustomSearchStore.exampleFileContent.utf8))
        XCTAssertEqual(parsed["yt"]?.name, "YouTube")
        XCTAssertEqual(parsed["ddg"]?.name, "duckduckgo.com")
    }

    func testSearchURLEncodesQuery() {
        let search = CustomSearch(
            keyword: "yt", name: "YouTube",
            urlTemplate: "https://www.youtube.com/results?search_query={query}"
        )
        XCTAssertEqual(
            search.searchURL(for: "lofi beats")?.absoluteString,
            "https://www.youtube.com/results?search_query=lofi%20beats"
        )
        XCTAssertEqual(
            search.searchURL(for: "a & b")?.absoluteString,
            "https://www.youtube.com/results?search_query=a%20%26%20b"
        )
    }

    func testSearchURLSupportsPercentSPlaceholder() {
        let search = CustomSearch(keyword: "g", name: "g", urlTemplate: "https://example.com/?q=%s")
        XCTAssertEqual(search.searchURL(for: "hi there")?.absoluteString, "https://example.com/?q=hi%20there")
    }

    func testMissingFileYieldsEmpty() {
        let store = CustomSearchStore(fileURL: tempDir.appendingPathComponent("searches.json"))
        XCTAssertFalse(store.fileExists)
        XCTAssertTrue(store.searches().isEmpty)
        XCTAssertNil(store.search(for: "yt"))
    }

    func testStoreReloadsWhenMtimeChanges() throws {
        let file = tempDir.appendingPathComponent("searches.json")
        try write(#"{"yt": "https://youtube.com/results?q={query}"}"#, to: file)
        let store = CustomSearchStore(fileURL: file)
        XCTAssertNotNil(store.search(for: "yt"))
        XCTAssertNil(store.search(for: "gh"))

        try write(#"{"gh": "https://github.com/search?q={query}"}"#, to: file)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(2)], ofItemAtPath: file.path
        )
        XCTAssertNotNil(store.search(for: "gh"))
        XCTAssertNil(store.search(for: "yt"))
    }

    func testStoreEmptiesWhenFileDeleted() throws {
        let file = tempDir.appendingPathComponent("searches.json")
        try write(#"{"yt": "https://youtube.com/results?q={query}"}"#, to: file)
        let store = CustomSearchStore(fileURL: file)
        XCTAssertNotNil(store.search(for: "yt"))

        try FileManager.default.removeItem(at: file)
        XCTAssertNil(store.search(for: "yt"))
        XCTAssertTrue(store.searches().isEmpty)
    }

    func testCreateExampleFile() {
        let file = tempDir.appendingPathComponent("searches.json")
        let store = CustomSearchStore(fileURL: file)
        XCTAssertEqual(store.createExampleFile(), file)
        XCTAssertTrue(store.fileExists)
        XCTAssertEqual(store.search(for: "yt")?.name, "YouTube")
    }
}
