import AppKit
import SwiftUI

// Plays a full screen entrance when the theme changes: the Spidey mask swings
// in on a web line, the bat signal lights up the sky, Sasuke turns up and
// opens Rinnegan all over the screen, or the moon over Itachi's pole turns into
// a spinning Sharingan. The overlay is a borderless
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
    // Only the grab itself runs on the main thread; encoding a full screen PNG
    // there takes long enough to stall the animation being recorded.
    func captureFrame(to path: String) {
        guard let view = window?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        DispatchQueue.global(qos: .utility).async {
            guard let png = rep.representation(using: .png, properties: [:]) else { return }
            try? png.write(to: URL(fileURLWithPath: path))
        }
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
            case .sharingan:
                SharinganMoonView(size: size, applyTheme: applyTheme, finished: finished)
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

// MARK: - Sasuke: he arrives and opens Rinnegan all over the screen

// Where each eye opens, as fractions of the screen, with the size it opens to
// as a fraction of the shorter side. Ordered from the middle outwards so they
// bloom away from him as he casts, and kept off his figure so he stays clear.
private let rinneganScatter: [(x: CGFloat, y: CGFloat, size: CGFloat, spin: Double)] = [
    (0.34, 0.30, 0.10, 12), (0.66, 0.30, 0.09, -18),
    (0.30, 0.68, 0.09, -22), (0.70, 0.66, 0.10, 16),
    (0.17, 0.19, 0.14, 24), (0.83, 0.21, 0.13, -8),
    (0.20, 0.79, 0.12, 6), (0.80, 0.81, 0.13, -14),
    (0.06, 0.45, 0.09, 20), (0.94, 0.49, 0.10, -6),
    (0.41, 0.09, 0.07, 10), (0.59, 0.92, 0.08, -20),
    (0.10, 0.90, 0.06, 4), (0.90, 0.10, 0.07, -12),
    (0.03, 0.66, 0.05, 18), (0.97, 0.72, 0.06, -4),
]

private struct RinneganAwakenView: View {
    let size: CGSize
    let applyTheme: () -> Void
    let finished: () -> Void

    private let shortSide: CGFloat
    private let portrait: NSImage?

    @State private var dimmed = false
    @State private var arrived = false
    @State private var charged = false
    @State private var pulseOne = false
    @State private var pulseTwo = false
    @State private var opened = 0
    @State private var flash = false
    @State private var visible = true
    @State private var art: SharinganArtwork?

    init(size: CGSize, applyTheme: @escaping () -> Void, finished: @escaping () -> Void) {
        self.size = size
        self.applyTheme = applyTheme
        self.finished = finished
        shortSide = min(size.width, size.height)
        portrait = SasukePortrait.image()
    }

    private var figureHeight: CGFloat { shortSide * 0.82 }

    var body: some View {
        ZStack {
            Color.black.opacity(dimmed ? 0.74 : 0)
            aura
            pulse(out: pulseOne)
            pulse(out: pulseTwo)
            figure
            eyes
            SasukeArt.rinneganPurple.opacity(flash ? 0.45 : 0)
        }
        .frame(width: size.width, height: size.height)
        .opacity(visible ? 1 : 0)
        .onAppear(perform: run)
    }

    @ViewBuilder
    private var figure: some View {
        if let portrait {
            let aspect = portrait.size.width / max(portrait.size.height, 1)
            Image(nsImage: portrait)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: figureHeight * aspect, height: figureHeight)
                .shadow(
                    color: SasukeArt.rinneganPurple.opacity(charged ? 0.9 : 0),
                    radius: charged ? shortSide * 0.05 : 0
                )
                .scaleEffect(arrived ? 1 : 0.94)
                .opacity(arrived ? 1 : 0)
                .position(x: size.width / 2, y: size.height / 2)
        }
    }

    // The chakra he gathers before the eyes open.
    private var aura: some View {
        Circle()
            .fill(RadialGradient(
                colors: [
                    SasukeArt.rinneganPurple.opacity(0.5),
                    SasukeArt.rinneganPurple.opacity(0.12),
                    .clear,
                ],
                center: .center,
                startRadius: 0,
                endRadius: shortSide * 0.5
            ))
            .frame(width: shortSide, height: shortSide)
            .scaleEffect(charged ? 1 : 0.35)
            .opacity(charged ? 1 : 0)
            .position(x: size.width / 2, y: size.height / 2)
    }

    // A ring of chakra thrown outwards, thinning as it goes.
    private func pulse(out: Bool) -> some View {
        Circle()
            .stroke(SasukeArt.rinneganPurple.opacity(0.75), lineWidth: shortSide * 0.012)
            .frame(width: shortSide * 0.5, height: shortSide * 0.5)
            .scaleEffect(out ? 3.2 : 0.15)
            .opacity(out ? 0 : 0.9)
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
        step(0.10, .spring(response: 0.6, dampingFraction: 0.82)) { arrived = true }
        step(0.62, .easeInOut(duration: 0.45)) { charged = true }
        step(0.95, .easeOut(duration: 1.10)) { pulseOne = true }
        step(1.25, .easeOut(duration: 1.10)) { pulseTwo = true }
        for index in rinneganScatter.indices {
            step(1.00 + Double(index) * 0.055, .spring(response: 0.34, dampingFraction: 0.62)) {
                opened = index + 1
            }
        }
        step(1.98, .easeOut(duration: 0.16)) { flash = true }
        step(2.04, nil) { applyTheme() }
        step(2.18, .easeOut(duration: 0.38)) { flash = false }
        step(2.80, .easeIn(duration: 0.50)) { visible = false }
        step(3.40, nil) { finished() }
    }
}

// MARK: - Sharingan: the moon behind Itachi's pole opens into the eye

// The scene's still layers, flattened to bitmaps once before the entrance
// starts. Drawn live they are hundreds of shapes and gradients redrawn on every
// frame of a full screen animation, which stalls it; as textures the whole
// thing scales and spins for free.
private struct SharinganArtwork {
    let sky: NSImage?
    let moon: NSImage?
    let eye: NSImage?
    let silhouette: NSImage?
}

@MainActor
private func rasterize<V: View>(_ view: V, size: CGSize) -> NSImage? {
    let renderer = ImageRenderer(
        content: view.frame(width: size.width, height: size.height)
    )
    renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
    // cgImage, not nsImage: the NSImage this returns draws itself lazily by
    // re-running the SwiftUI render every time it is composited, which is the
    // opposite of the point.
    guard let bitmap = renderer.cgImage else { return nil }
    return NSImage(cgImage: bitmap, size: size)
}


private struct SharinganMoonView: View {
    let size: CGSize
    let applyTheme: () -> Void
    let finished: () -> Void

    private let shortSide: CGFloat
    private let moonCenter: CGPoint
    private let moonDiameter: CGFloat
    private let poleTopY: CGFloat
    private let figureHeight: CGFloat

    @State private var skyIn = false
    @State private var moonIn = false
    @State private var poleIn = false
    @State private var irisReveal: CGFloat = 0
    @State private var pupilIn = false
    @State private var tomoeShown = 0
    @State private var spin: Double = 0
    @State private var irisSpin: Double = 0
    @State private var shockwave = false
    @State private var eyeGlow: Double = 0
    @State private var flash = false
    @State private var visible = true
    @State private var art: SharinganArtwork?

    init(size: CGSize, applyTheme: @escaping () -> Void, finished: @escaping () -> Void) {
        self.size = size
        self.applyTheme = applyTheme
        self.finished = finished
        shortSide = min(size.width, size.height)
        moonDiameter = min(size.width * 0.50, size.height * 0.74)
        moonCenter = CGPoint(x: size.width * 0.5, y: size.height * 0.42)
        figureHeight = moonDiameter * 0.27
        // He perches low on the moon, so the eye opens above his shoulders
        // instead of behind him.
        poleTopY = moonCenter.y + moonDiameter * 0.36
    }

    var body: some View {
        ZStack {
            Color.black
            layer(art?.sky, size).opacity(skyIn ? 1 : 0)
            moon
            shock
            silhouette
            Color(red: 0.741, green: 0.043, blue: 0.078).opacity(flash ? 0.45 : 0)
        }
        .frame(width: size.width, height: size.height)
        .opacity(visible ? 1 : 0)
        .onAppear {
            art = buildArtwork()
            run()
        }
    }

    @MainActor
    private func buildArtwork() -> SharinganArtwork {
        let moonSize = CGSize(width: moonDiameter, height: moonDiameter)
        let eyeSize = CGSize(width: eyeSpan, height: eyeSpan)
        return SharinganArtwork(
            // The moon's own glow is baked into the sky: it never moves, and a
            // second full screen layer to fade is more than the compositor can
            // carry alongside everything else.
            sky: rasterize(
                ZStack {
                    NightSky(size: size)
                    haloRing(Color(red: 0.988, green: 0.784, blue: 0.882), 0.38)
                        .position(moonCenter)
                },
                size: size
            ),
            moon: rasterize(MoonDisc(diameter: moonDiameter), size: moonSize),
            // The eye carries its own red glow, so the light blooms with it as
            // it takes the moon.
            eye: rasterize(
                ZStack {
                    eyeGlowRing
                    SharinganIris(diameter: moonDiameter)
                    MoonCraters(diameter: moonDiameter).opacity(0.75)
                },
                size: eyeSize
            ),
            silhouette: rasterize(
                ZStack {
                    PoleWires(topY: poleTopY)
                        .stroke(Color.black, lineWidth: max(1.5, shortSide * 0.0038))
                    PoleBody(topY: poleTopY)
                        .fill(Color.black)
                    PerchedFigure(height: figureHeight)
                        .position(x: size.width / 2, y: poleTopY - figureHeight / 2 + shortSide * 0.004)
                },
                size: size
            )
        )
    }

    @ViewBuilder
    private func layer(_ image: NSImage?, _ frame: CGSize) -> some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .frame(width: frame.width, height: frame.height)
        }
    }

    // The glow around the moon, drawn into the sky and again around the eye.
    private func haloRing(_ color: Color, _ strength: Double) -> some View {
        Circle()
            .fill(RadialGradient(
                colors: [color.opacity(strength), color.opacity(strength * 0.35), .clear],
                center: .center,
                startRadius: moonDiameter * 0.42,
                endRadius: moonDiameter * 0.95
            ))
            .frame(width: moonDiameter * 1.9, height: moonDiameter * 1.9)
    }

    // The eye's texture is wider than the moon so its glow has room. The glow
    // has to reach nothing by the texture's own edge, or the square it is drawn
    // into shows as a seam over the sky.
    private var eyeSpan: CGFloat { moonDiameter * 1.42 }

    private var eyeGlowRing: some View {
        Circle()
            .fill(RadialGradient(
                colors: [
                    Color(red: 0.898, green: 0.086, blue: 0.161).opacity(0.75),
                    Color(red: 0.898, green: 0.086, blue: 0.161).opacity(0.28),
                    .clear,
                ],
                center: .center,
                startRadius: moonDiameter * 0.45,
                endRadius: eyeSpan * 0.5
            ))
            .frame(width: eyeSpan, height: eyeSpan)
    }

    private var moon: some View {
        ZStack {
            layer(art?.moon, CGSize(width: moonDiameter, height: moonDiameter))
            // The red floods out from the centre until it has taken the moon.
            layer(art?.eye, CGSize(width: eyeSpan, height: eyeSpan))
                .rotationEffect(.degrees(irisSpin))
                .scaleEffect(irisReveal)
                .opacity(Double(min(irisReveal * 1.6, 1)))
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    SharinganTomoe(diameter: moonDiameter, index: index)
                        .scaleEffect(index < tomoeShown ? 1 : 0.1)
                        .opacity(index < tomoeShown ? 1 : 0)
                }
            }
            .rotationEffect(.degrees(spin))
            SharinganPupil(diameter: moonDiameter)
                .scaleEffect(pupilIn ? 1 : 0.2)
                .opacity(pupilIn ? 1 : 0)
        }
        .frame(width: moonDiameter, height: moonDiameter)
        .scaleEffect(moonIn ? 1 : 0.88)
        .opacity(moonIn ? 1 : 0)
        .position(moonCenter)
    }

    // Chakra thrown off the eye when it spins up.
    private var shock: some View {
        Circle()
            .stroke(Color(red: 0.937, green: 0.106, blue: 0.161).opacity(0.7), lineWidth: shortSide * 0.010)
            .frame(width: moonDiameter, height: moonDiameter)
            .scaleEffect(shockwave ? 2.6 : 0.9)
            // Only there once the eye is, so the pale moon keeps a clean rim.
            .opacity(shockwave ? 0 : 0.85 * Double(irisReveal))
            .position(moonCenter)
    }

    private var silhouette: some View {
        ZStack {
            layer(art?.silhouette, size)
            PerchedFigureEyes(height: figureHeight)
                .opacity(eyeGlow)
                .position(x: size.width / 2, y: poleTopY - figureHeight / 2 + shortSide * 0.004)
        }
        .frame(width: size.width, height: size.height)
        .offset(y: poleIn ? 0 : size.height * 0.16)
        .opacity(poleIn ? 1 : 0)
    }

    private func run() {
        step(0.02, .easeOut(duration: 0.40)) { skyIn = true }
        step(0.20, .easeOut(duration: 0.85)) { moonIn = true }
        step(0.60, .spring(response: 0.70, dampingFraction: 0.85)) { poleIn = true }
        step(1.10, .easeInOut(duration: 0.60)) { irisReveal = 1 }
        step(1.45, .spring(response: 0.35, dampingFraction: 0.7)) { pupilIn = true }
        for index in 0..<3 {
            step(1.55 + Double(index) * 0.09, .spring(response: 0.32, dampingFraction: 0.6)) {
                tomoeShown = index + 1
            }
        }
        // Seven thirds of a turn, so the tomoe land back in their slots.
        step(1.90, .easeInOut(duration: 1.10)) { spin = 840 }
        step(1.90, .easeInOut(duration: 1.10)) { irisSpin = 120 }
        step(1.90, .easeOut(duration: 1.00)) { shockwave = true }
        step(2.05, .easeOut(duration: 0.45)) { eyeGlow = 1 }
        step(2.80, .easeOut(duration: 0.14)) { flash = true }
        step(2.86, nil) { applyTheme() }
        step(3.00, .easeOut(duration: 0.45)) { flash = false }
        step(3.35, .easeIn(duration: 0.50)) { visible = false }
        step(3.90, nil) { finished() }
    }
}
