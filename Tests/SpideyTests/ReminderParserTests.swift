import XCTest
@testable import Spidey

final class ReminderParserTests: XCTestCase {
    // Fixed clock: Wednesday 2026-08-19 at 10:00 in a fixed zone, so results
    // never depend on when or where the tests run.
    private var cal = Calendar(identifier: .gregorian)
    private var now = Date()

    override func setUp() {
        super.setUp()
        cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        now = date(2026, 8, 19, 10, 0)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        cal.date(from: DateComponents(
            timeZone: cal.timeZone, year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    private func parse(_ query: String) -> ReminderParser.Parsed? {
        ReminderParser.parse(query, now: now, calendar: cal)
    }

    // MARK: - Prefix recognition

    func testPrefixVariants() {
        XCTAssertEqual(parse("remind me to buy milk")?.task, "buy milk")
        XCTAssertEqual(parse("remind me buy milk")?.task, "buy milk")
        XCTAssertEqual(parse("remind to buy milk")?.task, "buy milk")
        XCTAssertEqual(parse("remind buy milk")?.task, "buy milk")
        XCTAssertEqual(parse("Remind Me To Call Mom")?.task, "Call Mom")
    }

    func testNonRemindQueriesReturnNil() {
        XCTAssertNil(parse("remind"))
        XCTAssertNil(parse("remind me to"))
        XCTAssertNil(parse("remind me to   "))
        XCTAssertNil(parse("reminders"))
        XCTAssertNil(parse("buy milk at 5pm"))
    }

    func testNoTimeMeansNoDue() {
        let parsed = parse("remind me to buy milk")
        XCTAssertEqual(parsed, ReminderParser.Parsed(task: "buy milk", due: nil))
    }

    // MARK: - "at <time>" with am/pm

    func testAtTimeWithMeridiem() {
        XCTAssertEqual(parse("remind me to buy milk at 5pm")?.due, date(2026, 8, 19, 17, 0))
        XCTAssertEqual(parse("remind me to buy milk at 5 pm")?.due, date(2026, 8, 19, 17, 0))
        XCTAssertEqual(parse("remind me to buy milk at 5PM")?.due, date(2026, 8, 19, 17, 0))
        XCTAssertEqual(parse("remind me to buy milk at 5 p.m.")?.due, date(2026, 8, 19, 17, 0))
        XCTAssertEqual(parse("remind me to buy milk at 11am")?.due, date(2026, 8, 19, 11, 0))
        XCTAssertEqual(parse("remind me to buy milk at 5:30pm")?.due, date(2026, 8, 19, 17, 30))
        XCTAssertEqual(parse("remind me to buy milk at 5pm")?.task, "buy milk")
    }

    func testTwelveOClockEdgeCases() {
        // Noon is still ahead of the 10:00 clock; midnight already passed.
        XCTAssertEqual(parse("remind me to eat at 12pm")?.due, date(2026, 8, 19, 12, 0))
        XCTAssertEqual(parse("remind me to sleep at 12am")?.due, date(2026, 8, 20, 0, 0))
    }

    func testPastMeridiemTimeRollsToTomorrow() {
        // 8 AM already passed at 10:00, so the next occurrence is tomorrow.
        XCTAssertEqual(parse("remind me to stretch at 8am")?.due, date(2026, 8, 20, 8, 0))
    }

    // MARK: - "at <time>" 24-hour and bare hours

    func testTwentyFourHourTimes() {
        XCTAssertEqual(parse("remind me to review at 17:30")?.due, date(2026, 8, 19, 17, 30))
        XCTAssertEqual(parse("remind me to review at 13:00")?.due, date(2026, 8, 19, 13, 0))
        // 09:15 in unambiguous 24h form has passed; hour 9 alone is ambiguous,
        // so 9:15 resolves to the evening reading (21:15) instead.
        XCTAssertEqual(parse("remind me to review at 9:15")?.due, date(2026, 8, 19, 21, 15))
    }

    func testBareHourPicksNextUpcomingOccurrence() {
        // At 10:00: 11 is still ahead this morning, 9 means 9 tonight.
        XCTAssertEqual(parse("remind me to call at 11")?.due, date(2026, 8, 19, 11, 0))
        XCTAssertEqual(parse("remind me to call at 9")?.due, date(2026, 8, 19, 21, 0))
        XCTAssertEqual(parse("remind me to call at 12")?.due, date(2026, 8, 19, 12, 0))
        XCTAssertEqual(parse("remind me to call at 5")?.due, date(2026, 8, 19, 17, 0))
    }

    func testBareHourBothOccurrencesPassedRollsToTomorrow() {
        let lateNow = date(2026, 8, 19, 23, 0)
        let parsed = ReminderParser.parse("remind me to journal at 9", now: lateNow, calendar: cal)
        // Both 9:00 and 21:00 have passed; tomorrow's 9 reads as morning.
        XCTAssertEqual(parsed?.due, date(2026, 8, 20, 9, 0))
    }

    // MARK: - "tomorrow"

    func testTomorrowAt() {
        XCTAssertEqual(parse("remind me to standup tomorrow at 9")?.due, date(2026, 8, 20, 9, 0))
        XCTAssertEqual(parse("remind me to standup tomorrow at 5")?.due, date(2026, 8, 20, 17, 0))
        XCTAssertEqual(parse("remind me to standup tomorrow at 9am")?.due, date(2026, 8, 20, 9, 0))
        XCTAssertEqual(parse("remind me to standup tomorrow at 9pm")?.due, date(2026, 8, 20, 21, 0))
        XCTAssertEqual(parse("remind me to standup tomorrow at 17:30")?.due, date(2026, 8, 20, 17, 30))
        XCTAssertEqual(parse("remind me to standup tomorrow at 9")?.task, "standup")
    }

    func testBareTomorrowDefaultsToNineAM() {
        let parsed = parse("remind me to water plants tomorrow")
        XCTAssertEqual(parsed?.task, "water plants")
        XCTAssertEqual(parsed?.due, date(2026, 8, 20, 9, 0))
    }

    // MARK: - "in <n><unit>"

    func testRelativeMinutes() {
        XCTAssertEqual(parse("remind standup in 20m")?.due, now.addingTimeInterval(20 * 60))
        XCTAssertEqual(parse("remind standup in 20 min")?.due, now.addingTimeInterval(20 * 60))
        XCTAssertEqual(parse("remind standup in 90 minutes")?.due, now.addingTimeInterval(90 * 60))
        XCTAssertEqual(parse("remind standup in 1 minute")?.due, now.addingTimeInterval(60))
        XCTAssertEqual(parse("remind standup in 20m")?.task, "standup")
    }

    func testRelativeHoursAndDays() {
        XCTAssertEqual(parse("remind me to check oven in 2h")?.due, now.addingTimeInterval(2 * 3600))
        XCTAssertEqual(parse("remind me to check oven in 2 hours")?.due, now.addingTimeInterval(2 * 3600))
        XCTAssertEqual(parse("remind me to check oven in 1 hr")?.due, now.addingTimeInterval(3600))
        XCTAssertEqual(parse("remind me to renew passport in 1d")?.due, now.addingTimeInterval(86400))
        XCTAssertEqual(parse("remind me to renew passport in 3 days")?.due, now.addingTimeInterval(3 * 86400))
    }

    func testRelativeFractions() {
        XCTAssertEqual(parse("remind me to check in 1.5h")?.due, now.addingTimeInterval(5400))
    }

    // MARK: - Task extraction

    func testOnlyTrailingTimeClauseIsStripped() {
        let parsed = parse("remind me to meet at the cafe at 5pm")
        XCTAssertEqual(parsed?.task, "meet at the cafe")
        XCTAssertEqual(parsed?.due, date(2026, 8, 19, 17, 0))
    }

    func testInsideTheTaskInIsNotStripped() {
        let parsed = parse("remind me to check in with sam in 20m")
        XCTAssertEqual(parsed?.task, "check in with sam")
        XCTAssertEqual(parsed?.due, now.addingTimeInterval(20 * 60))
    }

    func testTaskCasePreserved() {
        XCTAssertEqual(parse("remind me to Email Anthropic at 5pm")?.task, "Email Anthropic")
    }

    func testTimeClauseAloneIsNotATask() {
        XCTAssertNil(parse("remind me to at 5pm"))
        XCTAssertNil(parse("remind in 20m"))
        XCTAssertNil(parse("remind tomorrow"))
    }

    // MARK: - Invalid times fall back to a plain reminder

    func testUnparseableTimeKeepsWholeTaskWithNoDue() {
        // Hour 45 can't be a time, so nothing is stripped and no alarm is set.
        XCTAssertEqual(parse("remind me to buy at 45"), ReminderParser.Parsed(task: "buy at 45", due: nil))
        // 5:75 is not a valid clock reading; the regex never treats it as time.
        XCTAssertEqual(parse("remind me to buy at 5:75pm")?.due, nil)
        XCTAssertEqual(parse("remind me to buy at 5:75pm")?.task, "buy at 5:75pm")
    }

    func testMeridiemHourOutOfRange() {
        // "13pm" is nonsense; keep the text as the task with no alarm.
        XCTAssertEqual(parse("remind me to nap at 13pm"), ReminderParser.Parsed(task: "nap at 13pm", due: nil))
    }
}
