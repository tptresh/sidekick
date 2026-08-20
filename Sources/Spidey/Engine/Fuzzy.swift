import Foundation

enum Fuzzy {
    // Returns a score in 0...1, or nil when the query does not match at all.
    // Prefix matches beat word-boundary matches beat substring matches beat subsequences.
    static func score(query: String, candidate: String) -> Double? {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        let c = candidate.lowercased()
        guard !q.isEmpty, !c.isEmpty else { return nil }

        if c == q { return 1.0 }
        if c.hasPrefix(q) { return 0.92 }
        // Any word inside the candidate starting with the query.
        let words = c.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        if words.contains(where: { $0.hasPrefix(q) }) { return 0.82 }
        if c.contains(q) { return 0.7 }
        // Initials: "gc" matches "Google Chrome".
        let initials = String(words.compactMap(\.first))
        if initials.hasPrefix(q) { return 0.68 }
        // Subsequence match, penalized by how spread out it is.
        var qIndex = q.startIndex
        var matched = 0
        for ch in c {
            if qIndex < q.endIndex, ch == q[qIndex] {
                qIndex = q.index(after: qIndex)
                matched += 1
            }
        }
        guard qIndex == q.endIndex else { return nil }
        let density = Double(matched) / Double(c.count)
        return 0.3 + 0.25 * density
    }
}
