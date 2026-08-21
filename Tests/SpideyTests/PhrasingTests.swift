import XCTest
@testable import Spidey

final class PhrasingTests: XCTestCase {
    private func check(_ pairs: [(String, String)], file: StaticString = #filePath, line: UInt = #line) {
        for (spoken, expected) in pairs {
            XCTAssertEqual(
                Phrasing.normalize(spoken), expected,
                "\"\(spoken)\" should normalize to \"\(expected)\"", file: file, line: line
            )
        }
    }

    func testTimerPhrasing() {
        check([
            ("set a timer for 5 minutes", "timer 5 minutes"),
            ("Set a timer for 5 minutes", "timer 5 minutes"),
            ("set timer 10m", "timer 10m"),
            ("start a timer for 1h30m", "timer 1h30m"),
            ("timer for 90 seconds", "timer 90 seconds"),
            ("5 minute timer", "timer 5 minute"),
            ("set a 25 min timer", "timer 25 min"),
            ("countdown for 3 minutes", "timer 3 minutes"),
            ("cancel my timer", "timers"),
            ("stop all timers", "timers"),
            ("show me my timers", "timers"),
            ("timer", "timers"),
            // Terse syntax is left exactly as it was.
            ("timer 10m tea", "timer 10m tea"),
        ])
    }

    func testPowerPhrasing() {
        check([
            ("put my mac to sleep", "sleep"),
            ("go to sleep", "sleep"),
            ("sleep the computer", "sleep"),
            ("lock my screen", "lock screen"),
            ("lock", "lock screen"),
            ("restart my mac", "restart"),
            ("reboot", "restart"),
            ("shut down my computer", "shut down"),
            ("shutdown", "shut down"),
            ("log me out", "log out"),
            ("sign out", "log out"),
            ("empty the trash", "empty trash"),
            ("start the screen saver", "screensaver"),
            ("eject all disks", "eject"),
        ])
    }

    func testPowerPhrasingLeavesUnrelatedQueriesAlone() {
        // Only this Mac gets restarted, never a search for something else.
        check([
            ("restart my router", "restart my router"),
            ("shut down chrome", "quit chrome"),
            ("sleep token", "sleep token"),
        ])
    }

    func testTogglePhrasing() {
        check([
            ("turn off wifi", "wifi off"),
            ("turn wifi off", "wifi off"),
            ("disable wi-fi", "wifi off"),
            ("turn on my wifi", "wifi on"),
            ("enable wireless", "wifi on"),
            ("turn off bluetooth", "bluetooth off"),
            ("bluetooth on", "bluetooth on"),
            ("switch to dark mode", "dark mode on"),
            ("turn on dark mode", "dark mode on"),
            ("light mode", "dark mode off"),
            ("keep my mac awake", "caffeinate on"),
            ("don't let my mac sleep", "caffeinate on"),
            ("turn on do not disturb", "dnd on"),
            ("turn off dnd", "dnd off"),
            ("silence my notifications", "dnd on"),
            ("clear my clipboard", "clear clipboard"),
        ])
    }

    func testVolumeAndBrightnessPhrasing() {
        check([
            ("turn up the volume", "volume up"),
            ("turn the volume up", "volume up"),
            ("louder", "volume up"),
            ("turn it down", "volume down"),
            ("make it quieter", "volume down"),
            ("set the volume to 50", "volume 50"),
            ("volume to 30%", "volume 30"),
            ("max volume", "volume 100"),
            ("mute the sound", "mute"),
            ("mute", "mute"),
            ("turn up the brightness", "brightness up"),
            ("make the screen brighter", "brightness up"),
            ("dim the screen", "brightness down"),
            ("set brightness to 40%", "brightness 40"),
        ])
    }

    func testReadoutPhrasing() {
        check([
            ("what's my ip", "ip"),
            ("what is my ip address", "ip"),
            ("my ip", "ip"),
            ("how much battery is left", "battery"),
            ("battery percentage", "battery"),
            ("what's my battery level", "battery"),
            ("how much disk space is left", "disk"),
            ("free space", "disk"),
            ("what time is it in tokyo", "time in tokyo"),
            ("the time in london", "time in london"),
        ])
    }

    func testMediaAndWindowPhrasing() {
        check([
            ("pause the music", "pause"),
            ("play music", "play"),
            ("skip this song", "next"),
            ("what's playing", "now playing"),
            ("maximize this window", "maximize"),
            ("move this window to the left", "left half"),
            ("snap window top right", "top right"),
            ("center this window", "center"),
        ])
    }

    func testProcessPhrasing() {
        check([
            ("close chrome", "quit chrome"),
            ("quit the finder app", "quit finder"),
            ("force close safari", "force quit safari"),
            ("kill node", "kill node"),
        ])
    }

    func testCourtesyIsStripped() {
        check([
            ("please lock my screen", "lock screen"),
            ("can you empty the trash", "empty trash"),
            ("hey spidey turn off wifi", "wifi off"),
            ("mute please", "mute"),
        ])
    }

    func testUnrecognizedQueriesSurviveIntact() {
        check([
            ("swift concurrency", "swift concurrency"),
            ("github.com", "github.com"),
            ("2+2", "2+2"),
            ("the batman", "the batman"),
        ])
    }

    // The rewrites are only worth anything if the providers accept them.
    func testNormalizedQueriesReachTheirProviders() {
        XCTAssertEqual(
            TimerProvider.results(for: Phrasing.normalize("set a timer for 5 minutes")).first?.title,
            "Start a 5m timer"
        )
        XCTAssertEqual(
            TimerProvider.results(for: Phrasing.normalize("set a 25 minute timer for pasta")).first?.title,
            "Start timer: pasta (25m)"
        )
        XCTAssertEqual(
            VolumeProvider.results(for: Phrasing.normalize("set the volume to 40%")).first?.title,
            "Set Volume to 40%"
        )
        XCTAssertEqual(
            VolumeProvider.results(for: Phrasing.normalize("turn up the volume")).first?.title,
            "Volume Up"
        )
        XCTAssertEqual(
            VolumeProvider.results(for: Phrasing.normalize("mute the sound")).first?.title,
            "Mute"
        )
        let lock = SystemProvider.results(
            for: Phrasing.normalize("please lock my screen"), armedCommand: nil, arm: { _ in }
        )
        XCTAssertEqual(lock.first?.title, "Lock Screen")
        let sleep = SystemProvider.results(
            for: Phrasing.normalize("put my mac to sleep"), armedCommand: nil, arm: { _ in }
        )
        XCTAssertEqual(sleep.first?.title, "Sleep")
        // Destructive commands still come back armed rather than running.
        let trash = SystemProvider.results(
            for: Phrasing.normalize("empty the trash"), armedCommand: nil, arm: { _ in }
        )
        XCTAssertEqual(trash.first?.title, "Empty Trash")
        XCTAssertTrue(trash.first?.subtitle.contains("asks to confirm") == true)
    }

    func testSpokenDurationsParse() {
        XCTAssertEqual(TimerCenter.parse("5 minutes")?.seconds, 300)
        XCTAssertEqual(TimerCenter.parse("an hour")?.seconds, 3600)
        XCTAssertEqual(TimerCenter.parse("half an hour")?.seconds, 1800)
        XCTAssertEqual(TimerCenter.parse("an hour and a half")?.seconds, 5400)
        XCTAssertEqual(TimerCenter.parse("25-minute")?.seconds, 1500)
        // Filler between the duration and the label is dropped.
        XCTAssertEqual(TimerCenter.parse("5 minutes for the pasta")?.label, "pasta")
        XCTAssertEqual(TimerCenter.parse("10m tea")?.label, "tea")
    }

    func testNotificationsReadAsFocus() {
        // "turn off notifications" wants Do Not Disturb on, not off.
        check([
            ("turn off notifications", "dnd on"),
            ("silence notifications", "dnd on"),
            ("turn on notifications", "dnd off"),
            ("allow notifications", "dnd off"),
        ])
    }

    func testToggleIntentSplit() {
        XCTAssertEqual(ToggleProvider.Intent.split("wifi off").subject, "wifi")
        XCTAssertEqual(ToggleProvider.Intent.split("wifi").subject, "wifi")
        // An explicit direction wins over flipping the current state.
        XCTAssertTrue(ToggleProvider.Intent.split("wifi off").intent.desired(current: true) == false)
        XCTAssertTrue(ToggleProvider.Intent.split("wifi off").intent.desired(current: false) == false)
        XCTAssertTrue(ToggleProvider.Intent.split("wifi on").intent.desired(current: false))
        XCTAssertTrue(ToggleProvider.Intent.split("wifi").intent.desired(current: false))
        XCTAssertFalse(ToggleProvider.Intent.split("wifi").intent.desired(current: true))
    }
}
