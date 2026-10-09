import XCTest
@testable import Spidey

final class IntegrationFindMyTests: XCTestCase {
    typealias P = FindMyProvider

    // MARK: name matching

    func testCurlyApostropheInRowMatchesStraightTypedName() {
        XCTAssertNotNil(P.matchRank(label: "Tanush\u{2019}s Keys, Home, 9 min ago", term: "tanush's keys"))
    }

    func testMissingApostropheStillMatches() {
        XCTAssertNotNil(P.matchRank(label: "Tanush\u{2019}s Keys, Home, 9 min ago", term: "tanushs keys"))
        XCTAssertNotNil(P.matchRank(label: "Tanush\u{2019}s iPhone, Home, Now", term: "tanush iphone"))
    }

    func testCurlyQuotesAndExtraSpacesInTypedNameAreFolded() {
        XCTAssertNotNil(P.matchRank(label: "Tanush's MacBook Pro", term: "tanush\u{2019}s   macbook"))
    }

    func testUnrelatedRowDoesNotMatch() {
        XCTAssertNil(P.matchRank(label: "Tanush's Keys, Home, 9 min ago", term: "iphone"))
        XCTAssertNil(P.matchRank(label: "Tanush's iPhone, Home, Now", term: "tanush ipad"))
    }

    func testExactNameBeatsPartialName() {
        let labels = ["Tanush's iPhone 15 Pro, Home, Now", "Tanush's iPhone, Home, Now"]
        XCTAssertEqual(P.bestMatch(labels, term: "tanush's iphone", owner: nil), 1)
    }

    func testOwnersDeviceBeatsFamilyDeviceForGenericKind() {
        let labels = ["Mum's iPhone, Leeds, 2 min ago", "Tanush's iPhone, Home, Now"]
        XCTAssertEqual(P.bestMatch(labels, term: "iphone", owner: "Tanush Pandey"), 1)
        // With no owner name the first listed row wins, as before.
        XCTAssertEqual(P.bestMatch(labels, term: "iphone", owner: nil), 0)
    }

    func testNameMatchBeatsLocationMatch() {
        // "home" is only in the location of the first row but is the name of the second.
        let labels = ["Tanush's iPhone, Home, Now", "Home Keys, Office, 1 hr ago"]
        XCTAssertEqual(P.bestMatch(labels, term: "home", owner: nil), 1)
    }

    func testDeviceNameIsTheLabelBeforeTheLocation() {
        XCTAssertEqual(P.deviceName(fromRowLabel: "Tanush\u{2019}s Keys, Home, 9 min ago"), "tanush's keys")
        XCTAssertEqual(P.deviceName(fromRowLabel: "AirPods Pro"), "airpods pro")
    }

    // MARK: confirmation sheet

    func testConfirmationPicksThePlayButtonNeverCancel() {
        XCTAssertEqual(P.confirmationChoice(["Cancel", "Play Sound"]), 1)
        XCTAssertEqual(P.confirmationChoice(["Cancel", "Continue"]), 1)
        XCTAssertEqual(P.confirmationChoice(["Don\u{2019}t Play", "OK"]), 1)
        XCTAssertNil(P.confirmationChoice(["Cancel", "Stop Sound"]))
        XCTAssertNil(P.confirmationChoice([]))
    }

    // MARK: messages

    func testEveryFailureHasAPlainMessage() {
        for outcome in P.Outcome.allCases where outcome != .ok {
            let message = P.failureMessage(outcome, term: "iphone")
            XCTAssertFalse(message.isEmpty, "\(outcome)")
            XCTAssertFalse(message.contains("\u{2014}"), "\(outcome)")
            XCTAssertTrue(message.contains("Find My"), "\(outcome) should say where to finish")
        }
    }

    func testPermissionMessageNamesTheSetting() {
        XCTAssertTrue(P.failureMessage(.noAccessibility, term: "iphone").contains("Accessibility"))
    }

    func testRetryOnlyForStepsAfterTheRowWasFound() {
        XCTAssertTrue(P.Outcome.rowPressFailed.isRetryable)
        XCTAssertTrue(P.Outcome.noPlayButton.isRetryable)
        XCTAssertFalse(P.Outcome.deviceNotFound.isRetryable)
        XCTAssertFalse(P.Outcome.noAccessibility.isRetryable)
        XCTAssertFalse(P.Outcome.playUnavailable.isRetryable)
    }
}
