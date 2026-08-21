import AppKit

// A borderless black overlay that shows one line of text as big as fits,
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
        label.lineBreakMode = .byClipping
        label.sizeToFit()

        let padding: CGFloat = 40
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

        let background = NSView(frame: NSRect(origin: .zero, size: size))
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.92).cgColor
        background.layer?.cornerRadius = 24
        label.frame = NSRect(
            x: (size.width - label.frame.width) / 2,
            y: (size.height - label.frame.height) / 2,
            width: label.frame.width, height: label.frame.height
        )
        background.addSubview(label)
        window.contentView = background

        current = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    static func dismiss() {
        current?.orderOut(nil)
        current?.close()
        current = nil
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
