import AppKit

// A borderless dark glass card that shows one line of text as big as fits,
// centered on the main screen. Any key press or click dismisses it.
final class LargeTypeWindow: NSWindow {
    private static var current: LargeTypeWindow?

    static func show(_ text: String) {
        dismiss()
        guard let screen = NSScreen.main else { return }
        let maxWidth = screen.visibleFrame.width * 0.85

        let label = NSTextField(labelWithString: text)
        label.font = fittingFont(for: text, maxWidth: maxWidth - 80)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.sizeToFit()

        let padding: CGFloat = 40
        // Text too long even at the smallest size is cut with an ellipsis
        // instead of being clipped at both edges.
        label.frame.size.width = min(label.frame.width, maxWidth - padding * 2)
        let size = NSSize(
            width: min(label.frame.width + padding * 2, maxWidth),
            height: label.frame.height + padding * 2
        )
        let origin = NSPoint(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.midY - size.height / 2
        )

        let window = LargeTypeWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .transient]
        window.appearance = NSAppearance(named: .darkAqua)
        window.hasShadow = true

        let content = NSView(frame: NSRect(origin: .zero, size: size))
        label.frame = NSRect(
            x: (size.width - label.frame.width) / 2,
            y: (size.height - label.frame.height) / 2,
            width: label.frame.width, height: label.frame.height
        )
        content.addSubview(label)
        window.contentView = card(holding: content, size: size)

        current = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    static func dismiss() {
        current?.orderOut(nil)
        current?.close()
        current = nil
    }

    // Dark Liquid Glass on macOS 26, the HUD blur before that, and a solid
    // near-black card under Reduce Transparency.
    private static func card(holding content: NSView, size: NSSize) -> NSView {
        let radius: CGFloat = 28
        let tint = NSColor.black.withAlphaComponent(0.55)
        if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
            content.wantsLayer = true
            content.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.94).cgColor
            content.layer?.cornerRadius = radius
            return content
        }
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: size))
            glass.cornerRadius = radius
            glass.tintColor = tint
            glass.contentView = content
            return glass
        }
        let blur = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = radius
        blur.layer?.masksToBounds = true
        content.wantsLayer = true
        content.layer?.backgroundColor = tint.cgColor
        content.frame = blur.bounds
        content.autoresizingMask = [.width, .height]
        blur.addSubview(content)
        return blur
    }

    private static func fittingFont(for text: String, maxWidth: CGFloat) -> NSFont {
        let base: CGFloat = 200
        let font = NSFont.systemFont(ofSize: base, weight: .bold)
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        guard width > maxWidth else { return font }
        let scaled = max(base * maxWidth / width, 24)
        return NSFont.systemFont(ofSize: scaled, weight: .bold)
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        Self.dismiss()
    }

    override func mouseDown(with event: NSEvent) {
        Self.dismiss()
    }

    override func resignKey() {
        super.resignKey()
        Self.dismiss()
    }
}
