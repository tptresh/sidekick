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

    private init() {}

    // Parses "10m tea", "1h30m pasta", "90s", "10 minutes laundry".
    // Returns the duration and whatever text is left over as the label.
    static func parse(_ text: String) -> (seconds: TimeInterval, label: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // (?![a-z]) instead of \b so "1h30m" still matches the "1h" part.
        let pattern = #"(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)(?![a-z])"#
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

        let cleanLabel = label.trimmingCharacters(in: .whitespaces)
        guard total > 0, total <= 24 * 3600 else { return nil }
        return (total, cleanLabel.isEmpty ? "Timer" : cleanLabel)
    }

    func start(seconds: TimeInterval, label: String) {
        requestAuthorizationIfNeeded()
        let id = UUID()
        let fireDate = Date().addingTimeInterval(seconds)
        let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.fire(id: id, label: label)
        }
        entries.append(Entry(id: id, label: label, fireDate: fireDate, timer: timer))
    }

    func cancel(_ id: UUID) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].timer.invalidate()
            entries.remove(at: index)
        }
    }

    private func fire(id: UUID, label: String) {
        entries.removeAll { $0.id == id }
        NSSound(named: "Glass")?.play()
        // Notifications need a real app bundle; skip them when running bare
        // from .build during development.
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "Timer done"
        content.body = label
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: id.uuidString, content: content, trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func requestAuthorizationIfNeeded() {
        guard !requestedAuthorization, Bundle.main.bundleIdentifier != nil else { return }
        requestedAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
