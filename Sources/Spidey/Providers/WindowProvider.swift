import AppKit
import ApplicationServices

// "left half", "maximize", "center": snaps the frontmost window using the
// Accessibility API. Needs the one-time Accessibility permission.
enum WindowProvider {
    struct Snap {
        let names: [String]
        let title: String
        let symbol: String
        // Target frame given the screen's visible frame and the window's current size.
        let frame: (NSRect, NSSize) -> NSRect
    }

    static let snaps: [Snap] = [
        Snap(names: ["left half", "left"], title: "Left Half", symbol: "rectangle.lefthalf.filled") { screen, _ in
            NSRect(x: screen.minX, y: screen.minY, width: screen.width / 2, height: screen.height)
        },
        Snap(names: ["right half", "right"], title: "Right Half", symbol: "rectangle.righthalf.filled") { screen, _ in
            NSRect(x: screen.midX, y: screen.minY, width: screen.width / 2, height: screen.height)
        },
        Snap(names: ["top half", "top"], title: "Top Half", symbol: "rectangle.tophalf.filled") { screen, _ in
            NSRect(x: screen.minX, y: screen.midY, width: screen.width, height: screen.height / 2)
        },
        Snap(names: ["bottom half", "bottom"], title: "Bottom Half", symbol: "rectangle.bottomhalf.filled") { screen, _ in
            NSRect(x: screen.minX, y: screen.minY, width: screen.width, height: screen.height / 2)
        },
        Snap(names: ["top left"], title: "Top Left Quarter", symbol: "rectangle.inset.topleft.filled") { screen, _ in
            NSRect(x: screen.minX, y: screen.midY, width: screen.width / 2, height: screen.height / 2)
        },
        Snap(names: ["top right"], title: "Top Right Quarter", symbol: "rectangle.inset.topright.filled") { screen, _ in
            NSRect(x: screen.midX, y: screen.midY, width: screen.width / 2, height: screen.height / 2)
        },
        Snap(names: ["bottom left"], title: "Bottom Left Quarter", symbol: "rectangle.inset.bottomleft.filled") { screen, _ in
            NSRect(x: screen.minX, y: screen.minY, width: screen.width / 2, height: screen.height / 2)
        },
        Snap(names: ["bottom right"], title: "Bottom Right Quarter", symbol: "rectangle.inset.bottomright.filled") { screen, _ in
            NSRect(x: screen.midX, y: screen.minY, width: screen.width / 2, height: screen.height / 2)
        },
        Snap(names: ["maximize", "maximise", "max", "full screen", "fullscreen"], title: "Maximize", symbol: "rectangle.fill") { screen, _ in
            screen
        },
        Snap(names: ["center", "centre", "center window"], title: "Center", symbol: "rectangle.center.inset.filled") { screen, size in
            NSRect(
                x: screen.midX - size.width / 2,
                y: screen.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
        },
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
                items.append(ResultItem(
                    title: snap.title,
                    subtitle: "Moves the front \(appName) window",
                    icon: .symbol(snap.symbol),
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
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var windowRef: CFTypeRef?
        AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef)
        if windowRef == nil {
            var windowsRef: CFTypeRef?
            AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)
            windowRef = (windowsRef as? [AXUIElement])?.first
        }
        guard let window = windowRef, CFGetTypeID(window as CFTypeRef) == AXUIElementGetTypeID() else { return }
        let axWindow = window as! AXUIElement

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let target = snap.frame(screen.visibleFrame, currentSize(of: axWindow))

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
