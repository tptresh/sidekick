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
    func testSingleWordsAreAmbientNames() {
        // A bare first name is the common case ("claire"); matching happens
        // against the in-memory index, so it costs no Contacts fetch.
        XCTAssertTrue(ContactsProvider.looksLikeName("claire"))
        XCTAssertTrue(ContactsProvider.looksLikeName("tanush"))
    }

    func testMultiWordNamesMatch() {
        XCTAssertTrue(ContactsProvider.looksLikeName("tanush pandey"))
        XCTAssertTrue(ContactsProvider.looksLikeName("mary jane o'neil"))
    }

    func testNonNamesAreRejected() {
        XCTAssertFalse(ContactsProvider.looksLikeName("2 + 2"))
        XCTAssertFalse(ContactsProvider.looksLikeName("open example.com now ok"))
        XCTAssertFalse(ContactsProvider.looksLikeName("b64 hello"))
        XCTAssertFalse(ContactsProvider.looksLikeName("cl"))
    }
}

final class ContactMatchingTests: XCTestCase {
    private let claire = ContactCard(
        id: "1",
        name: "Claire Bennett",
        nickname: "Cee",
        organization: "Primatech",
        jobTitle: "Cheerleader",
        phones: [
            .init(label: "mobile", value: "+1 (555) 867-5309"),
            .init(label: "work", value: "+1 (555) 200-1000"),
        ],
        emails: [.init(label: "home", value: "Claire@example.com")],
        addresses: [.init(label: "home", value: "9 Ridge Rd, Odessa TX")],
        urls: [.init(label: "homepage", value: "claire.example.com")]
    )

    private func score(_ needle: String) -> Double? {
        ContactIndex.score(needle: needle, card: claire)
    }

    func testFirstNameAloneCountsAsAnExactMatch() {
        // The whole point of the index: "claire" has to find Claire Bennett,
        // and rank as strongly as typing her full name.
        XCTAssertEqual(score("claire") ?? 0, 0.95, accuracy: 0.001)
        XCTAssertEqual(score("claire bennett") ?? 0, 1.0, accuracy: 0.001)
        XCTAssertEqual(score("bennett") ?? 0, 0.95, accuracy: 0.001)
    }

    func testPrefixesRankBelowWholeNames() {
        // A prefix of the card name still beats a prefix of a later word.
        XCTAssertEqual(score("cla") ?? 0, 0.9, accuracy: 0.001)
        XCTAssertEqual(score("claire ben") ?? 0, 0.9, accuracy: 0.001)
        XCTAssertEqual(score("benn") ?? 0, 0.8, accuracy: 0.001)
        // A nickname is a name in its own right.
        XCTAssertEqual(score("cee") ?? 0, 1.0, accuracy: 0.001)
    }

    func testReachableByAddressNumberOrEmployer() {
        XCTAssertNotNil(score("8675309"))
        XCTAssertNotNil(score("claire@example"))
        // An employer is deliberately weak: below the threshold an ambient
        // one-word query uses, so "primatech" only lands in a contact search.
        let employer = score("primatech") ?? 0
        XCTAssertGreaterThan(employer, 0)
        XCTAssertLessThan(employer, 0.8)
    }

    func testUnrelatedQueriesDoNotMatch() {
        XCTAssertNil(score("safari"))
        XCTAssertNil(score("zoom"))
    }

    func testCardSummarizesEveryField() {
        XCTAssertEqual(claire.reachable, "+1 (555) 867-5309")
        XCTAssertEqual(claire.subtitleDetail, "Cheerleader \u{00B7} Primatech")
        let copied = claire.plainTextCard
        XCTAssertTrue(copied.contains("Claire Bennett"))
        XCTAssertTrue(copied.contains("work: +1 (555) 200-1000"))
        XCTAssertTrue(copied.contains("home: 9 Ridge Rd, Odessa TX"))
    }

    func testAmbientRowsCoverTheUsualWaysToReachSomeone() {
        let titles = ContactsProvider
            .rows(for: claire, verb: .all, detail: .ambient, baseScore: 960)
            .map(\.title)
        XCTAssertEqual(titles, [
            "Message Claire Bennett",
            "Call Claire Bennett",
            "FaceTime Claire Bennett",
            "Email Claire Bennett",
            "Claire Bennett",
        ])
    }

    func testFullRowsAddEveryFieldTheCardHolds() {
        let rows = ContactsProvider.rows(for: claire, verb: .all, detail: .full, baseScore: 950)
        let titles = rows.map(\.title)
        XCTAssertEqual(titles.first, "Claire Bennett")
        XCTAssertTrue(titles.contains("FaceTime Audio Claire Bennett"))
        XCTAssertTrue(titles.contains("Call Claire Bennett \u{00B7} work"))
        XCTAssertTrue(titles.contains("Claire Bennett's home in Maps"))
        XCTAssertTrue(titles.contains("Claire Bennett \u{00B7} homepage"))
        // Scores stay in the order the rows were built, so nothing shuffles.
        XCTAssertEqual(rows.map(\.score), rows.map(\.score).sorted(by: >))
    }

    func testAVerbNarrowsToOneWayOfReaching() {
        let titles = ContactsProvider
            .rows(for: claire, verb: .call, detail: .ambient, baseScore: 960)
            .map(\.title)
        XCTAssertEqual(titles, [
            "Call Claire Bennett",
            "Call Claire Bennett \u{00B7} work",
            "Claire Bennett",
        ])
    }

    func testCompanyCardsStayOutOfTheTopRank() {
        let shop = ContactCard(
            id: "3",
            name: "Notion",
            organization: "Notion",
            phones: [.init(label: "main", value: "555-2222")]
        )
        XCTAssertTrue(shop.isCompany)
        XCTAssertFalse(claire.isCompany)
    }

    func testMobileLineWinsOverWork() {
        let reversed = ContactCard(
            id: "2",
            name: "Noah Bennett",
            phones: [
                .init(label: "work", value: "555-0000"),
                .init(label: "mobile", value: "555-1111"),
            ]
        )
        XCTAssertEqual(reversed.primaryPhone?.value, "555-1111")
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
