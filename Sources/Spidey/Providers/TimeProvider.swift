import AppKit

// "time in tokyo": current time in any city macOS knows a time zone for.
enum TimeProvider {
    struct Match {
        let identifier: String
        let label: String
    }

    // Places people type that the time zone database does not name directly:
    // "new delhi" lives in Asia/Kolkata, "hk" in Asia/Hong_Kong, and country
    // names never appear in an identifier at all.
    struct City {
        let label: String
        let identifier: String
        let names: [String]
    }

    // The order here breaks ties, so the better known place comes first.
    static let cities: [City] = [
        City(label: "New York", identifier: "America/New_York",
             names: ["new york", "new york city", "nyc", "manhattan", "brooklyn", "east coast"]),
        City(label: "Boston", identifier: "America/New_York", names: ["boston"]),
        City(label: "Washington DC", identifier: "America/New_York",
             names: ["washington", "washington dc", "dc"]),
        City(label: "Philadelphia", identifier: "America/New_York", names: ["philadelphia", "philly"]),
        City(label: "Atlanta", identifier: "America/New_York", names: ["atlanta"]),
        City(label: "Miami", identifier: "America/New_York", names: ["miami", "florida", "orlando"]),
        City(label: "Detroit", identifier: "America/Detroit", names: ["detroit"]),
        City(label: "Toronto", identifier: "America/Toronto", names: ["toronto", "canada"]),
        City(label: "Ottawa", identifier: "America/Toronto", names: ["ottawa"]),
        City(label: "Montreal", identifier: "America/Toronto", names: ["montreal"]),
        City(label: "Chicago", identifier: "America/Chicago", names: ["chicago"]),
        City(label: "Houston", identifier: "America/Chicago", names: ["houston"]),
        City(label: "Dallas", identifier: "America/Chicago", names: ["dallas", "fort worth"]),
        City(label: "Austin", identifier: "America/Chicago", names: ["austin", "texas"]),
        City(label: "Minneapolis", identifier: "America/Chicago", names: ["minneapolis"]),
        City(label: "New Orleans", identifier: "America/Chicago", names: ["new orleans"]),
        City(label: "Denver", identifier: "America/Denver", names: ["denver", "colorado"]),
        City(label: "Salt Lake City", identifier: "America/Denver", names: ["salt lake city", "slc", "utah"]),
        City(label: "Phoenix", identifier: "America/Phoenix", names: ["phoenix", "arizona"]),
        City(label: "Los Angeles", identifier: "America/Los_Angeles",
             names: ["los angeles", "la", "hollywood"]),
        City(label: "San Diego", identifier: "America/Los_Angeles", names: ["san diego"]),
        City(label: "Las Vegas", identifier: "America/Los_Angeles", names: ["las vegas", "vegas"]),
        City(label: "San Francisco", identifier: "America/Los_Angeles",
             names: ["san francisco", "sf", "bay area", "silicon valley", "palo alto", "cupertino"]),
        City(label: "Seattle", identifier: "America/Los_Angeles", names: ["seattle", "west coast"]),
        City(label: "Portland", identifier: "America/Los_Angeles", names: ["portland", "oregon"]),
        City(label: "Vancouver", identifier: "America/Vancouver", names: ["vancouver"]),

        City(label: "Honolulu", identifier: "Pacific/Honolulu", names: ["honolulu", "hawaii"]),

        City(label: "Anchorage", identifier: "America/Anchorage", names: ["anchorage", "alaska"]),
        City(label: "Mexico City", identifier: "America/Mexico_City", names: ["mexico city", "mexico", "cdmx"]),
        City(label: "Sao Paulo", identifier: "America/Sao_Paulo", names: ["sao paulo", "brazil", "brasilia"]),
        City(label: "Rio de Janeiro", identifier: "America/Sao_Paulo", names: ["rio", "rio de janeiro"]),
        City(label: "Buenos Aires", identifier: "America/Argentina/Buenos_Aires",
             names: ["buenos aires", "argentina"]),
        City(label: "Santiago", identifier: "America/Santiago", names: ["santiago", "chile"]),
        City(label: "Lima", identifier: "America/Lima", names: ["lima", "peru"]),
        City(label: "Bogota", identifier: "America/Bogota", names: ["bogota", "colombia"]),

        City(label: "London", identifier: "Europe/London",
             names: ["london", "uk", "england", "britain", "great britain"]),
        City(label: "Edinburgh", identifier: "Europe/London", names: ["edinburgh", "scotland", "glasgow"]),
        City(label: "Manchester", identifier: "Europe/London",
             names: ["manchester", "birmingham", "liverpool"]),
        City(label: "Cardiff", identifier: "Europe/London", names: ["cardiff", "wales"]),
        City(label: "Dublin", identifier: "Europe/Dublin", names: ["dublin", "ireland"]),
        City(label: "Paris", identifier: "Europe/Paris", names: ["paris", "france"]),
        City(label: "Lyon", identifier: "Europe/Paris", names: ["lyon", "marseille", "nice", "bordeaux"]),
        City(label: "Berlin", identifier: "Europe/Berlin", names: ["berlin", "germany"]),
        City(label: "Munich", identifier: "Europe/Berlin", names: ["munich", "muenchen"]),
        City(label: "Frankfurt", identifier: "Europe/Berlin", names: ["frankfurt"]),
        City(label: "Hamburg", identifier: "Europe/Berlin", names: ["hamburg", "cologne", "dusseldorf"]),
        City(label: "Amsterdam", identifier: "Europe/Amsterdam",
             names: ["amsterdam", "netherlands", "holland", "rotterdam"]),
        City(label: "Brussels", identifier: "Europe/Brussels", names: ["brussels", "belgium"]),
        City(label: "Madrid", identifier: "Europe/Madrid", names: ["madrid", "spain"]),
        City(label: "Barcelona", identifier: "Europe/Madrid", names: ["barcelona", "valencia", "seville"]),
        City(label: "Lisbon", identifier: "Europe/Lisbon", names: ["lisbon", "portugal", "porto"]),
        City(label: "Rome", identifier: "Europe/Rome", names: ["rome", "italy"]),
        City(label: "Milan", identifier: "Europe/Rome", names: ["milan", "milano"]),
        City(label: "Naples", identifier: "Europe/Rome", names: ["naples", "venice", "florence", "turin"]),
        City(label: "Zurich", identifier: "Europe/Zurich", names: ["zurich", "switzerland", "basel", "bern"]),
        City(label: "Geneva", identifier: "Europe/Zurich", names: ["geneva"]),
        City(label: "Vienna", identifier: "Europe/Vienna", names: ["vienna", "austria"]),
        City(label: "Stockholm", identifier: "Europe/Stockholm", names: ["stockholm", "sweden"]),
        City(label: "Oslo", identifier: "Europe/Oslo", names: ["oslo", "norway"]),
        City(label: "Copenhagen", identifier: "Europe/Copenhagen", names: ["copenhagen", "denmark"]),
        City(label: "Helsinki", identifier: "Europe/Helsinki", names: ["helsinki", "finland"]),
        City(label: "Warsaw", identifier: "Europe/Warsaw", names: ["warsaw", "poland", "krakow"]),
        City(label: "Prague", identifier: "Europe/Prague", names: ["prague", "czechia", "czech republic"]),
        City(label: "Budapest", identifier: "Europe/Budapest", names: ["budapest", "hungary"]),
        City(label: "Athens", identifier: "Europe/Athens", names: ["athens", "greece"]),
        City(label: "Istanbul", identifier: "Europe/Istanbul", names: ["istanbul", "turkey", "ankara"]),
        City(label: "Bucharest", identifier: "Europe/Bucharest", names: ["bucharest", "romania"]),
        City(label: "Moscow", identifier: "Europe/Moscow", names: ["moscow", "russia"]),
        City(label: "St Petersburg", identifier: "Europe/Moscow", names: ["st petersburg", "saint petersburg"]),
        City(label: "Kyiv", identifier: "Europe/Kyiv", names: ["kyiv", "kiev", "ukraine"]),

        City(label: "Reykjavik", identifier: "Atlantic/Reykjavik", names: ["reykjavik", "iceland"]),

        City(label: "Dubai", identifier: "Asia/Dubai",
             names: ["dubai", "uae", "emirates", "united arab emirates"]),
        City(label: "Abu Dhabi", identifier: "Asia/Dubai", names: ["abu dhabi"]),
        City(label: "Doha", identifier: "Asia/Qatar", names: ["doha", "qatar"]),
        City(label: "Riyadh", identifier: "Asia/Riyadh", names: ["riyadh", "saudi", "saudi arabia"]),
        City(label: "Jeddah", identifier: "Asia/Riyadh", names: ["jeddah", "mecca", "makkah"]),
        City(label: "Tel Aviv", identifier: "Asia/Jerusalem", names: ["tel aviv", "israel"]),
        City(label: "Jerusalem", identifier: "Asia/Jerusalem", names: ["jerusalem"]),
        City(label: "Tehran", identifier: "Asia/Tehran", names: ["tehran", "iran"]),

        City(label: "Cairo", identifier: "Africa/Cairo", names: ["cairo", "egypt"]),
        City(label: "Lagos", identifier: "Africa/Lagos", names: ["lagos", "nigeria", "abuja"]),
        City(label: "Nairobi", identifier: "Africa/Nairobi", names: ["nairobi", "kenya"]),
        City(label: "Johannesburg", identifier: "Africa/Johannesburg",
             names: ["johannesburg", "south africa", "pretoria", "durban"]),
        City(label: "Cape Town", identifier: "Africa/Johannesburg", names: ["cape town", "capetown"]),
        City(label: "Casablanca", identifier: "Africa/Casablanca",
             names: ["casablanca", "morocco", "marrakech"]),
        City(label: "Accra", identifier: "Africa/Accra", names: ["accra", "ghana"]),
        City(label: "Addis Ababa", identifier: "Africa/Addis_Ababa", names: ["addis ababa", "ethiopia"]),

        City(label: "New Delhi", identifier: "Asia/Kolkata",
             names: ["new delhi", "delhi", "india", "gurgaon", "gurugram", "noida"]),
        City(label: "Mumbai", identifier: "Asia/Kolkata", names: ["mumbai", "bombay"]),
        City(label: "Bengaluru", identifier: "Asia/Kolkata", names: ["bengaluru", "bangalore"]),
        City(label: "Hyderabad", identifier: "Asia/Kolkata", names: ["hyderabad"]),
        City(label: "Chennai", identifier: "Asia/Kolkata", names: ["chennai", "madras"]),
        City(label: "Pune", identifier: "Asia/Kolkata", names: ["pune"]),
        City(label: "Karachi", identifier: "Asia/Karachi", names: ["karachi", "pakistan"]),
        City(label: "Lahore", identifier: "Asia/Karachi", names: ["lahore", "islamabad"]),
        City(label: "Dhaka", identifier: "Asia/Dhaka", names: ["dhaka", "bangladesh"]),
        City(label: "Colombo", identifier: "Asia/Colombo", names: ["colombo", "sri lanka"]),
        City(label: "Kathmandu", identifier: "Asia/Kathmandu", names: ["kathmandu", "nepal"]),
        City(label: "Beijing", identifier: "Asia/Shanghai", names: ["beijing", "peking", "china"]),
        City(label: "Shanghai", identifier: "Asia/Shanghai", names: ["shanghai"]),
        City(label: "Shenzhen", identifier: "Asia/Shanghai", names: ["shenzhen", "guangzhou"]),
        City(label: "Hong Kong", identifier: "Asia/Hong_Kong", names: ["hong kong", "hk", "hkg", "hongkong"]),
        City(label: "Macau", identifier: "Asia/Macau", names: ["macau", "macao"]),
        City(label: "Taipei", identifier: "Asia/Taipei", names: ["taipei", "taiwan"]),
        City(label: "Tokyo", identifier: "Asia/Tokyo", names: ["tokyo", "japan"]),
        City(label: "Osaka", identifier: "Asia/Tokyo", names: ["osaka", "kyoto", "yokohama"]),
        City(label: "Seoul", identifier: "Asia/Seoul", names: ["seoul", "korea", "south korea", "busan"]),
        City(label: "Singapore", identifier: "Asia/Singapore", names: ["singapore", "sg", "sgp"]),
        City(label: "Kuala Lumpur", identifier: "Asia/Kuala_Lumpur", names: ["kuala lumpur", "kl", "malaysia"]),
        City(label: "Jakarta", identifier: "Asia/Jakarta", names: ["jakarta", "indonesia"]),
        City(label: "Bali", identifier: "Asia/Makassar", names: ["bali", "denpasar"]),
        City(label: "Bangkok", identifier: "Asia/Bangkok", names: ["bangkok", "thailand"]),
        City(label: "Phuket", identifier: "Asia/Bangkok", names: ["phuket", "chiang mai"]),
        City(label: "Ho Chi Minh City", identifier: "Asia/Ho_Chi_Minh",
             names: ["ho chi minh", "ho chi minh city", "saigon", "vietnam"]),
        City(label: "Hanoi", identifier: "Asia/Ho_Chi_Minh", names: ["hanoi"]),
        City(label: "Manila", identifier: "Asia/Manila", names: ["manila", "philippines"]),
        City(label: "Almaty", identifier: "Asia/Almaty", names: ["almaty", "kazakhstan"]),
        City(label: "Tashkent", identifier: "Asia/Tashkent", names: ["tashkent", "uzbekistan"]),

        City(label: "Sydney", identifier: "Australia/Sydney", names: ["sydney", "australia", "canberra"]),
        City(label: "Melbourne", identifier: "Australia/Melbourne", names: ["melbourne"]),
        City(label: "Brisbane", identifier: "Australia/Brisbane",
             names: ["brisbane", "queensland", "gold coast"]),
        City(label: "Perth", identifier: "Australia/Perth", names: ["perth"]),
        City(label: "Adelaide", identifier: "Australia/Adelaide", names: ["adelaide"]),

        City(label: "Auckland", identifier: "Pacific/Auckland", names: ["auckland", "new zealand", "nz"]),
        City(label: "Wellington", identifier: "Pacific/Auckland", names: ["wellington", "christchurch"]),
        City(label: "Fiji", identifier: "Pacific/Fiji", names: ["fiji", "suva"]),

        City(label: "UTC", identifier: "UTC", names: ["utc", "gmt", "zulu", "coordinated universal time"]),
    ]

    // Spellings of the zero offset that would only repeat the curated UTC row.
    private static let utcAliases: Set<String> = ["GMT", "GMT0", "Greenwich", "Universal", "Zulu", "UTC"]

    // Lowercased, unaccented, punctuation dropped: "St. Petersburg" and
    // "Zürich?" have to reach the same names people typed by hand.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let cleaned = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        let words = String(cleaned).split(separator: " ").map(String.init)
        var trimmed = words
        if trimmed.first == "the" { trimmed.removeFirst() }
        return trimmed.joined(separator: " ").lowercased()
    }

    // Optimal string alignment distance, which counts a swap of neighbouring
    // letters as one edit so "dehli" stays one step from "delhi".
    static func editDistance(_ first: String, _ second: String, limit: Int) -> Int {
        let a = Array(first)
        let b = Array(second)
        guard !a.isEmpty, !b.isEmpty else { return max(a.count, b.count) }
        if abs(a.count - b.count) > limit { return limit + 1 }

        var twoRowsBack: [Int] = []
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [Int](repeating: 0, count: b.count + 1)
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                var best = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    best = min(best, twoRowsBack[j - 2] + 1)
                }
                current[j] = best
            }
            twoRowsBack = previous
            previous = current
        }
        return previous[b.count]
    }

    // How well one name a person might type fits the query, or nil for no fit.
    private static func score(query: String, name: String) -> Double? {
        if name == query { return 100 }
        if name.hasPrefix(query), query.count >= 2 { return 85 }

        let words = name.split(separator: " ").map(String.init)
        if words.count > 1 {
            if words.dropFirst().contains(where: { $0.hasPrefix(query) }), query.count >= 3 { return 75 }
            let initials = String(words.compactMap(\.first))
            if initials == query, query.count >= 2 { return 72 }
        }
        if query.count >= 4, name.contains(query) { return 68 }

        // One typo forgiven and no more, so nonsense still finds nothing and
        // "portland" is never answered with Poland.
        guard query.count >= 4, editDistance(query, name, limit: 1) <= 1 else { return nil }
        return 55
    }

    // Match a city query to time zones, best guess first.
    static func rankedMatches(for city: String) -> [Match] {
        let query = normalize(city)
        guard query.count >= 2 else { return [] }

        var scored: [(match: Match, score: Double)] = []
        for (index, entry) in cities.enumerated() {
            let best = entry.names.compactMap { score(query: query, name: $0) }.max()
            guard let best else { continue }
            // Curated places win ties against the raw database, and earlier
            // entries win ties against later ones.
            scored.append((Match(identifier: entry.identifier, label: entry.label),
                           best + 2 - Double(index) * 0.001))
        }

        for identifier in TimeZone.knownTimeZoneIdentifiers
        where !identifier.hasPrefix("Etc/") && !utcAliases.contains(identifier) {
            let label = identifier
                .split(separator: "/").last.map(String.init)?
                .replacingOccurrences(of: "_", with: " ") ?? identifier
            guard let best = score(query: query, name: normalize(label)) else { continue }
            // Identifiers with no region ("EST", "Japan", "GMT") are legacy
            // aliases: honour them typed in full, but never fuzzily, or they
            // shadow the real city they stand for.
            if !identifier.contains("/"), best < 100 { continue }
            scored.append((Match(identifier: identifier, label: label), best))
        }

        // The database repeats places a curated entry already covers, so
        // "montreal" must not come back twice.
        var seenIdentifiers = Set<String>()
        var seenLabels = Set<String>()
        return scored
            .sorted { $0.score > $1.score }
            .filter {
                seenIdentifiers.insert($0.match.identifier).inserted
                    && seenLabels.insert($0.match.label).inserted
            }
            .prefix(3)
            .map(\.match)
    }

    static func matches(for city: String) -> [String] {
        rankedMatches(for: city).map(\.identifier)
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

        return rankedMatches(for: city).enumerated().compactMap { index, match in
            guard let zone = TimeZone(identifier: match.identifier) else { return nil }
            let formatter = DateFormatter()
            formatter.timeZone = zone
            formatter.timeStyle = .short
            let time = formatter.string(from: Date())
            formatter.dateFormat = "EEE d MMM"
            let day = formatter.string(from: Date())

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
                title: "\(time) in \(match.label)",
                subtitle: "\(match.identifier), \(day), \(relation). Return copies it.",
                icon: .symbol("clock.fill"),
                score: 985 - Double(index),
                action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("\(time) in \(match.label)", forType: .string)
                }
            )
        }
    }
}
