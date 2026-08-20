import AppKit

// "timer 10m tea" starts a timer; "timers" lists and cancels running ones.
enum TimerProvider {
    static func results(for query: String) -> [ResultItem] {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)

        if lowered == "timer" || lowered == "timers" {
            let running = TimerCenter.shared.entries.sorted { $0.fireDate < $1.fireDate }
            if running.isEmpty {
                return [ResultItem(
                    title: "No timers running",
                    subtitle: "Start one like: timer 10m tea",
                    icon: .symbol("timer"),
                    score: 950,
                    action: {}
                )]
            }
            return running.enumerated().map { index, entry in
                ResultItem(
                    title: "\(entry.label): \(entry.remainingDescription) left",
                    subtitle: "Return cancels this timer",
                    icon: .symbol("timer"),
                    score: 950 - Double(index),
                    action: { TimerCenter.shared.cancel(entry.id) }
                )
            }
        }

        guard lowered.hasPrefix("timer ") else { return [] }
        let spec = String(query.dropFirst("timer ".count))
        guard let parsed = TimerCenter.parse(spec) else {
            return [ResultItem(
                title: "Start a timer",
                subtitle: "Like: timer 10m tea, timer 1h30m pasta, timer 90s",
                icon: .symbol("timer"),
                score: 950,
                action: {}
            )]
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let endTime = formatter.string(from: Date().addingTimeInterval(parsed.seconds))
        return [ResultItem(
            title: "Start timer: \(parsed.label) (\(durationDescription(parsed.seconds)))",
            subtitle: "Rings at \(endTime) with a notification and a sound",
            icon: .symbol("timer"),
            score: 985,
            action: { TimerCenter.shared.start(seconds: parsed.seconds, label: parsed.label) }
        )]
    }

    static func durationDescription(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours)h") }
        if minutes > 0 { parts.append("\(minutes)m") }
        if secs > 0 { parts.append("\(secs)s") }
        return parts.isEmpty ? "0s" : parts.joined(separator: " ")
    }
}
