import AppKit
import CryptoKit

// Developer utilities: "uuid", "b64/b64d <text>", "url encode/decode <text>",
// "sha256/md5 <text>", and "ts" unix timestamp conversion. Rows copy their value.
enum DevToolsProvider {
    // MARK: - Pure transforms (unit tested)

    static func base64Encode(_ text: String) -> String {
        Data(text.utf8).base64EncodedString()
    }

    static func base64Decode(_ text: String) -> String? {
        var padded = text.trimmingCharacters(in: .whitespaces)
        // Tolerate missing "=" padding, which gets stripped in URLs and logs.
        let remainder = padded.count % 4
        if remainder > 0 {
            padded += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: padded) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func urlEncode(_ text: String) -> String {
        // RFC 3986 unreserved characters only, so &, =, / all get escaped.
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }

    static func urlDecode(_ text: String) -> String? {
        text.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
    }

    static func sha256Hex(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func md5Hex(_ text: String) -> String {
        Insecure.MD5.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    // "1700000000" (seconds) or "1700000000000" (milliseconds) to a Date.
    static func date(fromEpoch raw: String) -> Date? {
        guard let value = Double(raw), value > 0 else { return nil }
        let seconds = value >= 100_000_000_000 ? value / 1000 : value
        return Date(timeIntervalSince1970: seconds)
    }

    // "2024-01-15T10:30:00Z", "2024-01-15T10:30:00.123Z", or "2024-01-15".
    static func date(fromISO raw: String) -> Date? {
        let text = raw.trimmingCharacters(in: .whitespaces)
        let formatter = ISO8601DateFormatter()
        for options: ISO8601DateFormatter.Options in [
            [.withInternetDateTime],
            [.withInternetDateTime, .withFractionalSeconds],
            [.withFullDate],
        ] {
            formatter.formatOptions = options
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    static func format(_ date: Date, utc: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if utc { formatter.timeZone = TimeZone(identifier: "UTC") }
        return formatter.string(from: date)
    }

    // MARK: - Rows

    private static func copyRow(
        _ value: String, subtitle: String, icon: String, score: Double
    ) -> ResultItem {
        ResultItem(
            title: value,
            subtitle: subtitle,
            icon: .symbol(icon),
            score: score,
            action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(value, forType: .string)
            }
        )
    }

    static func results(for query: String) -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let lowered = trimmed.lowercased()

        if lowered == "uuid" {
            let uuid = UUID().uuidString
            return [
                copyRow(uuid.lowercased(), subtitle: "Fresh UUID, lowercase. Return copies it.",
                        icon: "number.square", score: 955),
                copyRow(uuid, subtitle: "Fresh UUID, uppercase. Return copies it.",
                        icon: "number.square.fill", score: 954),
            ]
        }

        // Keyword plus argument, keeping the argument's original case.
        func argument(after keyword: String) -> String? {
            guard lowered.hasPrefix(keyword + " ") else { return nil }
            let text = String(trimmed.dropFirst(keyword.count + 1))
                .trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : text
        }

        if let text = argument(after: "b64") {
            return [copyRow(base64Encode(text), subtitle: "Base64 of \"\(text)\". Return copies it.",
                            icon: "arrow.right.square", score: 955)]
        }
        if let text = argument(after: "b64d") {
            guard let decoded = base64Decode(text) else {
                return [copyRow(text, subtitle: "Not valid base64 text.",
                                icon: "exclamationmark.square", score: 955)]
            }
            return [copyRow(decoded, subtitle: "Decoded base64. Return copies it.",
                            icon: "arrow.left.square", score: 955)]
        }
        if let text = argument(after: "url encode") {
            return [copyRow(urlEncode(text), subtitle: "Percent-encoded. Return copies it.",
                            icon: "link.badge.plus", score: 955)]
        }
        if let text = argument(after: "url decode") {
            guard let decoded = urlDecode(text) else {
                return [copyRow(text, subtitle: "Not valid percent-encoded text.",
                                icon: "exclamationmark.square", score: 955)]
            }
            return [copyRow(decoded, subtitle: "Percent-decoded. Return copies it.",
                            icon: "link", score: 955)]
        }
        if let text = argument(after: "sha256") {
            return [copyRow(sha256Hex(text), subtitle: "SHA-256 of \"\(text)\". Return copies it.",
                            icon: "lock.square", score: 955)]
        }
        if let text = argument(after: "md5") {
            return [copyRow(md5Hex(text), subtitle: "MD5 of \"\(text)\". Return copies it.",
                            icon: "lock.open", score: 955)]
        }

        if lowered == "ts" {
            let now = Date()
            let seconds = String(Int(now.timeIntervalSince1970))
            let millis = String(Int(now.timeIntervalSince1970 * 1000))
            return [
                copyRow(seconds, subtitle: "Unix timestamp now, seconds. Return copies it.",
                        icon: "clock", score: 955),
                copyRow(millis, subtitle: "Unix timestamp now, milliseconds. Return copies it.",
                        icon: "clock.fill", score: 954),
            ]
        }
        if let raw = argument(after: "ts") {
            if let parsed = date(fromEpoch: raw) {
                return [
                    copyRow(format(parsed, utc: false), subtitle: "Local time for \(raw). Return copies it.",
                            icon: "clock", score: 955),
                    copyRow(format(parsed, utc: true) + " UTC", subtitle: "UTC time for \(raw). Return copies it.",
                            icon: "globe", score: 954),
                ]
            }
            if let parsed = date(fromISO: raw) {
                let epoch = String(Int(parsed.timeIntervalSince1970))
                return [copyRow(epoch, subtitle: "Unix timestamp for \(raw). Return copies it.",
                                icon: "clock", score: 955)]
            }
        }
        return []
    }
}
