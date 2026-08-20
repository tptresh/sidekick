import XCTest
@testable import Spidey

final class ClipboardStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeStore(limit: Int = 10) -> ClipboardStore {
        ClipboardStore(directory: directory, limitOverride: limit)
    }

    private func textEntry(_ value: String, date: Date = Date()) -> ClipEntry {
        ClipEntry(id: UUID(), kind: .text, date: date, value: value)
    }

    func testPinnedSortsFirst() {
        let store = makeStore()
        store.record(textEntry("alpha"))
        store.record(textEntry("beta"))

        // "alpha" is the older, bottom entry; pinning lifts it to the top.
        let alpha = store.entries.first { $0.value == "alpha" }!
        store.togglePin(alpha)
        XCTAssertEqual(store.entries.map(\.value), ["alpha", "beta"])
        XCTAssertTrue(store.entries[0].pinned)

        // New copies land below the pinned group.
        store.record(textEntry("gamma"))
        XCTAssertEqual(store.entries.map(\.value), ["alpha", "gamma", "beta"])

        // Unpinning drops it back into the unpinned group.
        store.togglePin(store.entries[0])
        XCTAssertFalse(store.entries.contains(where: \.pinned))
    }

    func testPinPersistsAcrossReload() {
        let store = makeStore()
        store.record(textEntry("keep me"))
        store.record(textEntry("ordinary"))
        store.togglePin(store.entries.first { $0.value == "keep me" }!)

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.entries.count, 2)
        XCTAssertEqual(reloaded.entries.first?.value, "keep me")
        XCTAssertTrue(reloaded.entries.first?.pinned == true)
        XCTAssertFalse(reloaded.entries.last?.pinned == true)
    }

    func testPinnedEntriesSurviveHistoryCap() {
        // The cap is clamped to a minimum of 10 unpinned entries.
        let store = makeStore(limit: 10)
        store.record(textEntry("pinned survivor"))
        store.togglePin(store.entries[0])

        for index in 0..<15 {
            store.record(textEntry("filler \(index)"))
        }

        XCTAssertEqual(store.entries.filter { !$0.pinned }.count, 10)
        XCTAssertEqual(store.entries.first?.value, "pinned survivor")
        XCTAssertTrue(store.entries.first?.pinned == true)
        // The oldest unpinned fillers aged out, newest survived.
        XCTAssertFalse(store.entries.contains { $0.value == "filler 0" })
        XCTAssertTrue(store.entries.contains { $0.value == "filler 14" })
    }

    func testUnpinReturnsToDateOrder() {
        let store = makeStore()
        let base = Date()
        store.record(textEntry("oldest", date: base.addingTimeInterval(-30)))
        store.record(textEntry("middle", date: base.addingTimeInterval(-20)))
        store.record(textEntry("newest", date: base.addingTimeInterval(-10)))
        XCTAssertEqual(store.entries.map(\.value), ["newest", "middle", "oldest"])

        // Pin the middle entry, then unpin it: it must slot back into its
        // date position, not land on top of the unpinned group.
        store.togglePin(store.entries.first { $0.value == "middle" }!)
        XCTAssertEqual(store.entries.map(\.value), ["middle", "newest", "oldest"])
        store.togglePin(store.entries.first { $0.value == "middle" }!)
        XCTAssertEqual(store.entries.map(\.value), ["newest", "middle", "oldest"])
    }

    func testPinnedGroupStaysInDateOrder() {
        let store = makeStore()
        let base = Date()
        store.record(textEntry("old", date: base.addingTimeInterval(-40)))
        store.record(textEntry("mid", date: base.addingTimeInterval(-30)))
        store.record(textEntry("new", date: base.addingTimeInterval(-20)))

        // Pin the oldest first, then the newest: the pinned group orders by
        // date, not by the order the pins happened.
        store.togglePin(store.entries.first { $0.value == "old" }!)
        store.togglePin(store.entries.first { $0.value == "new" }!)
        XCTAssertEqual(store.entries.map(\.value), ["new", "old", "mid"])
        XCTAssertTrue(store.entries[0].pinned)
        XCTAssertTrue(store.entries[1].pinned)
        XCTAssertFalse(store.entries[2].pinned)
    }

    func testRecordingPinnedValueRefreshesInPlace() {
        let store = makeStore()
        store.record(textEntry("dupe"))
        store.togglePin(store.entries[0])
        let pinnedID = store.entries[0].id

        // Copying the same value again must not create a second, unpinned row.
        store.record(textEntry("dupe"))
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries[0].id, pinnedID)
        XCTAssertTrue(store.entries[0].pinned)
    }

    func testDecodesHistoryWrittenBeforePinning() throws {
        // Simulate a clipboard.json from a build without the pinned field.
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacy = """
        [{"id":"\(UUID().uuidString)","kind":"text","date":0,"value":"old entry"}]
        """
        try legacy.data(using: .utf8)!.write(to: directory.appendingPathComponent("clipboard.json"))

        let store = makeStore()
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries[0].value, "old entry")
        XCTAssertFalse(store.entries[0].pinned)
    }

    func testPasteboardToolsParsing() {
        XCTAssertEqual(PasteboardToolsProvider.parse("plain"), .plainText)
        XCTAssertEqual(PasteboardToolsProvider.parse("paste plain"), .plainText)
        XCTAssertEqual(PasteboardToolsProvider.parse("clear clipboard"), .clearClipboard)
        XCTAssertEqual(PasteboardToolsProvider.parse("clear clip"), .clearClipboard)
        // Short prefixes en route to anything must not trigger command rows.
        XCTAssertNil(PasteboardToolsProvider.parse("pla"))
        XCTAssertNil(PasteboardToolsProvider.parse("pas"))
        XCTAssertNil(PasteboardToolsProvider.parse("past"))
        XCTAssertNil(PasteboardToolsProvider.parse("clear cl"))
        XCTAssertNil(PasteboardToolsProvider.parse("pl"))
        XCTAssertNil(PasteboardToolsProvider.parse("plane"))
        XCTAssertNil(PasteboardToolsProvider.parse("clear"))
        XCTAssertNil(PasteboardToolsProvider.parse(""))
    }
}
