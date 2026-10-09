import XCTest
@testable import Spidey

final class IntegrationFocusTests: XCTestCase {
    func testShortcutFailureQuotesTheFirstErrorLine() {
        let text = FocusProvider.shortcutFailureText("\n  Error: The shortcut could not be found.\nmore\n")
        XCTAssertTrue(text.hasPrefix("Shortcuts said: Error: The shortcut could not be found."))
    }

    func testShortcutFailureWithoutOutputStillExplains() {
        XCTAssertFalse(FocusProvider.shortcutFailureText("").isEmpty)
        XCTAssertTrue(FocusProvider.shortcutFailureText("   \n").contains("Shortcuts app"))
    }
}
