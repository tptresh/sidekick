import Foundation
import CoreLocation
import Combine

// Today's weather for the menu bar panel: the Mac's location (asked for once
// in the launch permission pass) and the free Open-Meteo forecast, which needs
// no account or key. Refreshed at most every 30 minutes, when the panel opens.
final class WeatherStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherStore()

    struct Today: Equatable {
        var temperature: Double
        var high: Double
        var low: Double
        var rainChance: Int?
        var code: Int
        var isDay: Bool
        var place: String?
    }

    enum State: Equatable {
        case idle
        case loading
        case ready(Today)
        case needsLocation
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let locationManager = CLLocationManager()
    private var lastFetch: Date?
    private var lastCoordinate: CLLocationCoordinate2D?
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var authorization: CLAuthorizationStatus { locationManager.authorizationStatus }

    func requestPermission() {
        guard locationManager.authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }

    func refreshIfStale() {
        if let lastFetch, Date().timeIntervalSince(lastFetch) < 30 * 60, case .ready = state { return }
        refresh()
    }

    func refresh() {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            state = .needsLocation
        case .notDetermined:
            state = .needsLocation
            locationManager.requestWhenInUseAuthorization()
        default:
            if case .ready = state {} else { state = .loading }
            locationManager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted, .notDetermined:
            break
        default:
            if case .needsLocation = state { refresh() }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastCoordinate = location.coordinate
        fetch(for: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // A failed fix with a known previous spot still gives a forecast.
        if let lastCoordinate {
            fetch(for: CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude))
            return
        }
        DispatchQueue.main.async {
            if case .ready = self.state { return }
            self.state = .failed("Could not find your location")
        }
    }

    // MARK: - Forecast

    private func fetch(for location: CLLocation) {
        let lat = String(format: "%.3f", location.coordinate.latitude)
        let lon = String(format: "%.3f", location.coordinate.longitude)
        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)"
            + "&current=temperature_2m,weather_code,is_day"
            + "&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max"
            + "&forecast_days=1&timezone=auto") else { return }

        session.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            guard let data, error == nil, var today = Self.parse(data) else {
                DispatchQueue.main.async {
                    if case .ready = self.state { return }
                    self.state = .failed("Weather is unavailable right now")
                }
                return
            }
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                today.place = placemarks?.first?.locality ?? placemarks?.first?.name
                DispatchQueue.main.async {
                    self.lastFetch = Date()
                    self.state = .ready(today)
                }
            }
        }.resume()
    }

    static func parse(_ data: Data) -> Today? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = json["current"] as? [String: Any],
              let daily = json["daily"] as? [String: Any],
              let temperature = (current["temperature_2m"] as? NSNumber)?.doubleValue,
              let code = (current["weather_code"] as? NSNumber)?.intValue,
              let high = ((daily["temperature_2m_max"] as? [Any])?.first as? NSNumber)?.doubleValue,
              let low = ((daily["temperature_2m_min"] as? [Any])?.first as? NSNumber)?.doubleValue
        else { return nil }
        let isDay = ((current["is_day"] as? NSNumber)?.intValue ?? 1) == 1
        let rain = ((daily["precipitation_probability_max"] as? [Any])?.first as? NSNumber)?.intValue
        return Today(
            temperature: temperature, high: high, low: low,
            rainChance: rain, code: code, isDay: isDay, place: nil
        )
    }

    // WMO weather codes, as Open-Meteo reports them.
    static func describe(code: Int, isDay: Bool) -> (text: String, symbol: String) {
        switch code {
        case 0: return ("Clear", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1: return ("Mostly clear", isDay ? "sun.max.fill" : "moon.fill")
        case 2: return ("Partly cloudy", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3: return ("Overcast", "cloud.fill")
        case 45, 48: return ("Fog", "cloud.fog.fill")
        case 51, 53, 55, 56, 57: return ("Drizzle", "cloud.drizzle.fill")
        case 61, 63, 66: return ("Rain", "cloud.rain.fill")
        case 65, 67: return ("Heavy rain", "cloud.heavyrain.fill")
        case 71, 73, 75, 77: return ("Snow", "cloud.snow.fill")
        case 80, 81, 82: return ("Showers", isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill")
        case 85, 86: return ("Snow showers", "cloud.snow.fill")
        case 95, 96, 99: return ("Thunderstorms", "cloud.bolt.rain.fill")
        default: return ("Weather", "cloud.fill")
        }
    }
}
