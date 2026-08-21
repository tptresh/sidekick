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

// MARK: - Sasuke: his Rinnegan fills the screen and starts turning

// Where the Rinnegan sits inside the picture, measured off the artwork itself:
// the centre of the iris, and its half width and half height as fractions of
// the image. His eye is turned away from us, so the iris is an ellipse rather
// than a circle, which the spin has to account for.
private enum EyeArt {
    // Where his Rinnegan sits in the picture, fitted to the artwork: the middle
    // of the iris, its semi-major axis as a fraction of the picture's width,
    // how far the minor axis is squashed against it, and how far it leans. His
    // eye is turned away from us, so the iris is a tilted ellipse.
    static let centre = UnitPoint(x: 0.4950, y: 0.5704)
    static let major: CGFloat = 0.2620
    static let squash: CGFloat = 0.560
    static let tilt: Double = -16.0
}

// Where each smaller eye opens, as fractions of the screen, with the size it
// opens to as a fraction of the shorter side. Pushed out to the edges so his
// own Rinnegan keeps the middle of the screen.
private let rinneganScatter: [(x: CGFloat, y: CGFloat, size: CGFloat, spin: Double)] = [
    (0.10, 0.15, 0.11, 12), (0.89, 0.13, 0.10, -18),
    (0.06, 0.80, 0.09, -22), (0.93, 0.83, 0.11, 16),
    (0.22, 0.90, 0.07, 24), (0.77, 0.92, 0.08, -8),
    (0.04, 0.45, 0.07, 6), (0.96, 0.50, 0.08, -14),
    (0.31, 0.06, 0.06, 20), (0.66, 0.05, 0.07, -6),
    (0.16, 0.62, 0.06, 10), (0.84, 0.66, 0.06, -20),
]

private struct RinneganAwakenView: View {
    let size: CGSize
    let applyTheme: () -> Void
    let finished: () -> Void

    private let shortSide: CGFloat
    private let portrait: NSImage?

    @State private var dimmed = false
    @State private var arrived = false
    @State private var spin: Double = 0
    @State private var pulseOne = false
    @State private var pulseTwo = false
    @State private var opened = 0
    @State private var flash = false
    @State private var visible = true

    init(size: CGSize, applyTheme: @escaping () -> Void, finished: @escaping () -> Void) {
        self.size = size
        self.applyTheme = applyTheme
        self.finished = finished
        shortSide = min(size.width, size.height)
        portrait = SasukePortrait.image()
    }

    // The picture is scaled to cover the screen, so its own size only matters
    // for the aspect ratio.
    private var displaySize: CGSize {
        guard let portrait, portrait.size.height > 0 else { return size }
        let aspect = portrait.size.width / portrait.size.height
        let height = max(size.height, size.width / aspect)
        return CGSize(width: height * aspect, height: height)
    }

    // Middle of his iris in screen coordinates, which is where the chakra rings
    // roll out from.
    private var irisCentre: CGPoint {
        let display = displaySize
        return CGPoint(
            x: size.width / 2 + (EyeArt.centre.x - 0.5) * display.width,
            y: size.height / 2 + (EyeArt.centre.y - 0.5) * display.height
        )
    }

    var body: some View {
        ZStack {
            Color.black.opacity(dimmed ? 0.85 : 0)
            eye
            pulse(out: pulseOne)
            pulse(out: pulseTwo)
            eyes
            SasukeArt.rinneganPurple.opacity(flash ? 0.45 : 0)
        }
        .frame(width: size.width, height: size.height)
        .opacity(visible ? 1 : 0)
        .onAppear(perform: run)
    }

    @ViewBuilder
    private var eye: some View {
        if let portrait {
            let display = displaySize
            ZStack {
                picture(portrait, display)
                // A Rinnegan drawn to match the one in the picture, laid over
                // it and turned. Rotating the artwork itself instead means
                // fighting the ellipse: the rings slide out of true and beat
                // against the ones underneath, and his eyelid comes round with
                // them. Drawing it means only the tomoe move, which is the part
                // that should.
                SasukeIris(diameter: EyeArt.major * display.width * 2)
                    .rotationEffect(.degrees(spin))
                    .scaleEffect(x: 1, y: EyeArt.squash)
                    .rotationEffect(.degrees(EyeArt.tilt))
                    .position(
                        x: EyeArt.centre.x * display.width,
                        y: EyeArt.centre.y * display.height
                    )
            }
            .frame(width: display.width, height: display.height)
            .scaleEffect(arrived ? 1 : 1.1)
            .opacity(arrived ? 1 : 0)
            .frame(width: size.width, height: size.height)
            .clipped()
        }
    }

    private func picture(_ image: NSImage, _ display: CGSize) -> some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .frame(width: display.width, height: display.height)
    }

    // A ring of chakra thrown out of his eye, thinning as it goes.
    private func pulse(out: Bool) -> some View {
        Circle()
            .stroke(SasukeArt.rinneganPurple.opacity(0.7), lineWidth: shortSide * 0.012)
            .frame(width: shortSide * 0.5, height: shortSide * 0.5)
            .scaleEffect(out ? 3.4 : 0.2)
            .opacity(out ? 0 : 0.85)
            .position(irisCentre)
    }

    private var eyes: some View {
        ForEach(Array(rinneganScatter.enumerated()), id: \.offset) { index, eye in
            let diameter = eye.size * shortSide
            RinneganDisc(diameter: diameter)
                .rotationEffect(.degrees(eye.spin + spin * 0.4))
                .shadow(color: SasukeArt.rinneganPurple.opacity(0.85), radius: diameter * 0.22)
                .scaleEffect(index < opened ? 1 : 0.15)
                .opacity(index < opened ? 1 : 0)
                .position(x: eye.x * size.width, y: eye.y * size.height)
        }
    }

    private func run() {
        step(0.02, .easeOut(duration: 0.30)) { dimmed = true }
        step(0.08, .easeOut(duration: 0.75)) { arrived = true }
        // One long ease in, so the Rinnegan winds up rather than snapping round.
        step(0.55, .easeIn(duration: 2.45)) { spin = 1260 }
        step(1.05, .easeOut(duration: 1.15)) { pulseOne = true }
        step(1.40, .easeOut(duration: 1.15)) { pulseTwo = true }
        for index in rinneganScatter.indices {
            step(1.10 + Double(index) * 0.06, .spring(response: 0.34, dampingFraction: 0.62)) {
                opened = index + 1
            }
        }
        step(2.10, .easeOut(duration: 0.16)) { flash = true }
        step(2.16, nil) { applyTheme() }
        step(2.30, .easeOut(duration: 0.38)) { flash = false }
        step(2.85, .easeIn(duration: 0.50)) { visible = false }
        step(3.45, nil) { finished() }
    }
}
