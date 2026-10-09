import SwiftUI
import AppKit

// Shared look for the search panel, the menu bar panel and Preferences: Liquid
// Glass surfaces on macOS 26 (material on older systems, solid under Reduce
// Transparency), one spacing and radius scale, and the theme red kept for
// accents only. Spidey's own windows are always dark, so every colour here is
// tuned for dark glass. Views read colours from the environment so none of
// them takes an accent colour as a parameter.
enum FuturisticStyle {
    struct Tokens {
        let accent: Color
        let accentText: Color
        let onAccent: Color
        // Quiet fill for rows and controls that sit on a glass card.
        let fill: Color
        let fillHover: Color
        let hairline: Color
        // Card colour when Reduce Transparency turns the glass off.
        let solidSurface: Color
        let selection: Color
        let ambient: Color

        static func resolve(theme: HeroTheme) -> Tokens {
            Tokens(
                accent: theme.accent,
                accentText: theme.accentText,
                onAccent: theme.onAccent,
                fill: Color.white.opacity(0.06),
                fillHover: Color.white.opacity(0.10),
                hairline: Color.white.opacity(0.10),
                solidSurface: Color(white: 0.14),
                selection: theme.accent.opacity(0.30),
                ambient: theme.accent.opacity(0.10)
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

    // The one corner radius scale: tiles and small controls, rows, cards, panel.
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 18
        static let xl: CGFloat = 22
    }

    enum Motion {
        static let quick = Animation.easeOut(duration: 0.15)
    }
}

private struct FXTokensKey: EnvironmentKey {
    static let defaultValue = FuturisticStyle.Tokens.resolve(theme: .spiderman)
}

extension EnvironmentValues {
    var fxTokens: FuturisticStyle.Tokens {
        get { self[FXTokensKey.self] }
        set { self[FXTokensKey.self] = newValue }
    }
}

extension View {
    // Theme tokens, the red tint, and a dark appearance for the hosting window
    // whatever the system is set to.
    func futuristicTheme(_ theme: HeroTheme) -> some View {
        let tokens = FuturisticStyle.Tokens.resolve(theme: theme)
        return self
            .environment(\.fxTokens, tokens)
            .tint(tokens.accent)
            .environment(\.colorScheme, .dark)
            .background(DarkWindowAppearance())
    }

    // A glass surface in the given shape: real Liquid Glass on macOS 26,
    // ultra thin material before that, and a solid card under Reduce
    // Transparency so text never sits on a busy wallpaper.
    func fxGlass<S: InsettableShape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassSurface(shape: shape, tint: tint, interactive: interactive))
    }

    // Hover/press animation that switches off under Reduce Motion.
    func fxAnimation<V: Equatable>(_ reduceMotion: Bool, value: V) -> some View {
        animation(reduceMotion ? nil : FuturisticStyle.Motion.quick, value: value)
    }
}

// Puts the window that hosts this view into Dark Aqua, so AppKit chrome (the
// popover, title bar, pickers, text fields) matches the dark SwiftUI content.
private struct DarkWindowAppearance: NSViewRepresentable {
    final class Probe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ nsView: Probe, context: Context) {}
}

private struct GlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.fxTokens) private var fx

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(shape.fill(tint ?? fx.solidSurface))
                .overlay(shape.strokeBorder(fx.hairline, lineWidth: 1))
        } else if #available(macOS 26, *) {
            content.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            content
                .background(shape.fill(tint ?? Color.clear))
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(fx.hairline, lineWidth: 0.5))
        }
    }
}

// Groups neighbouring glass surfaces so macOS 26 renders them as one family
// with shared sampling. Spacing 0 keeps separate cards from melting together.
// A plain stack before macOS 26.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: () -> Content

    init(spacing: CGFloat = 0, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}

// MARK: - Island

// A glass card with an optional small heading above it and a footnote below.
// Heading and footnote are inset to line up with the text inside the card.
struct Island<Content: View>: View {
    var label: String?
    var footnote: String?
    var padding: CGFloat
    @ViewBuilder var content: () -> Content

    init(
        label: String? = nil, footnote: String? = nil,
        padding: CGFloat = FuturisticStyle.Space.m, @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = label
        self.footnote = footnote
        self.padding = padding
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FuturisticStyle.Space.s) {
            if let label {
                SectionLabel(label).padding(.horizontal, FuturisticStyle.Space.m)
            }
            content()
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fxGlass(in: RoundedRectangle(cornerRadius: FuturisticStyle.Radius.lg, style: .continuous))
            if let footnote {
                Text(footnote)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, FuturisticStyle.Space.m)
            }
        }
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

// 1pt line between rows inside a card, inset to the row text.
struct RowLine: View {
    @Environment(\.fxTokens) private var fx
    var body: some View {
        Rectangle().fill(fx.hairline).frame(height: 1).padding(.horizontal, FuturisticStyle.Space.m)
    }
}

// MARK: - Rows and controls

// Rounded square behind a row's symbol: red when the row is on, quiet otherwise.
struct IconTile: View {
    let symbol: String
    let active: Bool
    @Environment(\.fxTokens) private var fx

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(active ? fx.onAccent : Color.primary)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: FuturisticStyle.Radius.sm, style: .continuous)
                    .fill(active ? AnyShapeStyle(fx.accent) : AnyShapeStyle(fx.fillHover))
            )
            .accessibilityHidden(true)
    }
}

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
        HStack(spacing: FuturisticStyle.Space.m) {
            IconTile(symbol: symbol, active: isOn)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: FuturisticStyle.Space.s)
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .accessibilityValue(subtitle)
        }
        .padding(.horizontal, FuturisticStyle.Space.s)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: FuturisticStyle.Radius.md, style: .continuous)
                .fill(hovering ? fx.fill : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .fxAnimation(reduceMotion, value: hovering)
        .fxAnimation(reduceMotion, value: isOn)
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
        .font(.system(size: 11, weight: .medium))
        .monospacedDigit()
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .frame(height: 20)
        .background(Capsule().fill((tone == .neutral ? Color.white : color).opacity(tone == .neutral ? 0.08 : 0.16)))
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

// Small capsule button. It lives on glass cards, so it uses a quiet fill rather
// than glass of its own (glass on glass inside one container would melt into
// the card). Prominent ones are filled with the theme red; destructive ones
// keep the quiet fill and turn the label red.
private struct PillButtonStyle: ButtonStyle {
    let tone: PillButton.Tone
    @Environment(\.fxTokens) private var fx
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(labelColor)
            .padding(.horizontal, FuturisticStyle.Space.m)
            .frame(height: 26)
            .background(Capsule().fill(tone == .prominent ? fx.accent : (configuration.isPressed ? fx.fillHover : fx.fill)))
            .overlay(Capsule().strokeBorder(tone == .prominent ? Color.clear : fx.hairline, lineWidth: 1))
            .opacity(configuration.isPressed && tone == .prominent ? 0.85 : (isEnabled ? 1 : 0.5))
            .contentShape(Capsule())
    }

    private var labelColor: Color {
        switch tone {
        case .prominent: return fx.onAccent
        case .destructive: return fx.accentText
        case .normal: return .primary
        }
    }
}

struct PillButton: View {
    enum Tone { case normal, prominent, destructive }
    let title: String
    let symbol: String?
    let tone: Tone
    let action: () -> Void

    init(_ title: String, symbol: String? = nil, prominent: Bool = false, action: @escaping () -> Void) {
        self.init(title, symbol: symbol, tone: prominent ? .prominent : .normal, action: action)
    }

    init(_ title: String, symbol: String? = nil, tone: Tone, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.tone = tone
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .semibold)) }
                Text(title).lineLimit(1).fixedSize()
            }
        }
        .buttonStyle(PillButtonStyle(tone: tone))
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
                .contentShape(Rectangle())
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
                RoundedRectangle(cornerRadius: FuturisticStyle.Radius.sm, style: .continuous)
                    .fill(active ? fx.accent.opacity(0.20) : fx.fillHover)
            )
            .accessibilityHidden(true)
    }
}
