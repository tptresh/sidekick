import SwiftUI
import AppKit

// The panel under the menu bar emblem, laid out like Control Center: today's
// weather on top, then two switch rows (Keep Mac Awake, automatic Light and
// Dark), then quiet Preferences and Quit links. It sits on the native popover
// material and follows the system appearance; the hero theme only lends its
// accent colour.
struct MenuBarPanel: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var weather = WeatherStore.shared
    @ObservedObject var caffeinate = CaffeinateManager.shared
    let openPreferences: () -> Void

    private var accent: Color { settings.theme.palette.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WeatherHeader(state: weather.state, retry: { weather.refresh() })
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 14)

            Divider().padding(.horizontal, 12)

            VStack(spacing: 4) {
                SwitchRow(
                    symbol: "cup.and.saucer.fill",
                    title: "Keep Mac Awake",
                    subtitle: caffeinate.isActive ? "On, sleep is paused" : "Off",
                    accent: accent,
                    isOn: Binding(
                        get: { caffeinate.isActive },
                        set: { on in if on != caffeinate.isActive { caffeinate.toggle() } }
                    )
                )
                SwitchRow(
                    symbol: "circle.lefthalf.filled",
                    title: "Automatic Light & Dark",
                    subtitle: scheduleSubtitle,
                    accent: accent,
                    isOn: $settings.autoAppearance
                )
                if settings.autoAppearance {
                    HStack(spacing: 16) {
                        TimeField(label: "Light", minute: $settings.lightModeMinute)
                        TimeField(label: "Dark", minute: $settings.darkModeMinute)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 46)
                    .padding(.bottom, 6)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            Divider().padding(.horizontal, 12)

            HStack {
                LinkButton(title: "Preferences…", action: openPreferences)
                Spacer()
                LinkButton(title: "Quit Sidekick") { NSApp.terminate(nil) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 300)
        .tint(accent)
    }

    private var scheduleSubtitle: String {
        guard settings.autoAppearance else { return "Off" }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let now = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        func untilNext(_ minute: Int) -> Int { (minute - now + 1440) % 1440 }
        let goesDark = untilNext(settings.darkModeMinute) < untilNext(settings.lightModeMinute)
        let minute = goesDark ? settings.darkModeMinute : settings.lightModeMinute
        return "\(goesDark ? "Dark" : "Light") at \(TimeField.format(minute))"
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
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(Self.temperature(today.temperature))
                            .font(.system(size: 30, weight: .light))
                            .monospacedDigit()
                        Text(today.place ?? "Today")
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                    }
                    Text(detailLine(today, condition: look.text))
                        .font(.system(size: 12))
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
                button: "Allow in System Settings"
            ) {
                SetupCenter.shared.openPrivacySettings(anchor: "Privacy_LocationServices")
            }
        case .failed(let reason):
            notice(symbol: "cloud", title: reason, button: "Try Again", action: retry)
        case .placeholder:
            // First run only: later opens always have the saved forecast.
            HStack(spacing: 14) {
                Circle().fill(.quaternary).frame(width: 36, height: 36).frame(width: 44)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(.quaternary).frame(width: 110, height: 14)
                    RoundedRectangle(cornerRadius: 3).fill(.quaternary).frame(width: 170, height: 10)
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
        symbol: String, title: String, button: String, action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold))
                LinkButton(title: button, action: action)
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

// MARK: - Rows

private struct SwitchRow: View {
    let symbol: String
    let title: String
    let subtitle: String
    let accent: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(isOn ? AnyShapeStyle(accent) : AnyShapeStyle(.quaternary)))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

private struct TimeField: View {
    let label: String
    @Binding var minute: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            DatePicker("", selection: dateBinding, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.field)
                .controlSize(.small)
                .monospacedDigit()
        }
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { Self.date(for: minute) },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    static func date(for minute: Int) -> Date {
        Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
    }

    static func format(_ minute: Int) -> String {
        date(for: minute).formatted(date: .omitted, time: .shortened)
    }
}

// Plain text link, like the bottom items in the system's own menu bar panels.
private struct LinkButton: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(hovering ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
