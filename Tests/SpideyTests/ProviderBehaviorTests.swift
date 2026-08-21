import XCTest
@testable import Spidey

final class TabRecordParsingTests: XCTestCase {
    func testParsesPlainRecords() {
        let output = "1\t1\thttps://a.example\tAlpha\n1\t2\thttps://b.example\tBeta\n"
        let tabs = TabsProvider.parseTabRecords(output)
        XCTAssertEqual(tabs.count, 2)
        XCTAssertEqual(tabs[0].windowIndex, 1)
        XCTAssertEqual(tabs[0].tabIndex, 1)
        XCTAssertEqual(tabs[0].url, "https://a.example")
        XCTAssertEqual(tabs[0].title, "Alpha")
        XCTAssertEqual(tabs[1].title, "Beta")
    }

    func testTitleKeepsEmbeddedTabs() {
        // Title is the last field, so tabs inside it survive the split.
        let output = "2\t3\thttps://c.example\tLeft\tRight\n"
        let tabs = TabsProvider.parseTabRecords(output)
        XCTAssertEqual(tabs.count, 1)
        XCTAssertEqual(tabs[0].title, "Left\tRight")
        XCTAssertEqual(tabs[0].url, "https://c.example")
    }

    func testTitleWithNewlineRejoinsFragment() {
        // A newline inside the title splits the record across two lines; the
        // second line must glue back onto the first tab instead of vanishing.
        let output = "1\t1\thttps://a.example\tFirst line\nsecond line\n1\t2\thttps://b.example\tBeta\n"
        let tabs = TabsProvider.parseTabRecords(output)
        XCTAssertEqual(tabs.count, 2)
        XCTAssertEqual(tabs[0].title, "First line second line")
        XCTAssertEqual(tabs[1].title, "Beta")
    }

    func testLeadingGarbageIsDropped() {
        // A fragment with no preceding record has nothing to attach to.
        let output = "orphan fragment\n1\t1\thttps://a.example\tAlpha\n"
        let tabs = TabsProvider.parseTabRecords(output)
        XCTAssertEqual(tabs.count, 1)
        XCTAssertEqual(tabs[0].title, "Alpha")
    }

    func testEmptyOutput() {
        XCTAssertTrue(TabsProvider.parseTabRecords("").isEmpty)
        XCTAssertTrue(TabsProvider.parseTabRecords("\n\n").isEmpty)
    }

    func testSanitizedTitleReplacesNewlines() {
        XCTAssertEqual(TabsProvider.sanitizedTitle("a\r\nb\nc\rd"), "a b c d")
        XCTAssertEqual(TabsProvider.sanitizedTitle("  plain  "), "plain")
    }
}

final class InterfaceSortTests: XCTestCase {
    func testEnInterfacesSortFirst() {
        let sorted = SystemInfoProvider.sortedByInterface([
            (interface: "awdl0", address: "169.254.0.2"),
            (interface: "en1", address: "192.168.1.11"),
            (interface: "anpi0", address: "169.254.0.1"),
            (interface: "bridge0", address: "192.168.2.1"),
            (interface: "en0", address: "192.168.1.10"),
            (interface: "utun3", address: "10.0.0.5"),
        ])
        XCTAssertEqual(
            sorted.map { $0.interface },
            ["en0", "en1", "anpi0", "awdl0", "bridge0", "utun3"]
        )
    }

    func testEnInterfacesSortNumerically() {
        let sorted = SystemInfoProvider.sortedByInterface([
            (interface: "en10", address: "a"),
            (interface: "en2", address: "b"),
            (interface: "en0", address: "c"),
        ])
        XCTAssertEqual(sorted.map { $0.interface }, ["en0", "en2", "en10"])
    }
}

final class ContactsNameDetectionTests: XCTestCase {
    func testSingleWordsAreNotAmbientNames() {
        // Single-word lookups go through the explicit "contact " keyword so
        // every app search en route doesn't cost a Contacts XPC fetch.
        XCTAssertFalse(ContactsProvider.looksLikeName("safari"))
        XCTAssertFalse(ContactsProvider.looksLikeName("tanush"))
    }

    func testMultiWordNamesMatch() {
        XCTAssertTrue(ContactsProvider.looksLikeName("tanush pandey"))
        XCTAssertTrue(ContactsProvider.looksLikeName("mary jane o'neil"))
    }

    func testNonNamesAreRejected() {
        XCTAssertFalse(ContactsProvider.looksLikeName("2 + 2"))
        XCTAssertFalse(ContactsProvider.looksLikeName("open example.com now ok"))
        XCTAssertFalse(ContactsProvider.looksLikeName("b64 hello"))
    }
}

final class ShellRunTests: XCTestCase {
    func testCapturesStdout() {
        XCTAssertEqual(
            Shell.run("/bin/echo", ["hello"]).trimmingCharacters(in: .whitespacesAndNewlines),
            "hello"
        )
    }

    func testStderrFloodDoesNotDeadlock() {
        // 128KB to stderr would wedge the child on an undrained pipe.
        let output = Shell.run(
            "/bin/sh", ["-c", "dd if=/dev/zero bs=1024 count=128 2>/dev/null | tr '\\0' 'e' 1>&2; echo done"]
        )
        XCTAssertEqual(output.trimmingCharacters(in: .whitespacesAndNewlines), "done")
    }

    func testHungBinaryTimesOut() {
        let start = Date()
        let output = Shell.run("/bin/sleep", ["30"], timeout: 1)
        XCTAssertEqual(output, "")
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }
}

final class WindowSnapMatchingTests: XCTestCase {
    // "full screen" and "maximize" are different commands: one enters the real
    // macOS full screen, the other only fills the screen.
    func testFullScreenQueryDoesNotOfferMaximize() {
        let titles = WindowProvider.results(for: "fullscreen").map(\.title)
        XCTAssertTrue(titles.contains { $0.contains("Full Screen") })
        XCTAssertFalse(titles.contains { $0.contains("Maximize") })
    }

    func testMaximizeQueryDoesNotOfferFullScreen() {
        let titles = WindowProvider.results(for: "maximize").map(\.title)
        XCTAssertTrue(titles.contains { $0.contains("Maximize") })
        XCTAssertFalse(titles.contains { $0.contains("Full Screen") })
    }

    func testMinimizeIsOfferedAndIsNotMaximize() {
        let titles = WindowProvider.results(for: "minimise").map(\.title)
        XCTAssertTrue(titles.contains { $0.contains("Minimize") })
        XCTAssertFalse(titles.contains { $0.contains("Maximize") })
        XCTAssertFalse(WindowProvider.results(for: "maximize").map(\.title).contains { $0.contains("Minimize") })
    }

    func testFullScreenSnapUsesTheFullScreenAction() {
        let snap = WindowProvider.snaps.first { $0.title == "Full Screen" }
        XCTAssertNotNil(snap)
        if case .fullScreen = snap!.action {} else {
            XCTFail("Full Screen must toggle native full screen, not set a frame")
        }
    }
}
