import XCTest
@testable import Spidey

// File search runs late (debounced, then Spotlight). These pin down what the
// list shows in between: never another query's files, and no restarts when
// the same query is merely refreshed (a site logo arriving, say).
final class SearchFileResultsTests: XCTestCase {
    private var model: SpideyViewModel!
    private var calls: [(String, FileProvider.Mode)] = []

    override func setUp() {
        super.setUp()
        AppProvider.shared.appsOverride = []
        calls = []
        model = SpideyViewModel()
        model.usageStore = UsageStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )
        model.fileSearch = { [unowned self] query, mode, completion in
            calls.append((query, mode))
            let name = query.split(separator: " ").joined(separator: "-") + " final.pdf"
            completion([Self.file(name)])
        }
    }

    override func tearDown() {
        AppProvider.shared.appsOverride = nil
        model = nil
        super.tearDown()
    }

    static func file(_ name: String) -> ResultItem {
        ResultItem(
            title: name, subtitle: "~/Documents", icon: .symbol("doc"), score: 450,
            dragFileURL: URL(fileURLWithPath: "/tmp/\(name)"), action: {}
        )
    }

    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
    }

    private func fileTitles() -> [String] {
        model.results.filter { $0.dragFileURL != nil }.map(\.title)
    }

    func testUnrelatedQueryDropsTheOldFilesAtOnce() {
        model.query = "notes"
        settle()
        XCTAssertEqual(fileTitles(), ["notes final.pdf"])
        model.query = "breaking bad"
        XCTAssertEqual(fileTitles(), [], "the previous query's files must not sit on top while typing")
    }

    func testRefiningTheQueryKeepsFilesThatStillMatch() {
        model.query = "rep"
        settle()
        model.query = "rep final"
        XCTAssertEqual(fileTitles(), ["rep final.pdf"])
    }

    func testRefreshingTheSameQueryDoesNotRestartTheSearch() {
        model.query = "report"
        settle()
        XCTAssertEqual(calls.count, 1)
        model.refresh()
        settle()
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(fileTitles(), ["report final.pdf"])
    }

    func testFindKeywordKeepsItsFilesAcrossARefresh() {
        model.query = "find report"
        settle()
        XCTAssertEqual(fileTitles(), ["report final.pdf"])
        model.refresh()
        XCTAssertEqual(fileTitles(), ["report final.pdf"])
        settle()
        XCTAssertEqual(calls.count, 1)
    }

    func testFileNameMatchIgnoresCaseAndAccents() {
        XCTAssertTrue(FileProvider.nameContainsAll(query: "resume final", name: "Résumé FINAL.pdf"))
        XCTAssertFalse(FileProvider.nameContainsAll(query: "resume draft", name: "Résumé FINAL.pdf"))
        XCTAssertFalse(FileProvider.nameContainsAll(query: "   ", name: "a.pdf"))
    }
}
