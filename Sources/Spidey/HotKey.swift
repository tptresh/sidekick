import Carbon.HIToolbox
import AppKit

// Thin wrapper around the Carbon hot key API. No accessibility permission needed.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var hotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?
    private var eventHandlerInstalled = false

    private init() {}

    @discardableResult
    func register(_ combo: HotKeyCombo, handler: @escaping () -> Void) -> Bool {
        unregister()
        installEventHandlerIfNeeded()
        self.handler = handler
        let hotKeyID = EventHotKeyID(signature: OSType(0x53504459), id: 1) // "SPDY"
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode, combo.carbonModifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else { return false }
        hotKeyRef = ref
        return true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    fileprivate func fire() {
        handler?()
    }

    private func installEventHandlerIfNeeded() {
        guard !eventHandlerInstalled else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ -> OSStatus in
                HotKeyCenter.shared.fire()
                return noErr
            },
            1, &eventType, nil, nil
        )
        eventHandlerInstalled = true
    }
}
