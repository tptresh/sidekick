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
}
