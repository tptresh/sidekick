import AppKit
import UserNotifications

// Running timers: fires a notification (and a sound) when one ends.
final class TimerCenter {
    static let shared = TimerCenter()

    struct Entry: Identifiable {
        let id: UUID
        let label: String
        let fireDate: Date
        let timer: Timer

        var remainingDescription: String {
            let remaining = max(0, Int(fireDate.timeIntervalSinceNow.rounded()))
            let hours = remaining / 3600
            let minutes = (remaining % 3600) / 60
            let seconds = remaining % 60
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            }
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private(set) var entries: [Entry] = []
    private var requestedAuthorization = false

    // Notifications need a real .app bundle (not .build or the test runner).
    private static let canNotify = Bundle.main.bundleURL.pathExtension == "app"

    private static let storeKey = "runningTimers"

    private struct Stored: Codable {
        let id: UUID
        let label: String
        let fireDate: Date
    }

    private func persist() {
        let stored = entries.map { Stored(id: $0.id, label: $0.label, fireDate: $0.fireDate) }
        UserDefaults.standard.set(try? JSONEncoder().encode(stored), forKey: Self.storeKey)
    }

    // Timers still running when the app last quit. Ones that ended meanwhile
    // were already delivered by macOS, so they are dropped, not re-announced.
    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.storeKey),
              let stored = try? JSONDecoder().decode([Stored].self, from: data) else { return }
        for item in stored {
            let remaining = item.fireDate.timeIntervalSinceNow
            guard remaining > 0 else { continue }
            schedule(id: item.id, label: item.label, fireDate: item.fireDate, remaining: remaining)
        }
        persist()
    }

    private func schedule(id: UUID, label: String, fireDate: Date, remaining: TimeInterval) {
        let timer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            self?.fire(id: id, label: label)
        }
        entries.append(Entry(id: id, label: label, fireDate: fireDate, timer: timer))
    }

    private init() {
        restore()
        // A Timer does not count time asleep, so after a long lid-close it
        // would ring late. Re-arm everything against its real end time.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.rearmAfterWake() }
    }

    private func rearmAfterWake() {
        let pending = entries
        entries.removeAll()
        for entry in pending {
            entry.timer.invalidate()
            let remaining = entry.fireDate.timeIntervalSinceNow
            if remaining <= 0 {
                fire(id: entry.id, label: entry.label)
                continue
            }
            schedule(id: entry.id, label: entry.label, fireDate: entry.fireDate, remaining: remaining)
        }
        persist()
    }

    // Parses "10m tea", "1h30m pasta", "90s", "10 minutes laundry", and the
    // spoken forms the phrasing layer passes through: "5 minutes", "an hour",
    // "half an hour", "for 5 minutes for pasta".
    // Returns the duration and whatever text is left over as the label.
    static func parse(_ text: String) -> (seconds: TimeInterval, label: String)? {
        let trimmed = spellOutDurations(text.trimmingCharacters(in: .whitespaces))
        guard !trimmed.isEmpty else { return nil }
        // (?![a-z]) instead of \b so "1h30m" still matches the "1h" part, and
        // [\s-]* so a hyphenated "25-minute" reads the same as "25 minute".
        let pattern = #"(\d+(?:\.\d+)?)[\s-]*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)(?![a-z])"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let fullRange = NSRange(trimmed.startIndex..., in: trimmed)
        let matches = regex.matches(in: trimmed, range: fullRange)

        var total: TimeInterval = 0
        var label = trimmed
        for match in matches.reversed() {
            guard let whole = Range(match.range, in: trimmed),
                  let numberRange = Range(match.range(at: 1), in: trimmed),
                  let unitRange = Range(match.range(at: 2), in: trimmed),
                  let value = Double(trimmed[numberRange]) else { continue }
            let unit = trimmed[unitRange].lowercased()
            if unit.hasPrefix("h") {
                total += value * 3600
            } else if unit.hasPrefix("m") {
                total += value * 60
            } else {
                total += value
            }
            label.removeSubrange(whole)
        }

        // A bare number means minutes: "timer 10 tea".
        if matches.isEmpty {
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard let minutes = Double(parts[0]), minutes > 0 else { return nil }
            total = minutes * 60
            label = parts.count > 1 ? String(parts[1]) : ""
        }

        guard total > 0, total <= 24 * 3600 else { return nil }
        let cleanLabel = cleanUpLabel(label)
        return (total, cleanLabel.isEmpty ? "Timer" : cleanLabel)
    }

    // Spoken durations the digit-and-unit regex cannot see on its own.
    private static func spellOutDurations(_ text: String) -> String {
        var working = text
        let replacements: [(String, String)] = [
            ("an hour and a half", "90 minutes"),
            ("a minute and a half", "90 seconds"),
            ("half an hour", "30 minutes"),
            ("half a minute", "30 seconds"),
            ("quarter of an hour", "15 minutes"),
            ("an hour", "1 hour"),
            ("a hour", "1 hour"),
            ("a minute", "1 minute"),
            ("a second", "1 second"),
        ]
        for (phrase, digits) in replacements {
            guard let range = working.range(of: phrase, options: [.caseInsensitive]) else { continue }
            working.replaceSubrange(range, with: digits)
            break
        }
        return working
    }

    // Filler left behind once the duration is removed: "timer 5m for pasta"
    // should be labelled "pasta", not "for pasta".
    private static func cleanUpLabel(_ label: String) -> String {
        var words = label
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        let filler: Set<String> = ["for", "to", "on", "in", "about", "and", "called", "named", "labeled", "labelled", "a", "an", "the", "my"]
        while let first = words.first, filler.contains(first.lowercased()) {
            words.removeFirst()
        }
        while let last = words.last, filler.contains(last.lowercased()) {
            words.removeLast()
        }
        return words.joined(separator: " ")
    }

    func start(seconds: TimeInterval, label: String) {
        requestAuthorizationIfNeeded()
        let id = UUID()
        let fireDate = Date().addingTimeInterval(seconds)
        schedule(id: id, label: label, fireDate: fireDate, remaining: seconds)
        persist()
        scheduleNotification(id: id, label: label, seconds: seconds)
    }

    func cancel(_ id: UUID) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].timer.invalidate()
            entries.remove(at: index)
            persist()
        }
        if Self.canNotify {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        }
    }

    // Handed to macOS up front so it rings even if the app is gone by then.
    private func scheduleNotification(id: UUID, label: String, seconds: TimeInterval) {
        guard Self.canNotify else { return }
        let content = UNMutableNotificationContent()
        content.title = "Timer done"
        content.body = label
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id.uuidString, content: content, trigger: trigger)
        )
    }

    private func fire(id: UUID, label: String) {
        entries.removeAll { $0.id == id }
        persist()
        NSSound(named: "Glass")?.play()
        // The notification was scheduled at start(); macOS usually delivers
        // it by itself. Post it here only if it has not rung yet.
        guard Self.canNotify else { return }
        let center = UNUserNotificationCenter.current()
        let identifier = id.uuidString
        center.getDeliveredNotifications { delivered in
            guard Self.needsFallbackNotification(
                id: identifier, delivered: delivered.map(\.request.identifier)
            ) else { return }
            let content = UNMutableNotificationContent()
            content.title = "Timer done"
            content.body = label
            content.sound = .default
            center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
        }
    }

    // Posts the "Timer done" notification now unless the one scheduled at
    // start() has already rung. One still queued (macOS has not caught up
    // after sleep) is replaced in place by the immediate one, since both
    // share an identifier, so it never rings twice.
    static func needsFallbackNotification(id: String, delivered: [String]) -> Bool {
        !delivered.contains(id)
    }

    private func requestAuthorizationIfNeeded() {
        guard !requestedAuthorization, Self.canNotify else { return }
        requestedAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
