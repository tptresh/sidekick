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

    var body: some View {
        VStack(spacing: FuturisticStyle.Space.s) {
            Island(padding: FuturisticStyle.Space.l) {
                WeatherHeader(state: weather.state, retry: { weather.refresh() })
                    .frame(minHeight: 44)
            }
            .background(alignment: .topTrailing) { AmbientWash() }

            Island(padding: FuturisticStyle.Space.s) {
                VStack(spacing: FuturisticStyle.Space.xs) {
                    SwitchRow(
                        symbol: "cup.and.saucer.fill",
                        title: "Keep Mac Awake",
                        subtitle: caffeinate.isActive ? "On, sleep is paused" : "Off",
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
                        HStack(spacing: FuturisticStyle.Space.l) {
                            TimeField(label: "Light", minute: $settings.lightModeMinute)
                            TimeField(label: "Dark", minute: $settings.darkModeMinute)
                            Spacer(minLength: 0)
                        }
                        .padding(.leading, 48)
                        .padding(.bottom, 6)
                    }
                }
            }

            HStack {
                LinkButton("Preferences…", action: openPreferences)
                Spacer()
                LinkButton("Quit Sidekick") { NSApp.terminate(nil) }
            }
            .padding(.horizontal, FuturisticStyle.Space.xs)
            .padding(.top, 2)
        }
        .padding(FuturisticStyle.Space.m)
        .frame(width: 320)
        .futuristicTheme(settings.theme)
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

// Soft accent glow behind the weather island. Reads the theme from its own
// environment so it follows the hero theme and appearance.
private struct AmbientWash: View {
    @Environment(\.fxTokens) private var fx
    var body: some View {
        RadialGradient(
            colors: [fx.ambientColor, .clear],
            center: .topTrailing, startRadius: 0, endRadius: 180
        )
        .clipShape(RoundedRectangle(cornerRadius: FuturisticStyle.Radius.island, style: .continuous))
        .allowsHitTesting(false)
    }
}

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
                Circle().fill(.quaternary).frame(width: 36, height: 36).frame(width: 44)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: FuturisticStyle.Radius.sm).fill(.quaternary).frame(width: 110, height: 14)
                    RoundedRectangle(cornerRadius: FuturisticStyle.Radius.sm).fill(.quaternary).frame(width: 170, height: 10)
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
                Text(title).font(.system(size: 13, weight: .medium)).lineLimit(1).truncationMode(.tail)
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

// MARK: - Rows

private struct TimeField: View {
    let label: String
    @Binding var minute: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .textCase(.uppercase)
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
