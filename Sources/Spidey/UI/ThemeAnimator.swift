import AppKit
import SwiftUI

// Plays a full screen entrance when the theme changes: the Spidey mask swings
// in on a web line, the bat signal lights up the sky, or Sasuke turns up and
// opens Rinnegan all over the screen. The overlay is a borderless
// click-through window above everything, and the theme itself flips
// mid-animation so the app is already dressed when it fades.
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
            case .sasuke:
                RinneganAwakenView(size: size, applyTheme: applyTheme, finished: finished)
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

// MARK: - Sasuke: his face appears and Rinnegan open all over the screen

// Where each eye opens, as fractions of the screen, with the size it opens to
// as a fraction of the shorter side. Kept off the middle so his face stays
// readable underneath, and ordered so they spread outwards as they fire.
private let rinneganScatter: [(x: CGFloat, y: CGFloat, size: CGFloat, spin: Double)] = [
    (0.30, 0.34, 0.11, 12), (0.70, 0.31, 0.10, -18),
    (0.15, 0.20, 0.15, 24), (0.84, 0.22, 0.13, -8),
    (0.22, 0.71, 0.14, -22), (0.78, 0.74, 0.12, 16),
    (0.07, 0.48, 0.09, 6), (0.93, 0.52, 0.10, -14),
    (0.38, 0.11, 0.08, 20), (0.62, 0.90, 0.09, -6),
    (0.13, 0.87, 0.07, 10), (0.88, 0.85, 0.08, -20),
    (0.47, 0.93, 0.06, 4), (0.55, 0.07, 0.07, -12),
    (0.04, 0.68, 0.05, 18), (0.96, 0.34, 0.06, -4),
]

private struct RinneganAwakenView: View {
    let size: CGSize
    let applyTheme: () -> Void
    let finished: () -> Void

    private let headSide: CGFloat
    private let shortSide: CGFloat

    @State private var dimmed = false
    @State private var faceIn = false
    @State private var lit = false
    @State private var opened = 0
    @State private var flash = false
    @State private var visible = true

    init(size: CGSize, applyTheme: @escaping () -> Void, finished: @escaping () -> Void) {
        self.size = size
        self.applyTheme = applyTheme
        self.finished = finished
        shortSide = min(size.width, size.height)
        headSide = shortSide * 0.62 * 18 / SasukeArt.headWidthUnits
    }

    var body: some View {
        ZStack {
            Color.black.opacity(dimmed ? 0.72 : 0)
            head
            eyes
            SasukeArt.rinneganPurple.opacity(flash ? 0.45 : 0)
        }
        .frame(width: size.width, height: size.height)
        .opacity(visible ? 1 : 0)
        .onAppear(perform: run)
    }

    // The head sits in the top half of its own box, so it is centred on its
    // head centre rather than on the box.
    private var head: some View {
        let unit = headSide / 18
        return SasukeHeadView(side: headSide, glow: lit)
            .offset(
                x: (9 - SasukeArt.headCentre.x) * unit,
                y: (9 - SasukeArt.headCentre.y) * unit
            )
            .scaleEffect(faceIn ? 1 : 0.9)
            .opacity(faceIn ? 1 : 0)
            .position(x: size.width / 2, y: size.height / 2)
    }

    private var eyes: some View {
        ForEach(Array(rinneganScatter.enumerated()), id: \.offset) { index, eye in
            let diameter = eye.size * shortSide
            RinneganDisc(diameter: diameter)
                .rotationEffect(.degrees(eye.spin))
                .shadow(color: SasukeArt.rinneganPurple.opacity(0.85), radius: diameter * 0.22)
                .scaleEffect(index < opened ? 1 : 0.15)
                .opacity(index < opened ? 1 : 0)
                .position(x: eye.x * size.width, y: eye.y * size.height)
        }
    }

    private func run() {
        step(0.02, .easeOut(duration: 0.32)) { dimmed = true }
        step(0.10, .spring(response: 0.55, dampingFraction: 0.8)) { faceIn = true }
        step(0.62, .easeInOut(duration: 0.30)) { lit = true }
        for index in rinneganScatter.indices {
            step(0.82 + Double(index) * 0.055, .spring(response: 0.34, dampingFraction: 0.62)) {
                opened = index + 1
            }
        }
        step(1.80, .easeOut(duration: 0.16)) { flash = true }
        step(1.86, nil) { applyTheme() }
        step(2.00, .easeOut(duration: 0.38)) { flash = false }
        step(2.60, .easeIn(duration: 0.50)) { visible = false }
        step(3.20, nil) { finished() }
    }
}
