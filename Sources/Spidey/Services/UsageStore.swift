import Foundation

/// Learns which results the user actually picks and turns that history into
/// score boosts ("frecency": use count weighted by how recently it happened).
///
/// Two kinds of memory are kept, persisted together in
/// ~/Library/Application Support/Spidey/usage.json:
///  - query associations: (typed query, rankingKey) pairs with a count and a
///    last-used date, so "chr" -> Chrome is learned quickly and specifically;
///  - global usage: per-key counts, a mild "things you use a lot" prior that
///    applies regardless of what was typed.
///
/// All methods are expected to be called from the main thread (the view model
/// drives both recording and lookups).
final class UsageStore {
    static let shared = UsageStore()

    // MARK: - Tunables

    /// Ceiling for the total boost applied to one result. Static provider
    /// scores span roughly 100...990 (apps 600...900), so 300 is enough to
    /// lift a habitual choice over competing static scores without letting a
    /// single click rearrange everything.
    static let maxAssociationBoost: Double = 300
    /// Ceiling for the boost earned purely from global usage with no matching
    /// query association - a light thumb on the scale, not a takeover.
    static let maxGlobalBoost: Double = 50
    /// A stored query that only prefix-matches (rather than equals) the typed
    /// query earns a discounted boost.
    static let prefixMatchFactor: Double = 0.85
    /// The frecency value at which half of a boost ceiling is granted. One
    /// selection within the hour (frecency 4) already yields ~44% of the
    /// association ceiling; three recent selections yield ~70%.
    static let associationHalfPoint: Double = 5
    static let globalHalfPoint: Double = 10
    /// Storage caps so usage.json cannot grow forever; the least recently
    /// used entries are pruned first.
    static let maxAssociations = 500
    static let maxGlobalKeys = 500

    // MARK: - Pure frecency math (unit-tested)

    /// Mozilla-style frecency: the raw use count weighted by a recency bucket.
    /// Used within the last hour x4, today x2, this week x1, older x0.5.
    static func frecency(count: Int, lastUsed: Date, now: Date) -> Double {
        guard count > 0 else { return 0 }
        let age = now.timeIntervalSince(lastUsed)
        let weight: Double
        switch age {
        case ..<3_600: weight = 4       // within the hour (or clock skew)
        case ..<86_400: weight = 2      // today
        case ..<(7 * 86_400): weight = 1 // this week
        default: weight = 0.5
        }
        return Double(count) * weight
    }

    /// Saturating curve mapping a frecency value to a boost that approaches
    /// (never exceeds) `ceiling`. `halfPoint` is the frecency at which half
    /// the ceiling is granted.
    static func boost(frecency: Double, ceiling: Double, halfPoint: Double) -> Double {
        guard frecency > 0 else { return 0 }
        return ceiling * frecency / (frecency + halfPoint)
    }

    /// 1.0 for an exact query match, a discount when one is a prefix of the
    /// other (typing "c" should surface what was chosen for "chr", and "chro"
    /// should still benefit from "chr"), nil when unrelated.
    static func matchQuality(stored: String, typed: String) -> Double? {
        guard !stored.isEmpty, !typed.isEmpty else { return nil }
        if stored == typed { return 1.0 }
        if stored.hasPrefix(typed) || typed.hasPrefix(stored) { return prefixMatchFactor }
        return nil
    }

    static func normalize(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespaces).lowercased()
    }

    // MARK: - Storage

    private struct Association: Codable {
        var query: String
        var key: String
        var count: Int
        var lastUsed: Date
    }

    private struct GlobalEntry: Codable {
        var count: Int
        var lastUsed: Date
    }

    private struct Snapshot: Codable {
        var associations: [Association] = []
        var global: [String: GlobalEntry] = [:]
    }

    private var snapshot: Snapshot
    private let fileURL: URL

    /// The default instance persists to Application Support; tests pass a
    /// temporary directory.
    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Spidey")
        fileURL = dir.appendingPathComponent("usage.json")
        if let data = try? Data(contentsOf: fileURL),
           let stored = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = stored
        } else {
            snapshot = Snapshot()
        }
    }

    // MARK: - Recording

    /// Call after the user runs a result: remembers that `rankingKey` was the
    /// answer to `query`, and bumps the key's global usage.
    func recordSelection(query: String, rankingKey: String, now: Date = Date()) {
        let q = Self.normalize(query)
        guard !rankingKey.isEmpty else { return }

        if !q.isEmpty {
            if let index = snapshot.associations.firstIndex(where: { $0.query == q && $0.key == rankingKey }) {
                snapshot.associations[index].count += 1
                snapshot.associations[index].lastUsed = now
            } else {
                snapshot.associations.append(Association(query: q, key: rankingKey, count: 1, lastUsed: now))
            }
            if snapshot.associations.count > Self.maxAssociations {
                snapshot.associations.sort { $0.lastUsed > $1.lastUsed }
                snapshot.associations.removeLast(snapshot.associations.count - Self.maxAssociations)
            }
        }

        var entry = snapshot.global[rankingKey] ?? GlobalEntry(count: 0, lastUsed: now)
        entry.count += 1
        entry.lastUsed = now
        snapshot.global[rankingKey] = entry
        if snapshot.global.count > Self.maxGlobalKeys {
            let overflow = snapshot.global.count - Self.maxGlobalKeys
            let oldest = snapshot.global.sorted { $0.value.lastUsed < $1.value.lastUsed }.prefix(overflow)
            for (key, _) in oldest { snapshot.global.removeValue(forKey: key) }
        }

        save()
    }

    // MARK: - Lookup

    /// Boosts to add to result scores for the given typed query, keyed by
    /// rankingKey. Association boosts (up to `maxAssociationBoost`) come from
    /// prefix-compatible previous queries; keys with only global usage get at
    /// most `maxGlobalBoost`. The combined value is capped at
    /// `maxAssociationBoost`.
    func boosts(for query: String, now: Date = Date()) -> [String: Double] {
        let typed = Self.normalize(query)
        guard !typed.isEmpty else { return [:] }

        var result: [String: Double] = [:]
        for association in snapshot.associations {
            guard let quality = Self.matchQuality(stored: association.query, typed: typed) else { continue }
            let f = Self.frecency(count: association.count, lastUsed: association.lastUsed, now: now)
            let b = Self.boost(frecency: f, ceiling: Self.maxAssociationBoost, halfPoint: Self.associationHalfPoint) * quality
            if b > (result[association.key] ?? 0) { result[association.key] = b }
        }
        for (key, entry) in snapshot.global {
            let f = Self.frecency(count: entry.count, lastUsed: entry.lastUsed, now: now)
            let g = Self.boost(frecency: f, ceiling: Self.maxGlobalBoost, halfPoint: Self.globalHalfPoint)
            guard g > 0 else { continue }
            result[key] = min(Self.maxAssociationBoost, (result[key] ?? 0) + g)
        }
        return result.filter { $0.value > 0 }
    }

    // MARK: - Persistence

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Learning is best-effort; a failed write only loses history.
        }
    }
}
