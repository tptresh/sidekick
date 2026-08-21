import AppKit
import SwiftUI

// Plays a full screen entrance when the theme changes: the Spidey mask
// swings in on a web line, or the bat signal lights up the sky. The overlay
// is a borderless click-through window above everything, and the theme
// itself flips mid-animation so the app is already dressed when it fades.
final class ThemeAnimator {
    static let shared = ThemeAnimator()

    private var window: NSWindow?
    private var isRunning = false

    func play(_ theme: HeroTheme) {
        guard !isRunning, let screen = NSScreen.main else {
            SettingsStore.shared.theme = theme
            return
        }
        isRunning = true

        let overlay = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.hasShadow = false
        overlay.level = .screenSaver
        overlay.ignoresMouseEvents = true
        overlay.isReleasedWhenClosed = false
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = ThemeEntranceView(
            theme: theme,
            size: screen.frame.size,
            applyTheme: { SettingsStore.shared.theme = theme },
            finished: { [weak self] in self?.dismiss() }
        )
        overlay.contentView = NSHostingView(rootView: view)
        overlay.setFrame(screen.frame, display: true)
        overlay.orderFrontRegardless()
        window = overlay
    }

    private func dismiss() {
        window?.orderOut(nil)
        window = nil
        isRunning = false
    }

    // Dev helper: captures the overlay's current contents for snapshot review.
    func captureFrame(to path: String) {
        guard let view = window?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}

// Runs a state change after a delay, animated when an animation is given.
private func step(_ delay: Double, _ animation: Animation?, _ change: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        if let animation {
            withAnimation(animation) { change() }
        } else {
            change()
        }
    }
}

private struct ThemeEntranceView: View {
    let theme: HeroTheme
    let size: CGSize
    let applyTheme: () -> Void
    let finished: () -> Void

    var body: some View {
        Group {
            switch theme {
            case .spiderman:
                WebSlingView(size: size, applyTheme: applyTheme, finished: finished)
            case .batman:
                BatSignalView(size: size, applyTheme: applyTheme, finished: finished)
            case .ironMan:
                IronAssembleView(size: size, applyTheme: applyTheme, finished: finished)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Spider-Man: the mask drops in on a web line and swings

private struct WebSlingView: View {
    let size: CGSize
    let applyTheme: () -> Void
    let finished: () -> Void

    private let maskImage: NSImage
    private let maskSize: CGFloat
    private let hangCenterY: CGFloat

    @State private var dropped = false
    @State private var swayAngle: Double = 0
    @State private var dimmed = false
    @State private var visible = true

    init(size: CGSize, applyTheme: @escaping () -> Void, finished: @escaping () -> Void) {
        self.size = size
        self.applyTheme = applyTheme
        self.finished = finished
        maskSize = min(size.width, size.height) * 0.30
        hangCenterY = size.height * 0.42
        maskImage = StatusIcons.watermark(
            for: .spiderman,
            size: maskSize,
            color: NSColor(red: 0.75, green: 0.16, blue: 0.21, alpha: 1)
        )
    }

    // The web line and mask move as one piece. The line is a full screen tall
    // so its top always stays offscreen while the assembly drops and swings.
    private var assemblyHeight: CGFloat { size.height + maskSize }
    private var restOffset: CGFloat { hangCenterY - maskSize / 2 - size.height }
    private var startOffset: CGFloat { -assemblyHeight }

    // Pivot where the web line crosses the top edge of the screen at rest,
    // so the sway reads as a pendulum hanging from the ceiling.
    private var pivot: UnitPoint {
        UnitPoint(x: 0.5, y: (size.height + maskSize / 2 - hangCenterY) / assemblyHeight)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(dimmed ? 0.32 : 0)
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.88))
                    .frame(width: 3, height: size.height)
                    .shadow(color: .white.opacity(0.6), radius: 3)
                Image(nsImage: maskImage)
                    .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
            }
            .frame(width: maskSize)
            .rotationEffect(.degrees(swayAngle), anchor: pivot)
            .offset(y: dropped ? restOffset : startOffset)
        }
        .opacity(visible ? 1 : 0)
        .onAppear(perform: run)
    }

    private func run() {
        step(0.02, .easeOut(duration: 0.25)) { dimmed = true }
        step(0.05, .spring(response: 0.75, dampingFraction: 0.58)) { dropped = true }
        step(0.55, nil) { applyTheme() }
        step(0.70, .easeInOut(duration: 0.35)) { swayAngle = 4.0 }
        step(1.05, .easeInOut(duration: 0.35)) { swayAngle = -2.5 }
        step(1.40, .easeInOut(duration: 0.30)) { swayAngle = 1.0 }
        step(1.70, .easeInOut(duration: 0.25)) { swayAngle = 0 }
        step(2.00, .easeIn(duration: 0.45)) { visible = false }
        step(2.55, nil) { finished() }
    }
}

// MARK: - Batman: a searchlight beam flickers on and projects the signal

private struct BatSignalView: View {
    let size: CGSize
    let applyTheme: () -> Void
    let finished: () -> Void

    private let batImage: NSImage
    private let signalCenter: CGPoint
    private let signalRadius: CGFloat

    @State private var dimmed = false
    @State private var beamOn = false
    @State private var beamAngle: Double = -9
    @State private var signalShown = false
    @State private var visible = true

    init(size: CGSize, applyTheme: @escaping () -> Void, finished: @escaping () -> Void) {
        self.size = size
        self.applyTheme = applyTheme
        self.finished = finished
        signalCenter = CGPoint(x: size.width * 0.62, y: size.height * 0.30)
        signalRadius = min(size.width, size.height) * 0.18
        batImage = StatusIcons.watermark(
            for: .batman,
            size: signalRadius * 1.9,
            color: .black
        )
    }

    var body: some View {
        ZStack {
            Color.black.opacity(dimmed ? 0.5 : 0)
            Group {
                BeamShape(target: signalCenter, halfWidth: signalRadius * 0.85)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.03), Color.white.opacity(0.30)],
                        startPoint: .bottomLeading, endPoint: .topTrailing
                    ))
                    .opacity(beamOn ? 1 : 0)
                signalDisc
                    .opacity(signalShown ? 1 : 0)
                    .scaleEffect(signalShown ? 1 : 0.55)
            }
            .rotationEffect(.degrees(beamAngle), anchor: .bottomLeading)
        }
        .opacity(visible ? 1 : 0)
        .onAppear(perform: run)
    }

    private var signalDisc: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [
                        Color.white.opacity(0.95),
                        Color.white.opacity(0.75),
                        Color.white.opacity(0.0),
                    ],
                    center: .center,
                    startRadius: signalRadius * 0.15,
                    endRadius: signalRadius * 1.35
                ))
                .frame(width: signalRadius * 2.7, height: signalRadius * 2.7)
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: signalRadius * 2, height: signalRadius * 2)
            Image(nsImage: batImage)
        }
        .position(signalCenter)
    }

    private func run() {
        step(0.02, .easeOut(duration: 0.30)) { dimmed = true }
        // The searchlight sputters to life before the beam steadies.
        step(0.15, .linear(duration: 0.04)) { beamOn = true }
        step(0.26, .linear(duration: 0.04)) { beamOn = false }
        step(0.34, .linear(duration: 0.04)) { beamOn = true }
        step(0.44, .linear(duration: 0.04)) { beamOn = false }
        step(0.52, .linear(duration: 0.05)) { beamOn = true }
        // Sweep up into position, then the signal snaps into focus.
        step(0.60, .easeOut(duration: 0.55)) { beamAngle = 0 }
        step(1.20, .spring(response: 0.45, dampingFraction: 0.7)) { signalShown = true }
        step(1.25, nil) { applyTheme() }
        step(2.40, .easeIn(duration: 0.50)) { visible = false }
        step(3.00, nil) { finished() }
    }
}

// A light cone from just past the bottom left corner up to the signal.
private struct BeamShape: Shape {
    let target: CGPoint
    let halfWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let origin = CGPoint(x: -40, y: rect.height + 40)
        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let length = max(sqrt(dx * dx + dy * dy), 1)
        let px = -dy / length
        let py = dx / length
        var path = Path()
        path.move(to: origin)
        path.addLine(to: CGPoint(x: target.x + px * halfWidth, y: target.y + py * halfWidth))
        path.addLine(to: CGPoint(x: target.x - px * halfWidth, y: target.y - py * halfWidth))
        path.closeSubpath()
        return path
    }
}

// MARK: - Iron Man: the armor pieces fly in and assemble, then the reactor ignites

// The bust is drawn from the same 18x18 unit geometry as the menu bar emblem,
// y flipped for SwiftUI, split into the pieces that fly in separately.
private struct IronPiece: Shape {
    enum Kind {
        case helmet, faceplate, leftShoulder, chest, rightShoulder
    }
    let kind: Kind

    func path(in rect: CGRect) -> Path {
        let u = rect.width / 18
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * u, y: y * u) }
        var path = Path()
        switch kind {
        case .helmet:
            path.move(to: pt(5.6, 11.0))
            path.addLine(to: pt(12.4, 11.0))
            path.addCurve(to: pt(13.1, 6.0), control1: pt(13.0, 10.4), control2: pt(13.1, 8.2))
            path.addCurve(to: pt(9.0, 1.2), control1: pt(13.1, 3.0), control2: pt(11.5, 1.2))
            path.addCurve(to: pt(4.9, 6.0), control1: pt(6.5, 1.2), control2: pt(4.9, 3.0))
            path.addCurve(to: pt(5.6, 11.0), control1: pt(4.9, 8.2), control2: pt(5.0, 10.4))
            path.closeSubpath()
        case .faceplate:
            path.move(to: pt(6.3, 10.6))
            path.addLine(to: pt(11.7, 10.6))
            path.addCurve(to: pt(12.2, 6.4), control1: pt(12.1, 10.0), control2: pt(12.2, 8.2))
            path.addCurve(to: pt(9.0, 4.1), control1: pt(12.2, 5.0), control2: pt(10.8, 4.1))
            path.addCurve(to: pt(5.8, 6.4), control1: pt(7.2, 4.1), control2: pt(5.8, 5.0))
            path.addCurve(to: pt(6.3, 10.6), control1: pt(5.8, 8.2), control2: pt(5.9, 10.0))
            path.closeSubpath()
            // Eye slits, punched by the even-odd fill.
            path.addRoundedRect(in: CGRect(x: 6.4 * u, y: 6.0 * u, width: 2.2 * u, height: 1.0 * u), cornerSize: CGSize(width: 0.5 * u, height: 0.5 * u))
            path.addRoundedRect(in: CGRect(x: 9.4 * u, y: 6.0 * u, width: 2.2 * u, height: 1.0 * u), cornerSize: CGSize(width: 0.5 * u, height: 0.5 * u))
        case .leftShoulder:
            path.move(to: pt(2.3, 17.0))
            path.addLine(to: pt(2.8, 13.6))
            path.addCurve(to: pt(4.9, 12.1), control1: pt(3.0, 12.7), control2: pt(3.8, 12.1))
            path.addLine(to: pt(6.5, 12.1))
            path.addLine(to: pt(6.5, 17.0))
            path.closeSubpath()
        case .chest:
            path.move(to: pt(6.5, 17.0))
            path.addLine(to: pt(6.5, 12.1))
            path.addLine(to: pt(7.3, 12.1))
            path.addCurve(to: pt(9.0, 12.9), control1: pt(8.0, 12.1), control2: pt(8.5, 12.9))
            path.addCurve(to: pt(10.7, 12.1), control1: pt(9.5, 12.9), control2: pt(10.0, 12.1))
            path.addLine(to: pt(11.5, 12.1))
            path.addLine(to: pt(11.5, 17.0))
            path.closeSubpath()
            // Arc reactor socket, punched by the even-odd fill.
            path.addEllipse(in: CGRect(x: 7.65 * u, y: 13.25 * u, width: 2.7 * u, height: 2.7 * u))
        case .rightShoulder:
            path.move(to: pt(15.7, 17.0))
            path.addLine(to: pt(15.2, 13.6))
            path.addCurve(to: pt(13.1, 12.1), control1: pt(15.0, 12.7), control2: pt(14.2, 12.1))
            path.addLine(to: pt(11.5, 12.1))
            path.addLine(to: pt(11.5, 17.0))
            path.closeSubpath()
        }
        return path
    }
}

private struct IronAssembleView: View {
    let size: CGSize
    let applyTheme: () -> Void
    let finished: () -> Void

    private let armorRed = Color(red: 0.678, green: 0.106, blue: 0.086)
    private let armorGold = Color(red: 0.855, green: 0.663, blue: 0.243)
    private let reactorBlue = Color(red: 0.62, green: 0.90, blue: 1.0)

    @State private var dimmed = false
    @State private var leftIn = false
    @State private var rightIn = false
    @State private var chestIn = false
    @State private var helmetIn = false
    @State private var faceOn = false
    @State private var reactorOn = false
    @State private var flash = false
    @State private var visible = true

    var body: some View {
        let side = min(size.width, size.height) * 0.5
        let u = side / 18
        ZStack {
            Color.black.opacity(dimmed ? 0.5 : 0)
            ZStack {
                IronPiece(kind: .leftShoulder)
                    .fill(armorRed)
                    .rotationEffect(.degrees(leftIn ? 0 : -35))
                    .offset(x: leftIn ? 0 : -size.width * 0.55)
                    .opacity(leftIn ? 1 : 0)
                IronPiece(kind: .rightShoulder)
                    .fill(armorRed)
                    .rotationEffect(.degrees(rightIn ? 0 : 35))
                    .offset(x: rightIn ? 0 : size.width * 0.55)
                    .opacity(rightIn ? 1 : 0)
                IronPiece(kind: .chest)
                    .fill(armorGold, style: FillStyle(eoFill: true))
                    .offset(y: chestIn ? 0 : size.height * 0.55)
                    .opacity(chestIn ? 1 : 0)
                IronPiece(kind: .helmet)
                    .fill(armorRed)
                    .rotationEffect(.degrees(helmetIn ? 0 : 10))
                    .offset(y: helmetIn ? 0 : -size.height * 0.55)
                    .opacity(helmetIn ? 1 : 0)
                // The faceplate flies in "toward us": it starts big and settles.
                IronPiece(kind: .faceplate)
                    .fill(armorGold, style: FillStyle(eoFill: true))
                    .scaleEffect(faceOn ? 1 : 2.8)
                    .opacity(faceOn ? 1 : 0)
                Circle()
                    .fill(reactorBlue)
                    .frame(width: 2.7 * u, height: 2.7 * u)
                    .position(x: 9.0 * u, y: 14.6 * u)
                    .shadow(color: reactorBlue.opacity(0.9), radius: reactorOn ? 2.2 * u : 0)
                    .opacity(reactorOn ? 1 : 0)
                    .scaleEffect(reactorOn ? 1 : 0.3)
            }
            .frame(width: side, height: side)
            Color.white.opacity(flash ? 0.55 : 0)
        }
        .frame(width: size.width, height: size.height)
        .opacity(visible ? 1 : 0)
        .onAppear(perform: run)
    }

    private func run() {
        let snap = Animation.spring(response: 0.42, dampingFraction: 0.72)
        step(0.05, .easeIn(duration: 0.2)) { dimmed = true }
        step(0.20, snap) { leftIn = true }
        step(0.32, snap) { rightIn = true }
        step(0.48, snap) { chestIn = true }
        step(0.66, snap) { helmetIn = true }
        step(0.90, .spring(response: 0.38, dampingFraction: 0.68)) { faceOn = true }
        step(1.25, .easeOut(duration: 0.18)) {
            reactorOn = true
            flash = true
        }
        step(1.30, nil) { applyTheme() }
        step(1.45, .easeOut(duration: 0.30)) { flash = false }
        step(2.05, .easeOut(duration: 0.40)) {
            dimmed = false
            visible = false
        }
        step(2.55, nil) { finished() }
    }
}
