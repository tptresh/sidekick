import SwiftUI
import AppKit

// The dropdown under the menu bar emblem. It shares the search panel's look:
// one dark Liquid Glass slab (drawn by the window), hairline dividers between
// sections and no cards inside, so it reads as the same family. Today's
// weather on top, then the two switches with preset times for the Light and
// Dark schedule, then quiet Preferences and Quit links.
struct MenuBarPanel: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var weather = WeatherStore.shared
    @ObservedObject var caffeinate = CaffeinateManager.shared
    let openPreferences: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: FuturisticStyle.Space.s) {
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                WeatherHeader(state: weather.state, retry: { weather.refresh() })
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, FuturisticStyle.Space.l)
            .padding(.top, FuturisticStyle.Space.l)
            .padding(.bottom, FuturisticStyle.Space.m)

            Hairline()

            VStack(spacing: 2) {
                SwitchRow(
                    symbol: "cup.and.saucer.fill",
                    title: "Keep Mac Awake",
                    subtitle: caffeinate.isActive
                        ? (caffeinate.lidHeld ? "On, even on battery or with the lid closed" : "On, but closing the lid still sleeps")
                        : "Off",
                    isOn: Binding(
                        get: { caffeinate.isActive },
                        set: { on in if on != caffeinate.isActive { caffeinate.toggle() } }
                    )
                )
                SwitchRow(
                    symbol: "circle.lefthalf.filled",
                    title: "Automatic Light & Dark",
                    subtitle: scheduleSubtitle,
                    isOn: $settings.autoAppearance
                )
                if settings.autoAppearance {
                    VStack(alignment: .leading, spacing: FuturisticStyle.Space.s) {
                        PresetTimes(label: "Light", options: PresetTimes.lightOptions, minute: $settings.lightModeMinute)
                        PresetTimes(label: "Dark", options: PresetTimes.darkOptions, minute: $settings.darkModeMinute)
                    }
                    .padding(.leading, 48)
                    .padding(.trailing, FuturisticStyle.Space.s)
                    .padding(.vertical, FuturisticStyle.Space.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(6)

            Hairline()

            HStack {
                LinkButton("Preferences…", action: openPreferences)
                Spacer()
                LinkButton("Quit Sidekick") { NSApp.terminate(nil) }
            }
            .padding(.horizontal, FuturisticStyle.Space.m)
            .frame(height: 40)
        }
        .frame(width: 340)
        .futuristicTheme(settings.theme)
    }

    private var scheduleSubtitle: String {
        guard settings.autoAppearance else { return "Off" }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let now = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        func untilNext(_ minute: Int) -> Int { (minute - now + 1440) % 1440 }
        let goesDark = untilNext(settings.darkModeMinute) < untilNext(settings.lightModeMinute)
        let minute = goesDark ? settings.darkModeMinute : settings.lightModeMinute
        return "\(goesDark ? "Dark" : "Light") at \(PresetTimes.format(minute))"
    }
}

private struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, FuturisticStyle.Space.m)
    }
}

// MARK: - Weather

private struct WeatherHeader: View {
    let state: WeatherStore.State
    let retry: () -> Void

    var body: some View {
        switch state {
        case .ready(let today):
            let look = WeatherStore.describe(code: today.code, isDay: today.isDay)
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: look.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 34))
                    .frame(width: 44)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(Self.temperature(today.temperature))
                            .font(.system(size: 36, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .layoutPriority(1)
                        Chip(today.place ?? "Today", tone: .neutral, symbol: "location.fill")
                            .frame(minWidth: 0)
                    }
                    Text(detailLine(today, condition: look.text))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        case .needsLocation:
            notice(
                symbol: "location.slash",
                title: "Weather needs your location",
                button: "Allow in System Settings",
                prominent: false
            ) {
                SetupCenter.shared.openPrivacySettings(anchor: "Privacy_LocationServices")
            }
        case .failed(let reason):
            notice(symbol: "cloud", title: reason, button: "Try Again", prominent: true, action: retry)
        case .placeholder:
            // First run only: later opens always have the saved forecast.
            HStack(spacing: 14) {
                Circle().fill(Color.white.opacity(0.10)).frame(width: 36, height: 36).frame(width: 44)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.10)).frame(width: 110, height: 14)
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.10)).frame(width: 170, height: 10)
                }
            }
            .frame(height: 44)
        }
    }

    private func detailLine(_ today: WeatherStore.Today, condition: String) -> String {
        var parts = [condition, "H \(Self.temperature(today.high))  L \(Self.temperature(today.low))"]
        if let rain = today.rainChance, rain > 0 { parts.append("Rain \(rain)%") }
        return parts.joined(separator: "  ·  ")
    }

    private func notice(
        symbol: String, title: String, button: String, prominent: Bool, action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                PillButton(button, symbol: prominent ? "arrow.clockwise" : nil, prominent: prominent, action: action)
            }
            Spacer(minLength: 0)
        }
    }

    // Celsius from the forecast; Fahrenheit where that is the local unit.
    static func temperature(_ celsius: Double) -> String {
        let value = Locale.current.measurementSystem == .us ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(value.rounded()))°"
    }
}
