import AppKit

// "time in tokyo": current time in any city macOS knows a time zone for.
enum TimeProvider {
    // Big cities people type that are not time zone identifiers themselves.
    static let aliases: [String: String] = [
        "nyc": "America/New_York",
        "new york": "America/New_York",
        "boston": "America/New_York",
        "miami": "America/New_York",
        "washington": "America/New_York",
        "la": "America/Los_Angeles",
        "los angeles": "America/Los_Angeles",
        "sf": "America/Los_Angeles",
        "san francisco": "America/Los_Angeles",
        "seattle": "America/Los_Angeles",
        "delhi": "Asia/Kolkata",
        "mumbai": "Asia/Kolkata",
        "bangalore": "Asia/Kolkata",
        "india": "Asia/Kolkata",
        "beijing": "Asia/Shanghai",
        "china": "Asia/Shanghai",
        "sydney": "Australia/Sydney",
        "melbourne": "Australia/Melbourne",
        "seoul": "Asia/Seoul",
        "sao paulo": "America/Sao_Paulo",
        "mexico city": "America/Mexico_City",
        "toronto": "America/Toronto",
        "vancouver": "America/Vancouver",
        "chicago": "America/Chicago",
        "texas": "America/Chicago",
        "denver": "America/Denver",
        "utc": "UTC",
        "gmt": "UTC",
    ]

    // Match a city query to time zone identifiers, aliases first.
    static func matches(for city: String) -> [String] {
        let lowered = city.lowercased().trimmingCharacters(in: .whitespaces)
        guard lowered.count >= 2 else { return [] }
        var found: [String] = []
        if let alias = aliases[lowered] {
            found.append(alias)
        }
        for identifier in TimeZone.knownTimeZoneIdentifiers where !identifier.hasPrefix("Etc/") {
            let cityName = identifier
                .split(separator: "/").last.map(String.init)?
                .replacingOccurrences(of: "_", with: " ")
                .lowercased() ?? ""
            if cityName == lowered || cityName.hasPrefix(lowered) {
                if !found.contains(identifier) { found.append(identifier) }
            }
            if found.count >= 4 { break }
        }
        return Array(found.prefix(3))
    }

    static func results(for query: String) -> [ResultItem] {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        var city: String?
        if lowered.hasPrefix("time in ") {
            city = String(lowered.dropFirst("time in ".count))
        } else if lowered.hasPrefix("time ") {
            city = String(lowered.dropFirst("time ".count))
        } else if lowered.hasSuffix(" time"), lowered.count > 5 {
            city = String(lowered.dropLast(" time".count))
        }
        guard let city, !city.isEmpty else { return [] }

        return matches(for: city).enumerated().compactMap { index, identifier in
            guard let zone = TimeZone(identifier: identifier) else { return nil }
            let formatter = DateFormatter()
            formatter.timeZone = zone
            formatter.timeStyle = .short
            let time = formatter.string(from: Date())
            formatter.dateFormat = "EEE d MMM"
            let day = formatter.string(from: Date())

            let cityName = identifier
                .split(separator: "/").last.map(String.init)?
                .replacingOccurrences(of: "_", with: " ") ?? identifier
            let offsetHours = Double(zone.secondsFromGMT() - TimeZone.current.secondsFromGMT()) / 3600
            let relation: String
            if offsetHours == 0 {
                relation = "same time as you"
            } else {
                let magnitude = abs(offsetHours)
                let amount = magnitude == magnitude.rounded()
                    ? String(Int(magnitude))
                    : String(format: "%.1f", magnitude)
                relation = "\(amount) hour\(magnitude == 1 ? "" : "s") \(offsetHours > 0 ? "ahead of" : "behind") you"
            }
            return ResultItem(
                title: "\(time) in \(cityName)",
                subtitle: "\(identifier), \(day), \(relation). Return copies it.",
                icon: .symbol("clock.fill"),
                score: 985 - Double(index),
                action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("\(time) in \(cityName)", forType: .string)
                }
            )
        }
    }
}
