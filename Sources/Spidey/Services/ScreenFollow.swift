import AppKit
import ApplicationServices

// With more than one display, Sidekick opens on the screen the user last
// clicked on, and whatever a result opens is pulled onto that same screen.
// Moving another app's window needs Accessibility; without it only the panel
// follows. Only a window that changed during the action (a new app in front,
// a new window) or the app a launch row named is moved, so toggles and copies
// never shuffle the user's windows around.
final class ScreenFollow {
    static let shared = ScreenFollow()

    private var lastClick: NSPoint?
    private var monitors: [Any] = []
    private var target: NSRect?
    private var expectedBundleID: String?
    private var stayPut = false
    private var generation = 0

    func start() {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            self?.lastClick = NSEvent.mouseLocation
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.lastClick = NSEvent.mouseLocation
            return event
        }) {
            monitors.append(local)
        }
    }

    // The screen the user is working on: where they last clicked, or where the
    // pointer is before any click has been seen.
    func activeScreen() -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        let point = lastClick ?? NSEvent.mouseLocation
        return screens[Self.index(of: point, in: screens.map(\.frame))]
    }

    // Called when the panel opens, so everything the next result opens lands
    // on the same screen as the panel.
    func pinTarget(_ screen: NSScreen) {
        target = screen.visibleFrame
    }

    // Launch rows name the app they open, so it is moved even when it was
    // already in front with the same window (a link opening in Brave).
    func expect(bundleID: String?) {
        expectedBundleID = bundleID
    }

    // For actions that go to an existing window on purpose (window switcher).
    func leaveWindowsAlone() {
        stayPut = true
    }

    func run(_ action: () -> Void) {
        expectedBundleID = nil
        stayPut = false
        let before = Self.frontWindow()
        action()
        guard NSScreen.screens.count > 1, let target, !stayPut, AXIsProcessTrusted() else { return }
        generation += 1
        let watch = Watch(
            generation: generation, target: target, expected: expectedBundleID,
            beforePID: before?.pid, beforeWindow: before?.window,
            deadline: Date().addingTimeInterval(expectedBundleID == nil ? 3 : 8)
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.poll(watch) }
    }

    // MARK: - Following the opened window

    private struct Watch {
        let generation: Int
        let target: NSRect
        let expected: String?
        let beforePID: pid_t?
        let beforeWindow: AXUIElement?
        let deadline: Date
    }

    private func poll(_ watch: Watch) {
        guard watch.generation == generation, Date() < watch.deadline else { return }
        let again = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self?.poll(watch) }
        }
        guard let front = Self.frontWindow(),
              front.pid != ProcessInfo.processInfo.processIdentifier else { return again() }
        let changed = front.pid != watch.beforePID
            || watch.beforeWindow.map { !CFEqual($0, front.window) } ?? true
        let isExpected = watch.expected != nil && front.bundleID == watch.expected
        if watch.expected != nil ? !isExpected : !changed { return again() }

        guard !Self.isFullScreen(front.window), let frame = Self.frame(of: front.window) else { return }
        if Self.needsMove(frame, target: watch.target) {
            let from = Self.screenFrame(containing: frame)
            Self.setFrame(Self.relocate(frame, from: from, to: watch.target), of: front.window)
        }
        // Some apps restore their saved window position a moment after showing
        // the window, so check once more and pull it back if it jumped.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, watch.generation == self.generation,
                  let frame = Self.frame(of: front.window),
                  Self.needsMove(frame, target: watch.target) else { return }
            let from = Self.screenFrame(containing: frame)
            Self.setFrame(Self.relocate(frame, from: from, to: watch.target), of: front.window)
        }
    }

    // MARK: - Geometry

    static func index(of point: NSPoint, in screens: [NSRect]) -> Int {
        if let hit = screens.firstIndex(where: { $0.contains(point) }) { return hit }
        func distance(_ rect: NSRect) -> CGFloat {
            let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
            let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
            return dx * dx + dy * dy
        }
        return screens.indices.min { distance(screens[$0]) < distance(screens[$1]) } ?? 0
    }

    // A window counts as already there when at least half of it is on the target.
    static func needsMove(_ window: NSRect, target: NSRect) -> Bool {
        let overlap = window.intersection(target)
        let area = window.width * window.height
        guard area > 0 else { return false }
        return overlap.isNull || overlap.width * overlap.height < area / 2
    }

    // Keeps the window's size (shrunk to fit) and its relative spot on screen.
    static func relocate(_ window: NSRect, from: NSRect, to: NSRect) -> NSRect {
        let width = min(window.width, to.width)
        let height = min(window.height, to.height)
        let relX = from.width > 0 ? (window.midX - from.minX) / from.width : 0.5
        let relY = from.height > 0 ? (window.midY - from.minY) / from.height : 0.5
        let x = min(max(to.minX + relX * to.width - width / 2, to.minX), to.maxX - width)
        let y = min(max(to.minY + relY * to.height - height / 2, to.minY), to.maxY - height)
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private static func screenFrame(containing window: NSRect) -> NSRect {
        let frames = NSScreen.screens.map(\.visibleFrame)
        return frames.max {
            let a = $0.intersection(window), b = $1.intersection(window)
            return (a.isNull ? 0 : a.width * a.height) < (b.isNull ? 0 : b.width * b.height)
        } ?? window
    }

    // MARK: - Accessibility

    private struct FrontWindow {
        let pid: pid_t
        let bundleID: String?
        let window: AXUIElement
    }

    private static func frontWindow() -> FrontWindow? {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(axApp, 0.5)
        for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            var ref: CFTypeRef?
            if AXUIElementCopyAttributeValue(axApp, attribute as CFString, &ref) == .success,
               let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() {
                return FrontWindow(
                    pid: app.processIdentifier, bundleID: app.bundleIdentifier,
                    window: ref as! AXUIElement
                )
            }
        }
        return nil
    }

    private static func isFullScreen(_ window: AXUIElement) -> Bool {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &ref)
        return (ref as? Bool) ?? false
    }

    // Accessibility uses a top-left origin on the primary screen; these
    // helpers speak Cocoa's bottom-left coordinates.
    private static func frame(of window: AXUIElement) -> NSRect? {
        var posRef: CFTypeRef?, sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posRef, let sizeRef,
              CFGetTypeID(posRef) == AXValueGetTypeID(), CFGetTypeID(sizeRef) == AXValueGetTypeID()
        else { return nil }
        var position = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        guard let primary = NSScreen.screens.first?.frame else { return nil }
        return NSRect(x: position.x, y: primary.maxY - position.y - size.height, width: size.width, height: size.height)
    }

    private static func setFrame(_ frame: NSRect, of window: AXUIElement) {
        guard let primary = NSScreen.screens.first?.frame else { return }
        var position = CGPoint(x: frame.minX, y: primary.maxY - frame.maxY)
        var size = CGSize(width: frame.width, height: frame.height)
        // Position first so the size is clamped by the new screen, then size,
        // then position again for apps that refuse a size off their old screen.
        if let value = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
        if let value = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
    }
}
