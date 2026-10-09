import AppKit
import EventKit

// "today" / "cal": today's remaining events. "next": the single next event
// with minutes-until and location. "remind me to buy milk at 5pm" (also
// "in 20m/2h/1d", "tomorrow at 9", "at 17:30"): creates an EKReminder in the
// default list with an alarm at the parsed time; the row previews exactly
// what will be created before Return commits it.
//
// Event fetches run on a background queue with a short-lived cache; when a
// fetch lands it posts the shared refresh notification so the visible query
// re-runs against the warm cache. Authorization reuses the row-driven flow
// from WindowProvider/FindMyProvider: .notDetermined shows a row whose Return
// opens the system prompt, .denied shows a row that opens Privacy settings.
// macOS 14's requestFullAccessToEvents/Reminders are used behind availability
// checks, falling back to the deprecated requestAccess(to:) on macOS 13.
// Under a bare `swift build` binary there is no Info.plist, so TCC would deny
// us outright; that case gets a friendly "run make app" row instead.
enum CalendarProvider {
    // EKEvent objects aren't thread-safe, so the fetch converts them to these
    // plain values on the fetch queue; only the structs cross to the main
    // thread for caching and rendering.
    private struct EventInfo {
        let title: String?
        let startDate: Date
        let endDate: Date
        let isAllDay: Bool
        let location: String?
        let calendarName: String?
    }

    private static let store = EKEventStore()
    private static let fetchQueue = DispatchQueue(label: "dev.opensource.spidey.calendar", qos: .userInitiated)
    private static let lock = NSLock()
    // Sorted events from now through the next 7 days; serves both "today" and "next".
    private static var eventCache: (events: [EventInfo], fetchedAt: Date)?
    private static var eventsLoading = false
    private static let cacheTTL: TimeInterval = 60
    private static var observingChanges = false

    // An event added, moved or deleted in Calendar should show at once, not
    // after the minute-long cache runs out.
    private static func observeChangesOnce() {
        lock.lock()
        let first = !observingChanges
        observingChanges = true
        lock.unlock()
        guard first else { return }
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: nil) { _ in
            invalidateEvents()
        }
    }

    private static func invalidateEvents() {
        lock.lock()
        eventCache = nil
        lock.unlock()
        NotificationCenter.default.post(name: .spideyFaviconLoaded, object: nil)
    }

    // MARK: - Entry point

    static func results(for query: String) -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let lowered = trimmed.lowercased()

        if lowered == "today" || lowered == "cal" || lowered == "calendar" {
            return todayResults()
        }
        if lowered == "next" {
            return nextResults()
        }
        if lowered.hasPrefix("remind") {
            if let parsed = ReminderParser.parse(trimmed) {
                return reminderResults(parsed)
            }
            if lowered == "remind" || lowered == "remind me" || lowered == "remind me to" {
                return [ResultItem(
                    title: "Create a reminder",
                    subtitle: "e.g. remind me to buy milk at 5pm \u{00B7} remind standup in 20m",
                    icon: .symbol("checklist"),
                    score: 950,
                    action: {}
                )]
            }
        }
        return []
    }

    // MARK: - Today

    private static func todayResults() -> [ResultItem] {
        if let gate = gateRow(.event, feature: "Today\u{2019}s events") {
            return [gate]
        }
        guard let events = cachedEvents() else {
            scheduleEventFetch()
            return [ResultItem(
                title: "Loading events\u{2026}",
                subtitle: "Reading today\u{2019}s calendar",
                icon: .symbol("calendar"),
                score: 950,
                action: {}
            )]
        }
        let now = Date()
        let calendar = Calendar.current
        let remaining = events.filter {
            $0.endDate > now && $0.startDate < endOfToday(now: now, calendar: calendar)
        }
        guard !remaining.isEmpty else {
            return [ResultItem(
                title: "No more events today",
                subtitle: "Return opens Calendar",
                icon: .symbol("calendar"),
                score: 950,
                action: { openCalendarApp() }
            )]
        }
        return remaining.prefix(8).enumerated().map { index, event in
            ResultItem(
                title: event.title ?? "Untitled event",
                subtitle: subtitle(for: event),
                icon: .symbol(event.isAllDay ? "calendar" : "calendar.badge.clock"),
                score: 950 - Double(index),
                action: { openCalendarApp() }
            )
        }
    }

    private static func subtitle(for event: EventInfo) -> String {
        let calendarName = event.calendarName ?? "Calendar"
        if event.isAllDay {
            return "All day \u{00B7} \(calendarName)"
        }
        let range = "\(timeFormatter.string(from: event.startDate))\u{2013}\(timeFormatter.string(from: event.endDate))"
        return "\(range) \u{00B7} \(calendarName)"
    }

    // MARK: - Next

    // Contract with MusicProvider: this row stays at 950; with a player
    // running, music's "Next Track" scores 955 for the exact query "next".
    private static func nextResults() -> [ResultItem] {
        if let gate = gateRow(.event, feature: "Next event") {
            return [gate]
        }
        guard let events = cachedEvents() else {
            scheduleEventFetch()
            return [ResultItem(
                title: "Loading events\u{2026}",
                subtitle: "Finding your next event",
                icon: .symbol("calendar"),
                score: 950,
                action: {}
            )]
        }
        let now = Date()
        guard let next = events.first(where: { !$0.isAllDay && $0.startDate > now }) else {
            return [ResultItem(
                title: "No upcoming events",
                subtitle: "Nothing scheduled in the next 7 days \u{00B7} Return opens Calendar",
                icon: .symbol("calendar"),
                score: 950,
                action: { openCalendarApp() }
            )]
        }
        var parts = [untilDescription(from: now, to: next.startDate)]
        if let location = next.location, !location.isEmpty {
            parts.append(location)
        }
        parts.append("\(timeFormatter.string(from: next.startDate)) \u{00B7} \(next.calendarName ?? "Calendar")")
        return [ResultItem(
            title: next.title ?? "Untitled event",
            subtitle: parts.joined(separator: " \u{00B7} "),
            icon: .symbol("calendar.badge.clock"),
            score: 950,
            action: { openCalendarApp() }
        )]
    }

    static func untilDescription(from now: Date, to date: Date) -> String {
        let minutes = Int(date.timeIntervalSince(now) / 60)
        if minutes < 1 { return "now" }
        if minutes < 60 { return "in \(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        if hours < 24 {
            return rest == 0 ? "in \(hours) h" : "in \(hours) h \(rest) min"
        }
        let days = hours / 24
        return "in \(days) day\(days == 1 ? "" : "s")"
    }

    // MARK: - Reminders

    private static func reminderResults(_ parsed: ReminderParser.Parsed) -> [ResultItem] {
        if let gate = gateRow(.reminder, feature: "Create reminder") {
            return [gate]
        }
        let title: String
        if let due = parsed.due {
            title = "Reminder: \(parsed.task) - \(dueDescription(due))"
        } else {
            title = "Reminder: \(parsed.task)"
        }
        let alarm = parsed.due == nil
            ? "No alarm \u{00B7} add a time like \u{201C}at 5pm\u{201D} or \u{201C}in 20m\u{201D}"
            : "Alarm at the shown time"
        return [ResultItem(
            title: title,
            subtitle: "\(alarm) \u{00B7} Return adds it to Reminders",
            icon: .symbol("checklist"),
            score: 950,
            action: { createReminder(parsed) }
        )]
    }

    private static func dueDescription(_ date: Date) -> String {
        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(date) {
            day = "today"
        } else if calendar.isDateInTomorrow(date) {
            day = "tomorrow"
        } else {
            day = dayFormatter.string(from: date)
        }
        return "\(day) \(timeFormatter.string(from: date))"
    }

    private static func createReminder(_ parsed: ReminderParser.Parsed) {
        fetchQueue.async {
            let reminder = EKReminder(eventStore: store)
            reminder.title = parsed.task
            guard let list = store.defaultCalendarForNewReminders()
                ?? store.calendars(for: .reminder).first else {
                NSLog("Spidey reminder: no Reminders list available")
                SystemProvider.tellUser(
                    title: "Reminder not saved",
                    body: "Reminders has no list to put it in. Create a list in Reminders, then try again."
                )
                return
            }
            reminder.calendar = list
            if let due = parsed.due {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: due
                )
                reminder.addAlarm(EKAlarm(absoluteDate: due))
            }
            do {
                try store.save(reminder, commit: true)
            } catch {
                NSLog("Spidey reminder save failed: \(error.localizedDescription)")
                SystemProvider.tellUser(
                    title: "Reminder not saved",
                    body: "Reminders said: \(error.localizedDescription)"
                )
            }
        }
    }

    // MARK: - Authorization gate

    // nil means access is usable; otherwise the row to show instead.
    private static func gateRow(_ type: EKEntityType, feature: String) -> ResultItem? {
        let kind = type == .event ? "Calendar" : "Reminders"
        guard Bundle.main.bundleIdentifier != nil else {
            return ResultItem(
                title: "\(feature) requires the bundled app",
                subtitle: "Run make app - a bare swift build binary can't be granted \(kind) access",
                icon: .symbol("shippingbox"),
                score: 950,
                action: {}
            )
        }
        switch EKEventStore.authorizationStatus(for: type) {
        case .notDetermined:
            return ResultItem(
                title: "\(feature): needs \(kind) access",
                subtitle: "Return opens the permission prompt, then try again",
                icon: .symbol("lock.shield"),
                score: 950,
                action: { requestAccess(type) }
            )
        case .denied, .restricted:
            return ResultItem(
                title: "\(feature): \(kind) access denied",
                subtitle: "Return opens Privacy settings - enable the app, then try again",
                icon: .symbol("lock.shield"),
                score: 950,
                action: { openPrivacySettings(type) }
            )
        default:
            // .authorized (13), .fullAccess (14+) are fine; .writeOnly (14+)
            // cannot read events, so send that through Privacy settings too.
            if hasAccess(type) { return nil }
            return ResultItem(
                title: "\(feature): needs full \(kind) access",
                subtitle: "Return opens Privacy settings - switch to Full Access, then try again",
                icon: .symbol("lock.shield"),
                score: 950,
                action: { openPrivacySettings(type) }
            )
        }
    }

    private static func hasAccess(_ type: EKEntityType) -> Bool {
        let status = EKEventStore.authorizationStatus(for: type)
        if #available(macOS 14.0, *) {
            if status == .fullAccess { return true }
        }
        return status == .authorized
    }

    private static func requestAccess(_ type: EKEntityType) {
        let done: (Bool, Error?) -> Void = { _, _ in
            // Re-run the visible query so granted access takes effect at once.
            invalidateEvents()
        }
        if #available(macOS 14.0, *) {
            if type == .event {
                store.requestFullAccessToEvents(completion: done)
            } else {
                store.requestFullAccessToReminders(completion: done)
            }
        } else {
            store.requestAccess(to: type, completion: done)
        }
    }

    private static func openPrivacySettings(_ type: EKEntityType) {
        let pane = type == .event ? "Privacy_Calendars" : "Privacy_Reminders"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Event fetching

    private static func cachedEvents() -> [EventInfo]? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = eventCache, Date().timeIntervalSince(entry.fetchedAt) < cacheTTL else {
            return nil
        }
        return entry.events
    }

    private static func scheduleEventFetch() {
        lock.lock()
        let alreadyRunning = eventsLoading
        if !alreadyRunning { eventsLoading = true }
        lock.unlock()
        guard !alreadyRunning else { return }
        observeChangesOnce()

        fetchQueue.async {
            let now = Date()
            let end = now.addingTimeInterval(7 * 86400)
            let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
            // Convert to plain values here: EKEvent isn't thread-safe, so no
            // EKEvent property is read outside this block.
            let events = store.events(matching: predicate)
                .map { event in
                    EventInfo(
                        title: event.title,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        isAllDay: event.isAllDay,
                        location: event.location,
                        calendarName: event.calendar?.title
                    )
                }
                .sorted { $0.startDate < $1.startDate }
            lock.lock()
            eventCache = (events, Date())
            eventsLoading = false
            lock.unlock()
            // Nudge the query engine to re-run against the warm cache.
            NotificationCenter.default.post(name: .spideyFaviconLoaded, object: nil)
        }
    }

    private static func endOfToday(now: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? now.addingTimeInterval(86400)
    }

    private static func openCalendarApp() {
        let url = URL(fileURLWithPath: "/System/Applications/Calendar.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: - Formatters

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d"
        return formatter
    }()
}

// MARK: - Reminder time parsing

// Pure parser for "remind ..." queries, separated so it can be unit-tested
// with an injected clock and calendar. Understands, anchored at the end of
// the query:
//   in 20m / in 2h / in 1d / in 90 minutes / in 1.5h
//   at 5pm / at 5:30pm / at 17:30 / at 9        (bare hours pick the next
//                                                upcoming occurrence today,
//                                                otherwise roll to tomorrow)
//   tomorrow at 9 / tomorrow at 17:30 / tomorrow (defaults to 9:00 AM)
// Ambiguous bare hours on an explicit "tomorrow" read 1-7 as afternoon and
// 8-12 as morning, so "tomorrow at 9" is 9 AM and "tomorrow at 5" is 5 PM.
enum ReminderParser {
    struct Parsed: Equatable {
        let task: String
        let due: Date?
    }

    static func parse(
        _ query: String, now: Date = Date(), calendar: Calendar = .current
    ) -> Parsed? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let lowered = trimmed.lowercased()
        // A still-being-typed prefix is not a reminder yet ("remind me to"
        // would otherwise match the shorter "remind me " prefix, task "to").
        if ["remind", "remind me", "remind me to", "remind to"].contains(lowered) {
            return nil
        }
        var rest: String?
        for prefix in ["remind me to ", "remind me ", "remind to ", "remind "] {
            if lowered.hasPrefix(prefix) {
                rest = String(trimmed.dropFirst(prefix.count))
                break
            }
        }
        guard let body = rest?.trimmingCharacters(in: .whitespaces), !body.isEmpty else {
            return nil
        }

        // "in 20m" and friends: a plain offset from now.
        if let groups = firstMatch(relativeRegex, in: body) {
            let task = stripping(body, suffix: groups[0]!)
            guard !task.isEmpty, let amount = Double(groups[1]!) else { return nil }
            let unit = groups[2]!.lowercased()
            let seconds: TimeInterval
            if unit.hasPrefix("m") {
                seconds = amount * 60
            } else if unit.hasPrefix("h") {
                seconds = amount * 3600
            } else {
                seconds = amount * 86400
            }
            return Parsed(task: task, due: now.addingTimeInterval(seconds))
        }

        // "tomorrow at 9" / "at 5pm" / bare "tomorrow".
        if let groups = firstMatch(tomorrowAtRegex, in: body) {
            let task = stripping(body, suffix: groups[0]!)
            guard !task.isEmpty else { return nil }
            if let due = resolve(
                hour: Int(groups[1]!) ?? -1, minute: groups[2].flatMap { Int($0) } ?? 0,
                meridiem: meridiem(groups[3]), explicitTomorrow: true, now: now, calendar: calendar
            ) {
                return Parsed(task: task, due: due)
            }
            return Parsed(task: body, due: nil)
        }
        if let groups = firstMatch(atRegex, in: body) {
            let task = stripping(body, suffix: groups[0]!)
            guard !task.isEmpty else { return nil }
            if let due = resolve(
                hour: Int(groups[1]!) ?? -1, minute: groups[2].flatMap { Int($0) } ?? 0,
                meridiem: meridiem(groups[3]), explicitTomorrow: false, now: now, calendar: calendar
            ) {
                return Parsed(task: task, due: due)
            }
            return Parsed(task: body, due: nil)
        }
        if let groups = firstMatch(tomorrowRegex, in: body) {
            let task = stripping(body, suffix: groups[0]!)
            guard !task.isEmpty else { return nil }
            let due = dateAt(dayOffset: 1, hour: 9, minute: 0, now: now, calendar: calendar)
            return Parsed(task: task, due: due)
        }

        return Parsed(task: body, due: nil)
    }

    // MARK: - Time resolution

    private enum Meridiem { case am, pm }

    private static func meridiem(_ raw: String?) -> Meridiem? {
        guard let raw = raw?.lowercased() else { return nil }
        if raw.hasPrefix("a") { return .am }
        if raw.hasPrefix("p") { return .pm }
        return nil
    }

    private static func resolve(
        hour: Int, minute: Int, meridiem: Meridiem?, explicitTomorrow: Bool,
        now: Date, calendar: Calendar
    ) -> Date? {
        guard (0...59).contains(minute) else { return nil }

        if let meridiem {
            guard (1...12).contains(hour) else { return nil }
            var resolved = hour % 12
            if meridiem == .pm { resolved += 12 }
            if explicitTomorrow {
                return dateAt(dayOffset: 1, hour: resolved, minute: minute, now: now, calendar: calendar)
            }
            guard let today = dateAt(dayOffset: 0, hour: resolved, minute: minute, now: now, calendar: calendar) else {
                return nil
            }
            // A time already past means the next occurrence: tomorrow.
            return today > now
                ? today
                : dateAt(dayOffset: 1, hour: resolved, minute: minute, now: now, calendar: calendar)
        }

        guard (0...23).contains(hour) else { return nil }

        // Unambiguous 24-hour times ("at 17:30", "at 0:30").
        if hour >= 13 || hour == 0 {
            if explicitTomorrow {
                return dateAt(dayOffset: 1, hour: hour, minute: minute, now: now, calendar: calendar)
            }
            guard let today = dateAt(dayOffset: 0, hour: hour, minute: minute, now: now, calendar: calendar) else {
                return nil
            }
            return today > now
                ? today
                : dateAt(dayOffset: 1, hour: hour, minute: minute, now: now, calendar: calendar)
        }

        // Ambiguous 1-12 with no am/pm.
        if explicitTomorrow {
            return dateAt(
                dayOffset: 1, hour: disambiguated(hour), minute: minute, now: now, calendar: calendar
            )
        }
        // Today: the next upcoming of the two candidate readings.
        var candidates = [hour == 12 ? 12 : hour]
        if hour < 12 { candidates.append(hour + 12) }
        for candidate in candidates.sorted() {
            if let date = dateAt(dayOffset: 0, hour: candidate, minute: minute, now: now, calendar: calendar),
               date > now {
                return date
            }
        }
        // Both readings already passed: tomorrow, with the day heuristic.
        return dateAt(
            dayOffset: 1, hour: disambiguated(hour), minute: minute, now: now, calendar: calendar
        )
    }

    // For an ambiguous bare hour on a future day: 1-7 reads as afternoon or
    // evening ("tomorrow at 5" is 5 PM), 8-12 as morning ("tomorrow at 9" is 9 AM).
    private static func disambiguated(_ hour: Int) -> Int {
        if (1...7).contains(hour) { return hour + 12 }
        return hour == 12 ? 12 : hour
    }

    private static func dateAt(
        dayOffset: Int, hour: Int, minute: Int, now: Date, calendar: Calendar
    ) -> Date? {
        let startOfDay = calendar.startOfDay(for: now)
        guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfDay) else {
            return nil
        }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }

    // MARK: - Regex plumbing

    private static let timePart = #"(\d{1,2})(?::([0-5]\d))?\s*(am|pm|a\.m\.|p\.m\.)?"#

    // (?:^|\s+) instead of \s+ so a body that is ONLY a time clause
    // ("remind in 20m") still matches, leaves an empty task, and parses to
    // nil rather than becoming a reminder titled "in 20m".
    private static let relativeRegex = try! NSRegularExpression(
        pattern: #"(?:^|\s+)in\s+(\d+(?:\.\d+)?)\s*(minutes?|mins?|m|hours?|hrs?|hr|h|days?|d)\s*$"#,
        options: [.caseInsensitive]
    )
    private static let tomorrowAtRegex = try! NSRegularExpression(
        pattern: #"(?:^|\s+)tomorrow\s+at\s+"# + timePart + #"\s*$"#,
        options: [.caseInsensitive]
    )
    private static let atRegex = try! NSRegularExpression(
        pattern: #"(?:^|\s+)at\s+"# + timePart + #"\s*$"#,
        options: [.caseInsensitive]
    )
    private static let tomorrowRegex = try! NSRegularExpression(
        pattern: #"(?:^|\s+)tomorrow\s*$"#,
        options: [.caseInsensitive]
    )

    // Group 0 is the whole match; missing optional groups come back nil.
    private static func firstMatch(_ regex: NSRegularExpression, in text: String) -> [String?]? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        var groups: [String?] = []
        for index in 0..<match.numberOfRanges {
            if let groupRange = Range(match.range(at: index), in: text) {
                groups.append(String(text[groupRange]))
            } else {
                groups.append(nil)
            }
        }
        return groups
    }

    private static func stripping(_ text: String, suffix: String) -> String {
        guard text.hasSuffix(suffix) else { return text.trimmingCharacters(in: .whitespaces) }
        return String(text.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
    }
}
