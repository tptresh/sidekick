import AppKit
import Combine

// Switches the system to Light Mode and Dark Mode at the times set in
// Settings. It only acts when a switch time passes (or the Mac wakes after
// one), so a manual flip in between sticks until the next scheduled time.
final class AppearanceScheduler {
    static let shared = AppearanceScheduler()

    private let settings = SettingsStore.shared
    private let defaults = UserDefaults.standard
    private let appliedKey = "appearanceAppliedAt"
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    func start() {
        // A changed schedule should take effect right away, not at the next boundary.
        Publishers.CombineLatest3(settings.$autoAppearance, settings.$lightModeMinute, settings.$darkModeMinute)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.defaults.removeObject(forKey: self.appliedKey)
                self.check()
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.check() }

        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in self?.check() }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        check()
    }

    private func check() {
        guard settings.autoAppearance,
              let boundary = Self.latestBoundary(
                  before: Date(),
                  lightMinute: settings.lightModeMinute,
                  darkMinute: settings.darkModeMinute
              )
        else { return }
        if let applied = defaults.object(forKey: appliedKey) as? Date, applied >= boundary.date { return }
        defaults.set(Date(), forKey: appliedKey)
        SystemProvider.runAppleScript(
            "tell application \"System Events\" to tell appearance preferences to set dark mode to \(boundary.dark)"
        )
    }

    // The most recent scheduled switch at or before `now`, and whether it
    // switches to dark. Nil when both times are the same.
    static func latestBoundary(
        before now: Date, lightMinute: Int, darkMinute: Int, calendar: Calendar = .current
    ) -> (date: Date, dark: Bool)? {
        guard lightMinute != darkMinute else { return nil }
        let today = calendar.startOfDay(for: now)
        var best: (date: Date, dark: Bool)?
        for dayOffset in [0, -1] {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            for (minute, dark) in [(lightMinute, false), (darkMinute, true)] {
                guard let date = calendar.date(
                    bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day
                ), date <= now else { continue }
                if best == nil || date > best!.date { best = (date, dark) }
            }
        }
        return best
    }
}
