import SwiftUI
import AppKit

// The panel under the menu bar emblem: today's weather, the keep-awake
// indicator while it is on, and the automatic Light / Dark switch times.
struct MenuBarPanel: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var weather = WeatherStore.shared
    @ObservedObject var caffeinate = CaffeinateManager.shared
    let openSearch: () -> Void
    let openPreferences: () -> Void

    static let width: CGFloat = 320

    private var palette: ThemePalette { settings.theme.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            WeatherCard(state: weather.state, retry: { weather.refresh() })
            if caffeinate.isActive {
                awakeBanner
            }
            scheduleCard
            Divider().overlay(palette.textSecondary.opacity(0.25))
            footer
        }
        .padding(14)
        .frame(width: Self.width)
        .background(
            LinearGradient(
                colors: [palette.backgroundTop, palette.background],
                startPoint: .top, endPoint: .bottom
            )
        )
        .foregroundColor(palette.textPrimary)
        .onAppear { weather.refreshIfStale() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: StatusIcons.watermark(
                for: settings.theme, size: 18, color: NSColor(palette.accent)
            ))
            .resizable()
            .frame(width: 18, height: 18)
            Text("Sidekick")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(palette.textSecondary)
        }
    }

    private var awakeBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "cup.and.saucer.fill")
                .foregroundColor(palette.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Keeping your Mac awake")
                    .font(.system(size: 12, weight: .semibold))
                Text("Sleep is paused until you stop it")
                    .font(.system(size: 11))
                    .foregroundColor(palette.textSecondary)
            }
            Spacer()
            Button("Stop") { caffeinate.stop() }
                .buttonStyle(PanelPillButtonStyle(tint: palette.accent))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(palette.accent.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(palette.accent.opacity(0.45), lineWidth: 1)
        )
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundColor(palette.accent)
                Text("Automatic Light & Dark")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Toggle("", isOn: $settings.autoAppearance)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }
            HStack(spacing: 12) {
                timeField(symbol: "sun.max.fill", label: "Light", keyPath: \.lightModeMinute)
                timeField(symbol: "moon.fill", label: "Dark", keyPath: \.darkModeMinute)
            }
            .disabled(!settings.autoAppearance)
            .opacity(settings.autoAppearance ? 1 : 0.45)
            Text(nextSwitchDescription)
                .font(.system(size: 11))
                .foregroundColor(palette.textSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(palette.textPrimary.opacity(0.06))
        )
    }

    private func timeField(
        symbol: String, label: String, keyPath: ReferenceWritableKeyPath<SettingsStore, Int>
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundColor(palette.textSecondary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(palette.textSecondary)
            DatePicker("", selection: minuteBinding(keyPath), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.field)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nextSwitchDescription: String {
        guard settings.autoAppearance else { return "Off. Your Mac keeps whichever look you pick." }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let now = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let light = settings.lightModeMinute
        let dark = settings.darkModeMinute
        func untilNext(_ minute: Int) -> Int { (minute - now + 1440) % 1440 }
        let goesDark = untilNext(dark) < untilNext(light)
        let minute = goesDark ? dark : light
        let time = Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date())
            .map { $0.formatted(date: .omitted, time: .shortened) } ?? ""
        return "Next: \(goesDark ? "Dark" : "Light") mode at \(time)"
    }

    private func minuteBinding(_ keyPath: ReferenceWritableKeyPath<SettingsStore, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minute = settings[keyPath: keyPath]
                return Calendar.current.date(
                    bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()
                ) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                settings[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Button(action: openSearch) {
                Label {
                    Text("Search")
                    if let hotKey = settings.activeHotKey {
                        Text(hotKey.displayString).foregroundColor(palette.textSecondary)
                    }
                } icon: {
                    Image(systemName: "magnifyingglass")
                }
            }
            Spacer()
            Button(action: openPreferences) {
                Label("Preferences", systemImage: "gearshape")
            }
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
        }
        .buttonStyle(PanelFooterButtonStyle(palette: palette))
    }
}

// The weather graphic: a sky-coloured card that follows the conditions and
// time of day, with a large multicolour symbol and today's range.
private struct WeatherCard: View {
    let state: WeatherStore.State
    let retry: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: skyColors, startPoint: .topLeading, endPoint: .bottomTrailing))
            content
                .padding(14)
        }
        .frame(height: 118)
        .foregroundColor(.white)
        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .ready(let today):
            let look = WeatherStore.describe(code: today.code, isDay: today.isDay)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(today.place ?? "Today")
                        .font(.system(size: 12, weight: .semibold))
                        .opacity(0.9)
                    Text(Self.temperature(today.temperature))
                        .font(.system(size: 42, weight: .light, design: .rounded))
                    Text(look.text)
                        .font(.system(size: 12, weight: .medium))
                    HStack(spacing: 8) {
                        Text("H \(Self.temperature(today.high))  L \(Self.temperature(today.low))")
                        if let rain = today.rainChance {
                            Label("\(rain)%", systemImage: "drop.fill")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .font(.system(size: 11))
                    .opacity(0.85)
                }
                Spacer()
                Image(systemName: look.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 52))
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            }
        case .needsLocation:
            message(
                symbol: "location.slash",
                title: "Weather needs your location",
                detail: "Allow Sidekick under Location Services.",
                button: "Open Settings",
                action: {
                    SetupCenter.shared.openPrivacySettings(anchor: "Privacy_LocationServices")
                    retry()
                }
            )
        case .failed(let reason):
            message(symbol: "cloud.fill", title: reason, detail: "Check your connection.", button: "Try Again", action: retry)
        case .idle, .loading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking the sky…").font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func message(
        symbol: String, title: String, detail: String, button: String, action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 28)).opacity(0.85)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.system(size: 11)).opacity(0.85)
                Button(button, action: action)
                    .buttonStyle(PanelPillButtonStyle(tint: .white.opacity(0.35)))
                    .padding(.top, 3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var skyColors: [Color] {
        guard case .ready(let today) = state else {
            return [Color(red: 0.27, green: 0.33, blue: 0.43), Color(red: 0.16, green: 0.20, blue: 0.27)]
        }
        if !today.isDay {
            return [Color(red: 0.12, green: 0.15, blue: 0.33), Color(red: 0.04, green: 0.05, blue: 0.14)]
        }
        switch today.code {
        case 0, 1:
            return [Color(red: 0.24, green: 0.56, blue: 0.93), Color(red: 0.12, green: 0.35, blue: 0.75)]
        case 2, 3, 45, 48:
            return [Color(red: 0.47, green: 0.55, blue: 0.66), Color(red: 0.29, green: 0.35, blue: 0.45)]
        case 71...77, 85, 86:
            return [Color(red: 0.60, green: 0.70, blue: 0.82), Color(red: 0.38, green: 0.47, blue: 0.60)]
        case 95...99:
            return [Color(red: 0.25, green: 0.24, blue: 0.38), Color(red: 0.12, green: 0.12, blue: 0.20)]
        default:
            return [Color(red: 0.33, green: 0.43, blue: 0.56), Color(red: 0.18, green: 0.25, blue: 0.36)]
        }
    }

    // Celsius from the forecast; Fahrenheit for regions that use it.
    static func temperature(_ celsius: Double) -> String {
        let usesFahrenheit = Locale.current.measurementSystem == .us
        let value = usesFahrenheit ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(value.rounded()))°"
    }
}

private struct PanelPillButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(configuration.isPressed ? 0.6 : 0.9)))
            .foregroundColor(.white)
    }
}

private struct PanelFooterButtonStyle: ButtonStyle {
    let palette: ThemePalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(palette.textPrimary.opacity(configuration.isPressed ? 0.16 : 0.07))
            )
            .contentShape(Rectangle())
    }
}
