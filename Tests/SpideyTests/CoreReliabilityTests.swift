import XCTest
@testable import Spidey

final class CoreReliabilityTests: XCTestCase {
    // MARK: - Hotkey fallback

    private let picked = HotKeyCombo(keyCode: 49, carbonModifiers: 0x1000) // Ctrl+Space

    // Launch fell back to Option+Space because Spotlight owns Cmd+Space; a
    // later retry that still fails must keep Cmd+Space as the saved choice so
    // freeing it in System Settings and reopening Sidekick still works.
    func testRetryThatFailsKeepsSavedPreference() {
        let outcome = HotKeyFallback.resolve(
            preferred: .commandSpace, userPicked: false, current: .optionSpace,
            register: { _ in false }
        )
        XCTAssertEqual(outcome.active, .optionSpace)
        XCTAssertNil(outcome.savePreferred)
    }

    // Picking a taken combo in Preferences keeps the working one and saves it back.
    func testUserPickedTakenComboRevertsToWorkingOne() {
        let outcome = HotKeyFallback.resolve(
            preferred: picked, userPicked: true, current: .commandSpace,
            register: { _ in false }
        )
        XCTAssertEqual(outcome.active, .commandSpace)
        XCTAssertEqual(outcome.savePreferred, .commandSpace)
    }

    func testFirstLaunchFallsBackToOptionSpace() {
        let outcome = HotKeyFallback.resolve(
            preferred: .commandSpace, userPicked: false, current: nil,
            register: { $0 == .optionSpace }
        )
        XCTAssertEqual(outcome.active, .optionSpace)
        XCTAssertNil(outcome.savePreferred)
    }

    func testPreferredRegistersCleanly() {
        let outcome = HotKeyFallback.resolve(
            preferred: .commandSpace, userPicked: false, current: .optionSpace,
            register: { _ in true }
        )
        XCTAssertEqual(outcome.active, .commandSpace)
        XCTAssertNil(outcome.savePreferred)
    }

    // MARK: - Site checks

    private func status(_ ok: Bool, _ detail: String = "") -> LinkChecker.Status {
        LinkChecker.Status(ok: ok, detail: detail, date: Date(timeIntervalSince1970: 0))
    }

    func testOfflineErrorsAreInconclusive() {
        XCTAssertTrue(LinkChecker.isInconclusive(URLError(.notConnectedToInternet)))
        XCTAssertTrue(LinkChecker.isInconclusive(URLError(.networkConnectionLost)))
        XCTAssertFalse(LinkChecker.isInconclusive(URLError(.cannotFindHost)))
        XCTAssertFalse(LinkChecker.isInconclusive(URLError(.badServerResponse)))
    }

    // A site whose request hit a dropped connection keeps its last status.
    func testInconclusiveResultKeepsPreviousStatus() {
        let previous = ["netflix": status(true, "Reachable")]
        let merged = LinkChecker.merge(
            previous: previous,
            fresh: ["netflix": status(false, "offline"), "crunchyroll": status(true)],
            inconclusive: ["netflix"]
        )
        XCTAssertEqual(merged?["netflix"]?.ok, true)
    }

    func testInconclusiveNewSiteIsNotFlagged() {
        let merged = LinkChecker.merge(
            previous: [:],
            fresh: ["a": status(false, "offline"), "b": status(true)],
            inconclusive: ["a"]
        )
        XCTAssertNil(merged?["a"])
        XCTAssertEqual(merged?["b"]?.ok, true)
    }

    func testEverythingFailingIsTreatedAsOffline() {
        XCTAssertNil(LinkChecker.merge(
            previous: [:],
            fresh: ["a": status(false), "b": status(false)],
            inconclusive: []
        ))
        XCTAssertNil(LinkChecker.merge(
            previous: [:], fresh: ["a": status(false)], inconclusive: ["a"]
        ))
    }

    func testRealFailureIsStillFlagged() {
        let merged = LinkChecker.merge(
            previous: ["a": status(true)],
            fresh: ["a": status(false, "HTTP 404"), "b": status(true)],
            inconclusive: []
        )
        XCTAssertEqual(merged?["a"]?.ok, false)
    }

    // MARK: - Timers

    // The notification handed to macOS at start already rang; the in-app
    // timer must not post a second copy of it. One still queued is replaced
    // by an immediate one with the same id, so it rings now and only once.
    func testTimerFallbackNotificationOnlyWhenNotRung() {
        XCTAssertFalse(TimerCenter.needsFallbackNotification(id: "x", delivered: ["x"]))
        XCTAssertTrue(TimerCenter.needsFallbackNotification(id: "x", delivered: []))
        XCTAssertTrue(TimerCenter.needsFallbackNotification(id: "x", delivered: ["z"]))
    }
}
