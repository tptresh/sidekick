import AppKit

// "100 usd to gbp", "5km in miles", "72f to c": unit and currency conversion.
enum ConvertProvider {
    struct Conversion {
        let value: Double
        let from: String
        let to: String
    }

    // MARK: - Unit tables

    // Alias -> (dimension, factor to the dimension's base unit).
    private static let units: [String: (dimension: String, factor: Double)] = {
        var table: [String: (String, Double)] = [:]
        func add(_ aliases: [String], _ dimension: String, _ factor: Double) {
            for alias in aliases { table[alias] = (dimension, factor) }
        }
        // Length, base meter.
        add(["mm", "millimeter", "millimeters", "millimetre", "millimetres"], "length", 0.001)
        add(["cm", "centimeter", "centimeters", "centimetre", "centimetres"], "length", 0.01)
        add(["m", "meter", "meters", "metre", "metres"], "length", 1)
        add(["km", "kilometer", "kilometers", "kilometre", "kilometres"], "length", 1000)
        add(["in", "inch", "inches"], "length", 0.0254)
        add(["ft", "foot", "feet"], "length", 0.3048)
        add(["yd", "yard", "yards"], "length", 0.9144)
        add(["mi", "mile", "miles"], "length", 1609.344)
        // Mass, base kilogram.
        add(["mg"], "mass", 0.000001)
        add(["g", "gram", "grams"], "mass", 0.001)
        add(["kg", "kilogram", "kilograms", "kilo", "kilos"], "mass", 1)
        add(["t", "tonne", "tonnes", "ton", "tons"], "mass", 1000)
        add(["oz", "ounce", "ounces"], "mass", 0.028349523)
        add(["lb", "lbs", "pound", "pounds"], "mass", 0.45359237)
        add(["st", "stone", "stones"], "mass", 6.35029318)
        // Volume, base liter.
        add(["ml", "milliliter", "milliliters", "millilitre", "millilitres"], "volume", 0.001)
        add(["l", "liter", "liters", "litre", "litres"], "volume", 1)
        add(["cup", "cups"], "volume", 0.24)
        add(["pt", "pint", "pints"], "volume", 0.473176)
        add(["gal", "gallon", "gallons"], "volume", 3.785411784)
        // Speed, base meters per second.
        add(["kmh", "kph", "km/h"], "speed", 1000.0 / 3600.0)
        add(["mph"], "speed", 0.44704)
        add(["knot", "knots", "kn"], "speed", 0.514444)
        add(["m/s", "mps"], "speed", 1)
        // Data, base byte, binary steps.
        add(["b", "byte", "bytes"], "data", 1)
        add(["kb"], "data", 1024)
        add(["mb"], "data", 1024 * 1024)
        add(["gb"], "data", 1024 * 1024 * 1024)
        add(["tb"], "data", 1024.0 * 1024 * 1024 * 1024)
        // Time, base second.
        add(["s", "sec", "secs", "second", "seconds"], "time", 1)
        add(["min", "mins", "minute", "minutes"], "time", 60)
        add(["h", "hr", "hrs", "hour", "hours"], "time", 3600)
        add(["day", "days"], "time", 86400)
        add(["week", "weeks"], "time", 604800)
        return table
    }()

    private static let temperatureAliases: Set<String> = [
        "c", "°c", "celsius", "f", "°f", "fahrenheit", "k", "kelvin",
    ]

    private static let currencySymbols: [String: String] = [
        "$": "usd", "£": "gbp", "€": "eur", "¥": "jpy",
    ]

    // MARK: - Parsing

    // Accepts "100 usd to gbp", "5km in miles", "72f to c", "$100 in gbp".
    static func parse(_ query: String) -> Conversion? {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        let pattern = #"^([$£€¥]?)([0-9]+(?:[.,][0-9]+)*)\s*([a-z°/$£€¥]*)\s+(?:to|in|as)\s+([a-z°/$£€¥]+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: lowered, range: NSRange(lowered.startIndex..., in: lowered)
              ) else { return nil }

        func group(_ index: Int) -> String {
            guard let range = Range(match.range(at: index), in: lowered) else { return "" }
            return String(lowered[range])
        }

        let symbol = group(1)
        let numberText = group(2).replacingOccurrences(of: ",", with: "")
        var fromUnit = group(3)
        var toUnit = group(4)
        if fromUnit.isEmpty { fromUnit = symbol }
        guard let value = Double(numberText), !fromUnit.isEmpty else { return nil }
        fromUnit = currencySymbols[fromUnit] ?? fromUnit
        toUnit = currencySymbols[toUnit] ?? toUnit
        return Conversion(value: value, from: fromUnit, to: toUnit)
    }

    // MARK: - Conversion

    enum Outcome {
        case value(Double, unitLabel: String, detail: String)
        case currencyPending
    }

    static func convert(_ conversion: Conversion) -> Outcome? {
        let from = conversion.from
        let to = conversion.to

        // Temperature.
        if temperatureAliases.contains(from), temperatureAliases.contains(to) {
            let celsius = toCelsius(conversion.value, unit: from)
            let result = fromCelsius(celsius, unit: to)
            return .value(result, unitLabel: temperatureLabel(to), detail: "Temperature")
        }

        // Same-dimension units.
        if let fromDef = units[from], let toDef = units[to], fromDef.dimension == toDef.dimension {
            let result = conversion.value * fromDef.factor / toDef.factor
            return .value(result, unitLabel: to, detail: fromDef.dimension.capitalized)
        }

        // Currency.
        let store = CurrencyStore.shared
        if store.isKnownCurrency(from), store.isKnownCurrency(to) {
            guard let rate = store.rate(from: from, to: to) else { return .currencyPending }
            return .value(
                conversion.value * rate,
                unitLabel: to.uppercased(),
                detail: "1 \(from.uppercased()) = \(format(rate)) \(to.uppercased()), \(store.lastUpdatedDescription)"
            )
        }
        return nil
    }

    private static func toCelsius(_ value: Double, unit: String) -> Double {
        if unit.contains("f") { return (value - 32) * 5 / 9 }
        if unit.contains("k") { return value - 273.15 }
        return value
    }

    private static func fromCelsius(_ celsius: Double, unit: String) -> Double {
        if unit.contains("f") { return celsius * 9 / 5 + 32 }
        if unit.contains("k") { return celsius + 273.15 }
        return celsius
    }

    private static func temperatureLabel(_ unit: String) -> String {
        if unit.contains("f") { return "°F" }
        if unit.contains("k") { return "K" }
        return "°C"
    }

    static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = abs(value) >= 100 ? 2 : 4
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    // MARK: - Results

    static func results(for query: String) -> [ResultItem] {
        guard let conversion = parse(query), let outcome = convert(conversion) else { return [] }
        switch outcome {
        case .currencyPending:
            CurrencyStore.shared.refreshIfStale()
            return [ResultItem(
                title: "Fetching exchange rates…",
                subtitle: "The result will appear in a moment",
                icon: .symbol("arrow.triangle.2.circlepath"),
                score: 990,
                action: {}
            )]
        case .value(let result, let unitLabel, let detail):
            let formatted = format(result)
            return [ResultItem(
                title: "= \(formatted) \(unitLabel)",
                subtitle: "\(detail). Return copies \(formatted).",
                icon: .symbol("arrow.left.arrow.right"),
                score: 990,
                action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(formatted, forType: .string)
                }
            )]
        }
    }
}
