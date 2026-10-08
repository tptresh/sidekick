import XCTest
@testable import Spidey

final class WeatherStoreTests: XCTestCase {
    // The shape Open-Meteo actually returns for the URL WeatherStore builds.
    private let sample = """
    {"latitude":51.5,"longitude":-0.12,
     "current":{"time":"2026-10-09T21:00","temperature_2m":10.6,"weather_code":3,"is_day":0},
     "daily":{"time":["2026-10-09"],"temperature_2m_max":[18.2],"temperature_2m_min":[10.6],
              "precipitation_probability_max":[96]}}
    """

    func testParsesOpenMeteoResponse() throws {
        let today = try XCTUnwrap(WeatherStore.parse(Data(sample.utf8)))
        XCTAssertEqual(today.temperature, 10.6)
        XCTAssertEqual(today.high, 18.2)
        XCTAssertEqual(today.low, 10.6)
        XCTAssertEqual(today.rainChance, 96)
        XCTAssertEqual(today.code, 3)
        XCTAssertFalse(today.isDay)
    }

    func testCachedForecastSurvivesRelaunch() throws {
        let suite = "WeatherStoreTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        var today = try XCTUnwrap(WeatherStore.parse(Data(sample.utf8)))
        today.place = "London"
        let cache = WeatherStore.Cache(today: today, latitude: 51.5, longitude: -0.12, fetchedAt: Date())
        WeatherStore.saveCache(cache, to: defaults)

        let loaded = try XCTUnwrap(WeatherStore.loadCache(from: defaults))
        XCTAssertEqual(loaded.today, today)
        XCTAssertEqual(loaded.latitude, 51.5)
    }
}
