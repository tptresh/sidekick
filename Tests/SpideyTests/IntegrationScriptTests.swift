import XCTest
@testable import Spidey

final class IntegrationScriptTests: XCTestCase {
    func testAutomationRefusalNamesTheSetting() {
        let text = SystemProvider.scriptFailureText(
            "execution error: Not authorized to send Apple events to System Events. (-1743)", app: "System Events"
        )
        XCTAssertTrue(text.contains("Automation"))
        XCTAssertTrue(text.contains("System Events"))
    }

    func testAppNotRunningIsExplained() {
        let text = SystemProvider.scriptFailureText("execution error: Spotify got an error: Application isn\u{2019}t running. (-600)", app: "Spotify")
        XCTAssertTrue(text.contains("Spotify"))
        XCTAssertTrue(text.contains("not running"))
    }

    func testTimeoutAndUnknownErrorsStillExplain() {
        XCTAssertTrue(SystemProvider.scriptFailureText(nil, app: "Music").contains("did not answer"))
        XCTAssertFalse(SystemProvider.scriptFailureText("weird", app: "Music").isEmpty)
    }

    func testScriptTargetIsReadFromTheTellLine() {
        XCTAssertEqual(SystemProvider.scriptTarget("tell application \"Spotify\" to playpause"), "Spotify")
        XCTAssertEqual(SystemProvider.scriptTarget("set volume output volume 50"), nil)
    }

    func testRunReportsExitStatusAndTimeout() {
        XCTAssertEqual(Shell.runStatus("/usr/bin/true", []).status, 0)
        XCTAssertNotEqual(Shell.runStatus("/usr/bin/false", []).status, 0)
        let slow = Shell.runStatus("/bin/sleep", ["5"], timeout: 0.3)
        XCTAssertNil(slow.status, "a timed-out run has no exit status")
    }
}

final class IntegrationTabsTests: XCTestCase {
    func testTabAddressIsEscapedForAppleScript() {
        XCTAssertEqual(TabsProvider.appleScriptEscaped("https://a.com/?q=\"x\"\\y"), "https://a.com/?q=\\\"x\\\"\\\\y")
    }

    func testClosedTabIsReportedNotSwappedForTheTabAtItsOldPosition() {
        let tab = TabsProvider.Tab(windowIndex: 2, tabIndex: 5, title: "Inbox", url: "https://mail.google.com")
        let script = TabsProvider.activateScript(tab, appName: "Google Chrome")
        XCTAssertTrue(script.contains("https://mail.google.com"))
        XCTAssertFalse(script.contains("window 2"), "must not fall back to the remembered position")
        XCTAssertFalse(script.contains("to 5"), "must not fall back to the remembered position")
        XCTAssertTrue(script.contains("number \(SystemProvider.messageErrorNumber)"))
    }

    func testOwnScriptMessageIsPassedThroughToTheUser() {
        let text = SystemProvider.scriptFailureText(
            "36:120: execution error: That tab has been closed. (\(SystemProvider.messageErrorNumber))",
            app: "Google Chrome"
        )
        XCTAssertEqual(text, "That tab has been closed.")
    }
}

final class IntegrationProcessTests: XCTestCase {
    func testQuittingAnAppThatIsNotRunningSaysSo() {
        let items = ProcessProvider.results(for: "quit zqxjvapp")
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.title, "Zqxjvapp is not running")
        // High enough to sit above streaming rows like "Watch ... on Netflix".
        XCTAssertGreaterThan(items.first?.score ?? 0, 800)
    }

    func testSameNamedBackgroundProcessesShareOneRow() {
        let processes = [
            ProcessProvider.BackgroundProcess(pid: 10, name: "node"),
            ProcessProvider.BackgroundProcess(pid: 11, name: "node"),
            ProcessProvider.BackgroundProcess(pid: 12, name: "nodemon"),
        ]
        let groups = ProcessProvider.groupedByName(processes)
        XCTAssertEqual(groups.map(\.name), ["node", "nodemon"])
        XCTAssertEqual(groups.first?.pids, [10, 11])
    }
}

final class IntegrationMusicTests: XCTestCase {
    func testControlCommandsWithNoPlayerSayNothingIsPlaying() {
        for query in ["pause", "next", "skip", "previous", "play pause", "now playing"] {
            XCTAssertEqual(MusicProvider.noPlayerRow(for: query)?.title, "Nothing is playing", query)
        }
        // "play" offers to launch a player instead, and bare common words stay quiet.
        XCTAssertNil(MusicProvider.noPlayerRow(for: "play"))
        XCTAssertNil(MusicProvider.noPlayerRow(for: "back"))
        XCTAssertNil(MusicProvider.noPlayerRow(for: "hello"))
    }

    func testNothingPlayingRowStaysBelowTheCalendarsNextEvent() {
        XCTAssertLessThan(MusicProvider.noPlayerRow(for: "next")?.score ?? 1000, 950)
    }
}

final class IntegrationToggleTests: XCTestCase {
    func testSettlingWaitsForALateChange() {
        var calls = 0
        XCTAssertTrue(ToggleProvider.settles(within: 2, every: 0.01) { calls += 1; return calls >= 3 })
        XCTAssertEqual(calls, 3)
    }

    func testSettlingGivesUpAfterTheLimit() {
        let start = Date()
        XCTAssertFalse(ToggleProvider.settles(within: 0.2, every: 0.05) { false })
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
    }
}

final class IntegrationMenuTests: XCTestCase {
    func testMenuItemThatOpensADialogIsNotReportedAsFailed() {
        // A press that opens a modal sheet often times out with cannotComplete
        // even though it worked.
        XCTAssertFalse(MenuItemsProvider.pressFailed(.cannotComplete))
        XCTAssertFalse(MenuItemsProvider.pressFailed(.success))
        XCTAssertTrue(MenuItemsProvider.pressFailed(.invalidUIElement))
        XCTAssertTrue(MenuItemsProvider.pressFailed(.actionUnsupported))
    }
}

final class IntegrationLockTests: XCTestCase {
    func testLockScreenWaitsLongEnoughForAPermissionPrompt() {
        XCTAssertGreaterThanOrEqual(SystemProvider.lockScreenTimeout, 30)
    }
}
