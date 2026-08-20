import AppKit
import Security

// "pw" or "pw 24": copies a freshly generated random password.
enum PasswordProvider {
    static let lowercase = "abcdefghijklmnopqrstuvwxyz"
    static let uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    static let digits = "0123456789"
    static let symbols = "!@#$%^&*-_=+?"

    static func generate(length: Int, includeSymbols: Bool) -> String {
        // Swift's system generator is cryptographically secure on Apple
        // platforms, and randomElement avoids modulo bias.
        let pool = Array(lowercase + uppercase + digits + (includeSymbols ? symbols : ""))
        return String((0..<length).map { _ in pool.randomElement()! })
    }

    static func parse(_ query: String) -> Int? {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        let parts = lowered.split(separator: " ")
        guard let first = parts.first, first == "pw" || first == "password", parts.count <= 2 else {
            return nil
        }
        if parts.count == 2 {
            guard let length = Int(parts[1]) else { return nil }
            return min(max(length, 6), 128)
        }
        return 20
    }

    static func results(for query: String) -> [ResultItem] {
        guard let length = parse(query) else { return [] }
        let strong = generate(length: length, includeSymbols: true)
        let simple = generate(length: length, includeSymbols: false)
        func row(_ password: String, kind: String, score: Double) -> ResultItem {
            ResultItem(
                title: password,
                subtitle: "Random \(length) character password, \(kind). Return copies it.",
                icon: .symbol("key.fill"),
                score: score,
                action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(password, forType: .string)
                }
            )
        }
        return [
            row(strong, kind: "letters, digits, and symbols", score: 985),
            row(simple, kind: "letters and digits only", score: 984),
        ]
    }
}
