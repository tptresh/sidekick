import Foundation
import CoreLocation
import Combine

// Today's weather for the menu bar panel, from the free Open-Meteo forecast
// (no account or key) at the Mac's approximate location.
//
// The panel must never wait on the network: the last forecast is saved and
// shown straight away, the app refreshes in the background at launch and every
// 30 minutes, and the remembered position is used instead of waiting for a new
// location fix. The town name is only looked up again after a real move.
final class WeatherStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherStore()

    struct Today: Codable, Equatable {
        var temperature: Double
        var high: Double
        var low: Double
        var rainChance: Int?
        var code: Int
        var isDay: Bool
        var place: String?
    }

    struct Cache: Codable {
        var today: Today
        var latitude: Double
        var longitude: Double
        var fetchedAt: Date
    }

    enum State: Equatable {
        case placeholder
        case ready(Today)
        case needsLocation
        case failed(String)
    }

    enum LocationSource: Equatable { case manual, coreLocation, network }

    struct Place: Equatable {
        var name: String
        var latitude: Double
        var longitude: Double
    }

    @Published private(set) var state: State = .placeholder
    @Published private(set) var updatedAt: Date?

    private static let cacheKey = "weatherCache"
    private static let refreshInterval: TimeInterval = 30 * 60
    // Moving less than this keeps the same town name and forecast spot.
    private static let moveThreshold: CLLocationDistance = 5_000

    private let locationManager = CLLocationManager()
    private var cache: Cache?
    private var timer: Timer?
    private var isFetching = false
    private var coreLocationFailed = false
    private var locationTimeout: Timer?
    private var settingsObserver: AnyCancellable?
    // Bumped on every refresh so a slow lookup for an old city cannot win.
    private var generation = 0
    private var cachedSource: LocationSource?
    private static let locationTimeoutSeconds: TimeInterval = 15
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        if let cached = Self.loadCache(from: .standard) {
            cache = cached
            state = .ready(cached.today)
            updatedAt = cached.fetchedAt
        }
        settingsObserver = SettingsStore.shared.$weatherCity
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.coreLocationFailed = false
                self?.refresh()
            }
    }

    private var manualCity: String? {
        let city = SettingsStore.shared.weatherCity.trimmingCharacters(in: .whitespacesAndNewlines)
        return city.isEmpty ? nil : city
    }

    private var isAuthorized: Bool {
        switch locationManager.authorizationStatus {
        case .notDetermined, .denied, .restricted: false
        default: true
        }
    }

    var authorization: CLAuthorizationStatus { locationManager.authorizationStatus }

    func requestPermission() {
        guard locationManager.authorizationStatus == .notDetermined else { return }
        locationManager.requestWhenInUseAuthorization()
    }

    // Called once at launch.
    func start() {
        refresh()
        let timer = Timer(timeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = 60
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func refreshIfStale() {
        if let updatedAt, Date().timeIntervalSince(updatedAt) < Self.refreshInterval { return }
        refresh()
    }

    func refresh() {
        generation += 1
        let current = generation
        stopLocating()
        if let city = manualCity {
            resolveManual(city, generation: current)
            return
        }
        switch locationManager.authorizationStatus {
        case .notDetermined:
            if cache == nil { state = .needsLocation }
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            resolveNetwork(generation: current)
        default:
            // Forecast for the remembered spot right away; a fresh fix only
            // matters if the Mac has actually moved.
            if cachedSource != .manual, let known = locationManager.location ?? cache.map({
                CLLocation(latitude: $0.latitude, longitude: $0.longitude)
            }) {
                fetch(for: known)
            }
            startLocating(generation: current)
        }
    }

    // requestLocation() times out on some Macs even when access is granted, so
    // listen for updates, take the first fix, and give up after a while.
    private func startLocating(generation current: Int) {
        locationManager.startUpdatingLocation()
        let timer = Timer(timeInterval: Self.locationTimeoutSeconds, repeats: false) { [weak self] _ in
            guard let self, self.generation == current else { return }
            self.coreLocationGaveUp()
        }
        RunLoop.main.add(timer, forMode: .common)
        locationTimeout = timer
    }

    private func stopLocating() {
        locationManager.stopUpdatingLocation()
        locationTimeout?.invalidate()
        locationTimeout = nil
    }

    private func coreLocationGaveUp() {
        stopLocating()
        coreLocationFailed = true
        resolveNetwork(generation: generation)
    }

    // MARK: - Fallback locations

    static func locationSource(authorized: Bool, coreLocationFailed: Bool, manualCity: String?) -> LocationSource {
        if let city = manualCity?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty {
            return .manual
        }
        return authorized && !coreLocationFailed ? .coreLocation : .network
    }

    static func parseGeocoding(_ data: Data) -> Place? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let first = (json["results"] as? [[String: Any]])?.first,
              let name = first["name"] as? String,
              let latitude = (first["latitude"] as? NSNumber)?.doubleValue,
              let longitude = (first["longitude"] as? NSNumber)?.doubleValue
        else { return nil }
        return Place(name: name, latitude: latitude, longitude: longitude)
    }

    static func parseNetworkLocation(_ data: Data) -> Place? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["success"] as? Bool) == true,
              let latitude = (json["latitude"] as? NSNumber)?.doubleValue,
              let longitude = (json["longitude"] as? NSNumber)?.doubleValue
        else { return nil }
        let name = (json["city"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? (json["region"] as? String) ?? (json["country"] as? String) ?? "Your area"
        return Place(name: name, latitude: latitude, longitude: longitude)
    }

    private func resolveManual(_ city: String, generation current: Int) {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [URLQueryItem(name: "name", value: city), URLQueryItem(name: "count", value: "1")]
        guard let url = components?.url else { return }
        session.dataTask(with: url) { [weak self] data, _, _ in
            let place = data.flatMap(Self.parseGeocoding)
            DispatchQueue.main.async {
                guard let self, self.generation == current else { return }
                guard let place else {
                    // A dropped connection keeps the last forecast; only an
                    // answer with no match means the city name is wrong.
                    if data != nil || self.cache == nil {
                        self.state = .failed(data == nil
                            ? "Weather is unavailable right now"
                            : "Could not find \"\(city)\"")
                    }
                    return
                }
                self.fetch(for: place, source: .manual)
            }
        }.resume()
    }

    private func resolveNetwork(generation current: Int) {
        guard let url = URL(string: "https://ipwho.is/") else { return }
        session.dataTask(with: url) { [weak self] data, _, _ in
            let place = data.flatMap(Self.parseNetworkLocation)
            DispatchQueue.main.async {
                guard let self, self.generation == current else { return }
                guard let place else {
                    if self.cache == nil || self.cachedSource == .manual {
                        self.state = .failed("Could not find your location")
                    }
                    return
                }
                self.fetch(for: place, source: .network)
            }
        }.resume()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            break
        default:
            if case .needsLocation = state { refresh() }
            else if !isAuthorized { refresh() }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, manualCity == nil else { return }
        stopLocating()
        coreLocationFailed = false
        if let cache, cachedSource != .manual, cachedSource != .network {
            let previous = CLLocation(latitude: cache.latitude, longitude: cache.longitude)
            guard location.distance(from: previous) > Self.moveThreshold else { return }
        }
        fetch(for: location, force: true, source: .coreLocation)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // A transient "location unknown" keeps waiting for the timeout.
        if (error as? CLError)?.code == .locationUnknown { return }
        guard manualCity == nil else { return }
        coreLocationGaveUp()
    }

    // MARK: - Forecast

    private func fetch(for place: Place, source: LocationSource) {
        fetch(
            for: CLLocation(latitude: place.latitude, longitude: place.longitude),
            force: true, source: source, placeName: place.name
        )
    }

    private func fetch(for location: CLLocation, force: Bool = false,
                       source: LocationSource? = nil, placeName: String? = nil) {
        guard !isFetching || force else { return }
        let lat = String(format: "%.3f", location.coordinate.latitude)
        let lon = String(format: "%.3f", location.coordinate.longitude)
        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)"
            + "&current=temperature_2m,weather_code,is_day"
            + "&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max"
            + "&forecast_days=1&timezone=auto") else { return }
        isFetching = true

        session.dataTask(with: url) { [weak self] data, _, error in
            let parsed = data.flatMap(Self.parse)
            DispatchQueue.main.async {
                guard let self else { return }
                self.isFetching = false
                guard error == nil, var today = parsed else {
                    if self.cache == nil { self.state = .failed("Weather is unavailable right now") }
                    return
                }
                let moved = self.cache.map {
                    location.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
                        > Self.moveThreshold
                } ?? true
                today.place = placeName ?? (moved ? nil : self.cache?.today.place)
                if let source { self.cachedSource = source }
                self.store(today, at: location)
                if today.place == nil { self.lookUpPlace(for: location) }
            }
        }.resume()
    }

    private func store(_ today: Today, at location: CLLocation) {
        let cache = Cache(
            today: today,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            fetchedAt: Date()
        )
        self.cache = cache
        state = .ready(today)
        updatedAt = cache.fetchedAt
        Self.saveCache(cache, to: .standard)
    }

    private func lookUpPlace(for location: CLLocation) {
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self, let place = placemarks?.first?.locality ?? placemarks?.first?.name,
                  var cache = self.cache else { return }
            cache.today.place = place
            self.cache = cache
            self.state = .ready(cache.today)
            Self.saveCache(cache, to: .standard)
        }
    }

    // MARK: - Persistence

    static func saveCache(_ cache: Cache, to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(cache) {
            defaults.set(data, forKey: cacheKey)
        }
    }

    static func loadCache(from defaults: UserDefaults) -> Cache? {
        guard let data = defaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(Cache.self, from: data)
    }

    // MARK: - Parsing

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
