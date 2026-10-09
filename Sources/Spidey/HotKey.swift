import Carbon.HIToolbox
import AppKit

// Thin wrapper around the Carbon hot key API. No accessibility permission needed.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var hotKeyRef: EventHotKeyRef?
    private(set) var currentCombo: HotKeyCombo?
    private var handler: (() -> Void)?
    private var eventHandlerInstalled = false

    private init() {}

    @discardableResult
    func register(_ combo: HotKeyCombo, handler: @escaping () -> Void) -> Bool {
        installEventHandlerIfNeeded()
        if combo == currentCombo, hotKeyRef != nil {
            self.handler = handler
            return true
        }
        // The old combo is only released once the new one is secured, so a
        // taken combo picked in Preferences leaves the working one in place.
        let hotKeyID = EventHotKeyID(signature: OSType(0x53504459), id: 1) // "SPDY"
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode, combo.carbonModifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else { return false }
        unregister()
        hotKeyRef = ref
        currentCombo = combo
        self.handler = handler
        return true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        currentCombo = nil
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

// Which combo ends up registered, and whether the saved preference changes.
enum HotKeyFallback {
    struct Outcome: Equatable {
        var active: HotKeyCombo?
        var savePreferred: HotKeyCombo?
    }

    static func resolve(
        preferred: HotKeyCombo, userPicked: Bool, current: HotKeyCombo?,
        register: (HotKeyCombo) -> Bool
    ) -> Outcome {
        if register(preferred) { return Outcome(active: preferred, savePreferred: nil) }
        // A combo that was already working stays rather than being swapped out.
        if let current {
            // Only a combo just picked in Preferences is saved back over: a
            // retry at launch or on reopening must keep the user's choice, so
            // freeing Cmd+Space in System Settings later still takes effect.
            let revert = userPicked && preferred != current
            return Outcome(active: current, savePreferred: revert ? current : nil)
        }
        if preferred != .optionSpace, register(.optionSpace) {
            return Outcome(active: .optionSpace, savePreferred: nil)
        }
        return Outcome(active: nil, savePreferred: nil)
    }
}
