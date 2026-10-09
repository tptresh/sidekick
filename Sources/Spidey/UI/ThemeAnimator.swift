import AppKit
import SwiftUI

// Plays a full screen entrance: the Spidey mask swings in on a web line. The
// overlay is a borderless click-through window above everything, and the theme
// itself is applied mid-animation so the app is already dressed when it fades.
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
