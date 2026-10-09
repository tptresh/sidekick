import SwiftUI

// Shared look for the menu bar panel and Preferences: glass islands, one hero
// accent per theme, mono labels. Views read their colours from the environment
// so none of them takes an accent colour as a parameter.
enum FuturisticStyle {
    struct Tokens {
        let accent: Color
        let accentText: Color
        let onAccent: Color
        let islandFill: Color
        let islandFillHover: Color
        let islandStroke: Color
        let islandEdgeHighlight: Color
        let prefsIslandFill: Color
        let glowColor: Color
        let glowRadius: CGFloat
        let ambientColor: Color

        static func resolve(theme: HeroTheme, scheme: ColorScheme) -> Tokens {
            let dark = scheme == .dark
            let accent = theme.accent(for: scheme)
            return Tokens(
                accent: accent,
                accentText: theme.accentText(for: scheme),
                onAccent: theme.onAccent(for: scheme),
                islandFill: dark ? Color.white.opacity(0.055) : Color.black.opacity(0.035),
                islandFillHover: dark ? Color.white.opacity(0.09) : Color.black.opacity(0.06),
                islandStroke: dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08),
                islandEdgeHighlight: dark ? Color.white.opacity(0.14) : Color.white.opacity(0.60),
                prefsIslandFill: dark ? Color.white.opacity(0.06) : Color.white.opacity(0.72),
                glowColor: accent.opacity(dark ? 0.45 : 0.30),
                glowRadius: dark ? 10 : 8,
                ambientColor: accent.opacity(dark ? 0.14 : 0.08)
            )
        }
    }

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let island: CGFloat = 12
        static let badge: CGFloat = 7
    }
}

private struct FXTokensKey: EnvironmentKey {
    static let defaultValue = FuturisticStyle.Tokens.resolve(theme: .spiderman, scheme: .dark)
}

extension EnvironmentValues {
    var fxTokens: FuturisticStyle.Tokens {
        get { self[FXTokensKey.self] }
        set { self[FXTokensKey.self] = newValue }
    }
}

private struct FuturisticThemeModifier: ViewModifier {
    let theme: HeroTheme
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let tokens = FuturisticStyle.Tokens.resolve(theme: theme, scheme: scheme)
        content
            .environment(\.fxTokens, tokens)
            .tint(tokens.accent)
    }
}

extension View {
    func futuristicTheme(_ theme: HeroTheme) -> some View {
        modifier(FuturisticThemeModifier(theme: theme))
    }
}

private extension View {
    // Hover/press animation that switches off under Reduce Motion.
    func fxAnimation<V: Equatable>(_ reduceMotion: Bool, value: V) -> some View {
        animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: value)
    }
}

// MARK: - Island

struct Island<Content: View>: View {
    var label: String?
    var footnote: String?
    var onWindow: Bool
    var padding: CGFloat
    @ViewBuilder var content: () -> Content
    @Environment(\.fxTokens) private var fx

    init(
        label: String? = nil, footnote: String? = nil, onWindow: Bool = false,
        padding: CGFloat = FuturisticStyle.Space.m, @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = label
        self.footnote = footnote
        self.onWindow = onWindow
        self.padding = padding
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label { SectionLabel(label) }
            content()
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(IslandBackground(fill: onWindow ? fx.prefsIslandFill : fx.islandFill))
            if let footnote {
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// Fill, 1pt stroke and a 1pt highlight along the top edge. No drop shadow.
struct IslandBackground: View {
    let fill: Color
    @Environment(\.fxTokens) private var fx

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: FuturisticStyle.Radius.island, style: .continuous)
        shape.fill(fill)
            .overlay(shape.strokeBorder(fx.islandStroke, lineWidth: 1))
            .overlay(alignment: .top) {
                Rectangle().fill(fx.islandEdgeHighlight).frame(height: 1)
                    .padding(.horizontal, FuturisticStyle.Radius.island / 2)
            }
            .clipShape(shape)
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Rows and controls

struct SwitchRow: View {
    let symbol: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    @Environment(\.fxTokens) private var fx
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    init(symbol: String, title: String, subtitle: String, isOn: Binding<Bool>) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn ? fx.onAccent : Color.primary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: FuturisticStyle.Radius.badge, style: .continuous)
                        .fill(isOn ? AnyShapeStyle(fx.accent) : AnyShapeStyle(.quaternary))
                )
                .shadow(color: isOn ? fx.glowColor : .clear, radius: isOn ? fx.glowRadius : 0)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .accessibilityValue(subtitle)
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: FuturisticStyle.Radius.md, style: .continuous)
                .fill(hovering ? fx.islandFillHover : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .fxAnimation(reduceMotion, value: hovering)
    }
}

struct Chip: View {
    enum Tone { case neutral, accent, success, warning, danger }
    let text: String
    let tone: Tone
    let symbol: String?
    @Environment(\.fxTokens) private var fx

    init(_ text: String, tone: Tone, symbol: String? = nil) {
        self.text = text
        self.tone = tone
        self.symbol = symbol
    }

    private var color: Color {
        switch tone {
        case .neutral: return .secondary
        case .accent: return fx.accentText
        case .success: return .green
        case .warning: return .orange
        case .danger: return .red
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(size: 9, weight: .semibold)) }
            Text(text).lineLimit(1).truncationMode(.tail)
        }
        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .frame(height: 18)
        .background(
            RoundedRectangle(cornerRadius: FuturisticStyle.Radius.sm, style: .continuous)
                .fill((tone == .neutral ? Color.gray : color).opacity(0.14))
        )
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

struct StatusDot: View {
    enum Tone { case healthy, failing, unchecked, learning }
    let tone: Tone
    let help: String
    @Environment(\.fxTokens) private var fx

    init(tone: Tone, help: String) {
        self.tone = tone
        self.help = help
    }

    private var color: Color {
        switch tone {
        case .healthy: return .green
        case .failing: return .orange
        case .unchecked: return Color.secondary.opacity(0.4)
        case .learning: return fx.accent
        }
    }

    var body: some View {
        Circle().fill(color)
            .frame(width: 8, height: 8)
            .help(help)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(help)
    }
}

private struct PillButtonStyle: ButtonStyle {
    let prominent: Bool
    @Environment(\.fxTokens) private var fx
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: FuturisticStyle.Radius.md, style: .continuous)
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(prominent ? fx.onAccent : Color.primary)
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(shape.fill(prominent ? fx.accent : fx.islandFill))
            .overlay(shape.strokeBorder(prominent ? Color.clear : fx.islandStroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PillButton: View {
    let title: String
    let symbol: String?
    let prominent: Bool
    let action: () -> Void

    init(_ title: String, symbol: String? = nil, prominent: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.prominent = prominent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .semibold)) }
                Text(title).lineLimit(1)
            }
        }
        .buttonStyle(PillButtonStyle(prominent: prominent))
    }
}

// Plain text link, like the bottom items in the system's own menu bar panels.
struct LinkButton: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

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

struct Monogram: View {
    let name: String
    let active: Bool
    @Environment(\.fxTokens) private var fx

    init(_ name: String, active: Bool) {
        self.name = name
        self.active = active
    }

    var body: some View {
        Text(String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(active ? fx.accentText : Color.secondary)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: FuturisticStyle.Radius.badge, style: .continuous)
                    .fill(active ? fx.accent.opacity(0.16) : Color.gray.opacity(0.14))
            )
            .accessibilityHidden(true)
    }
}
