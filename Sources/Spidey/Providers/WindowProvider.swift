import AppKit
import ApplicationServices

// "left half", "maximize", "full screen", "center": snaps the frontmost window
// using the Accessibility API. Needs the one-time Accessibility permission.
enum WindowProvider {
    struct Snap {
        let names: [String]
        let title: String
        let symbol: String
        var subtitle: String?
        let action: Action

        enum Action {
            // Target frame given the screen's visible frame and the window's current size.
            case frame((NSRect, NSSize) -> NSRect)
            // Real macOS full screen (its own Space), not a screen-sized window.
            case fullScreen
        }
    }

    static let snaps: [Snap] = [
        Snap(names: ["left half", "left"], title: "Left Half", symbol: "rectangle.lefthalf.filled", action: .frame { screen, _ in
            NSRect(x: screen.minX, y: screen.minY, width: screen.width / 2, height: screen.height)
        }),
        Snap(names: ["right half", "right"], title: "Right Half", symbol: "rectangle.righthalf.filled", action: .frame { screen, _ in
            NSRect(x: screen.midX, y: screen.minY, width: screen.width / 2, height: screen.height)
        }),
        Snap(names: ["top half", "top"], title: "Top Half", symbol: "rectangle.tophalf.filled", action: .frame { screen, _ in
            NSRect(x: screen.minX, y: screen.midY, width: screen.width, height: screen.height / 2)
        }),
        Snap(names: ["bottom half", "bottom"], title: "Bottom Half", symbol: "rectangle.bottomhalf.filled", action: .frame { screen, _ in
            NSRect(x: screen.minX, y: screen.minY, width: screen.width, height: screen.height / 2)
        }),
        Snap(names: ["top left"], title: "Top Left Quarter", symbol: "rectangle.inset.topleft.filled", action: .frame { screen, _ in
            NSRect(x: screen.minX, y: screen.midY, width: screen.width / 2, height: screen.height / 2)
        }),
        Snap(names: ["top right"], title: "Top Right Quarter", symbol: "rectangle.inset.topright.filled", action: .frame { screen, _ in
            NSRect(x: screen.midX, y: screen.midY, width: screen.width / 2, height: screen.height / 2)
        }),
        Snap(names: ["bottom left"], title: "Bottom Left Quarter", symbol: "rectangle.inset.bottomleft.filled", action: .frame { screen, _ in
            NSRect(x: screen.minX, y: screen.minY, width: screen.width / 2, height: screen.height / 2)
        }),
        Snap(names: ["bottom right"], title: "Bottom Right Quarter", symbol: "rectangle.inset.bottomright.filled", action: .frame { screen, _ in
            NSRect(x: screen.midX, y: screen.minY, width: screen.width / 2, height: screen.height / 2)
        }),
        Snap(
            names: ["full screen", "fullscreen", "exit full screen"],
            title: "Full Screen",
            symbol: "arrow.up.left.and.arrow.down.right",
            action: .fullScreen
        ),
        Snap(
            names: ["maximize", "maximise", "max", "fill screen"],
            title: "Maximize",
            symbol: "rectangle.fill",
            subtitle: "Fills the screen without entering full screen",
            action: .frame { screen, _ in screen }
        ),
        Snap(names: ["center", "centre", "center window"], title: "Center", symbol: "rectangle.center.inset.filled", action: .frame { screen, size in
            NSRect(
                x: screen.midX - size.width / 2,
                y: screen.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
        }),
    ]

    static func results(for query: String) -> [ResultItem] {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard lowered.count >= 3 else { return [] }
        var items: [ResultItem] = []
        for snap in snaps {
            let best = snap.names.compactMap { Fuzzy.score(query: lowered, candidate: $0) }.max()
            guard let match = best, match >= 0.8 else { continue }
            let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "the front window"
            if AXIsProcessTrusted() {
                var title = snap.title
                var symbol = snap.symbol
                var subtitle = snap.subtitle ?? "Moves the front \(appName) window"
                // The full screen row doubles as the way back out, so it has
                // to say which way it will go.
                if case .fullScreen = snap.action {
                    let isFull = frontWindowIsFullScreen()
                    title = isFull ? "Exit Full Screen" : "Full Screen"
                    symbol = isFull ? "arrow.down.right.and.arrow.up.left" : snap.symbol
                    subtitle = isFull
                        ? "Takes \(appName) back out of full screen"
                        : "Puts the front \(appName) window into full screen"
                }
                items.append(ResultItem(
                    title: title,
                    subtitle: subtitle,
                    icon: .symbol(symbol),
                    score: 900 + match * 60,
                    action: { apply(snap) }
                ))
            } else {
                items.append(ResultItem(
                    title: "\(snap.title): needs Accessibility access",
                    subtitle: "Return opens the permission prompt, then try again",
                    icon: .symbol("lock.shield"),
                    score: 900 + match * 60,
                    action: { requestPermission() }
                ))
            }
        }
        return items
    }

    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func apply(_ snap: Snap) {
        guard let axWindow = frontWindow() else { return }
        switch snap.action {
        case .fullScreen:
            setFullScreen(axWindow, to: !isFullScreen(axWindow))
        case .frame(let target):
            guard isFullScreen(axWindow) else {
                move(axWindow, using: target)
                return
            }
            // A full screen window ignores position and size, so leave full
            // screen first and snap once the Space has slid away.
            setFullScreen(axWindow, to: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                move(axWindow, using: target)
            }
        }
    }

    // MARK: - Accessibility

    // Raw attribute names: the SDK exposes no Swift constants for these.
    private static let fullScreenAttribute = "AXFullScreen" as CFString
    private static let fullScreenButtonAttribute = "AXFullScreenButton" as CFString
    private static let zoomButtonAttribute = "AXZoomButton" as CFString

    // messagingTimeout keeps the typing path responsive when the front app is
    // busy; the action path can afford to wait for the default.
    private static func frontWindow(messagingTimeout: Float? = nil) -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        if let messagingTimeout {
            AXUIElementSetMessagingTimeout(axApp, messagingTimeout)
        }

        var windowRef: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef)
        if windowRef == nil {
            var windowsRef: CFTypeRef?
            AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)
            windowRef = (windowsRef as? [AXUIElement])?.first
        }
        guard let window = windowRef, CFGetTypeID(window as CFTypeRef) == AXUIElementGetTypeID() else { return nil }
        return (window as! AXUIElement)
    }

    private static func frontWindowIsFullScreen() -> Bool {
        guard let window = frontWindow(messagingTimeout: 0.2) else { return false }
        return isFullScreen(window)
    }

    private static func isFullScreen(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, fullScreenAttribute, &value) == .success,
              let value, CFGetTypeID(value) == CFBooleanGetTypeID() else { return false }
        return CFBooleanGetValue((value as! CFBoolean))
    }

    private static func setFullScreen(_ window: AXUIElement, to on: Bool) {
        let flag: CFBoolean = on ? kCFBooleanTrue : kCFBooleanFalse
        if AXUIElementSetAttributeValue(window, fullScreenAttribute, flag) == .success { return }
        // Apps that never publish AXFullScreen still answer their green button,
        // which enters and leaves full screen the same way a click would.
        for button in [fullScreenButtonAttribute, zoomButtonAttribute] {
            var ref: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, button, &ref) == .success,
                  let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() else { continue }
            if AXUIElementPerformAction((ref as! AXUIElement), kAXPressAction as CFString) == .success { return }
        }
    }

    private static func move(_ axWindow: AXUIElement, using target: (NSRect, NSSize) -> NSRect) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let target = target(screen.visibleFrame, currentSize(of: axWindow))

        // Accessibility coordinates use a top-left origin on the primary screen.
        let primary = NSScreen.screens[0].frame
        var position = CGPoint(x: target.minX, y: primary.maxY - target.maxY)
        var size = CGSize(width: target.width, height: target.height)

        // Size, then position, then size again: some apps clamp one until the other changes.
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
        }
        if let positionValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, positionValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    private static func currentSize(of window: AXUIElement) -> NSSize {
        var sizeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)
        var size = CGSize(width: 800, height: 600)
        if let sizeRef, CFGetTypeID(sizeRef) == AXValueGetTypeID() {
            AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        }
        return size
    }
}
