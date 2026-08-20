import Foundation

extension Notification.Name {
    static let spideyRatesLoaded = Notification.Name("SpideyRatesLoaded")
}

// Daily-cached exchange rates (base USD) from open.er-api.com, so currency
// conversion works offline after the first fetch of the day.
final class CurrencyStore {
    static let shared = CurrencyStore()

    private(set) var rates: [String: Double] = [:]
    private(set) var lastUpdated: Date?
    private var fetching = false

    private let file: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Spidey/rates.json")
    }()

    private struct CachedRates: Codable {
        let updated: Date
        let rates: [String: Double]
    }

    private init() {
        if let data = try? Data(contentsOf: file),
           let cached = try? JSONDecoder().decode(CachedRates.self, from: data) {
            rates = cached.rates
            lastUpdated = cached.updated
        }
    }

    // Rate multiplier from one currency code to another, or nil while the
    // first download is still in flight.
    func rate(from: String, to: String) -> Double? {
        refreshIfStale()
        guard let fromRate = rates[from.uppercased()], let toRate = rates[to.uppercased()] else {
            return nil
        }
        return toRate / fromRate
    }

    func isKnownCurrency(_ code: String) -> Bool {
        if !rates.isEmpty {
            return rates[code.uppercased()] != nil
        }
        return Self.commonCodes.contains(code.uppercased())
    }

    var lastUpdatedDescription: String {
        guard let lastUpdated else { return "rates not loaded yet" }
        if Date().timeIntervalSince(lastUpdated) < 90 {
            return "rates updated just now"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "rates updated " + formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }

    func refreshIfStale() {
        let dayOld = lastUpdated.map { Date().timeIntervalSince($0) > 24 * 3600 } ?? true
        guard dayOld, !fetching,
              let url = URL(string: "https://open.er-api.com/v6/latest/USD") else { return }
        fetching = true
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                self.fetching = false
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let fetched = json["rates"] as? [String: Double], !fetched.isEmpty else { return }
                self.rates = fetched
                self.lastUpdated = Date()
                let cached = CachedRates(updated: Date(), rates: fetched)
                if let encoded = try? JSONEncoder().encode(cached) {
                    try? encoded.write(to: self.file)
                }
                NotificationCenter.default.post(name: .spideyRatesLoaded, object: nil)
            }
        }.resume()
    }

    // Used to recognize currency queries before the first download completes.
    static let commonCodes: Set<String> = [
        "USD", "GBP", "EUR", "JPY", "CNY", "INR", "AUD", "CAD", "CHF", "SEK",
        "NOK", "DKK", "PLN", "CZK", "HUF", "RON", "TRY", "RUB", "BRL", "MXN",
        "ARS", "CLP", "COP", "PEN", "ZAR", "NGN", "EGP", "KES", "ILS", "AED",
        "SAR", "QAR", "KWD", "BHD", "OMR", "JOD", "THB", "VND", "IDR", "MYR",
        "SGD", "HKD", "TWD", "KRW", "PHP", "NZD", "ISK", "PKR", "BDT", "LKR",
    ]
}
