import XCTest
@testable import Spidey

final class AppearanceSchedulerTests: XCTestCase {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/London")!
        return c
    }()

    private func at(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: hour, minute: minute))!
    }

    private func boundary(_ now: Date) -> (date: Date, dark: Bool)? {
        AppearanceScheduler.latestBoundary(before: now, lightMinute: 360, darkMinute: 990, calendar: calendar)
    }

    func testDaytimeIsLight() {
        let b = boundary(at(12, 0))
        XCTAssertEqual(b?.date, at(6, 0))
        XCTAssertEqual(b?.dark, false)
    }

    func testEveningIsDark() {
        let b = boundary(at(16, 30))
        XCTAssertEqual(b?.date, at(16, 30))
        XCTAssertEqual(b?.dark, true)
    }

    func testEarlyMorningUsesYesterdaysDarkSwitch() {
        let b = boundary(at(3, 0))
        XCTAssertEqual(b?.dark, true)
        XCTAssertEqual(b?.date, calendar.date(byAdding: .day, value: -1, to: at(16, 30)))
    }

    func testSameTimesDisableSchedule() {
        XCTAssertNil(AppearanceScheduler.latestBoundary(before: at(12, 0), lightMinute: 600, darkMinute: 600))
    }
}
