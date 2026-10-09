import AppKit
import UserNotifications

enum SystemProvider {
    struct Command {
        let names: [String]
        let title: String
        let subtitle: String
        let symbol: String
        let destructive: Bool
        let run: () -> Void
    }

    static let commands: [Command] = [
        Command(
            names: ["sleep"], title: "Sleep",
            subtitle: "Put the Mac to sleep, saving any episode you are watching",
            symbol: "moon.zzz.fill", destructive: false,
            // Stopping for the night is when the episode is worth
            // remembering, so the browser is read before the Mac goes down.
            // The short timeout keeps a slow read from delaying sleep.
            run: {
                WatchCapture.captureNow(timeout: 4) {
                    runAppleScript("tell application \"System Events\" to sleep")
                }
            }
        ),
        Command(
            names: ["lock", "lock screen"], title: "Lock Screen", subtitle: "Lock this Mac",
            symbol: "lock.fill", destructive: false,
            run: { lockScreen() }
        ),
        Command(
            names: ["screensaver", "screen saver"], title: "Screen Saver", subtitle: "Start the screen saver",
            symbol: "sparkles.tv", destructive: false,
            run: {
                let url = URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app")
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }
        ),
        Command(
            names: ["restart"], title: "Restart", subtitle: "Restart this Mac",
            symbol: "arrow.clockwise.circle.fill", destructive: true,
            run: { runAppleScript("tell application \"System Events\" to restart") }
        ),
        Command(
            names: ["shutdown", "shut down"], title: "Shut Down", subtitle: "Shut down this Mac",
            symbol: "power.circle.fill", destructive: true,
            run: { runAppleScript("tell application \"System Events\" to shut down") }
        ),
        Command(
            names: ["logout", "log out"], title: "Log Out", subtitle: "Log out of this Mac",
            symbol: "rectangle.portrait.and.arrow.right", destructive: true,
            run: { runAppleScript("tell application \"System Events\" to log out") }
        ),
        Command(
            names: ["empty trash", "trash"], title: "Empty Trash", subtitle: "Empty the Finder trash",
            symbol: "trash.fill", destructive: true,
            run: { runAppleScript("tell application \"Finder\" to empty trash") }
        ),
        Command(
            names: ["eject"], title: "Eject All", subtitle: "Eject all ejectable disks",
            symbol: "eject.fill", destructive: false,
            run: { runAppleScript("tell application \"Finder\" to eject (every disk whose ejectable is true)") }
        ),
    ]

    // Commands needing a second Return press before running (restart, shut down, empty trash, log out).
    static func results(for query: String, armedCommand: String?, arm: @escaping (String) -> Void) -> [ResultItem] {
        var items: [ResultItem] = []
        for command in commands {
            let best = command.names.compactMap { Fuzzy.score(query: query, candidate: $0) }.max()
            guard let match = best, match >= 0.65 else { continue }
            let armed = armedCommand == command.title
            let title = armed ? "\(command.title): press Return again to confirm" : command.title
            let subtitle = command.destructive && !armed
                ? command.subtitle + " (asks to confirm)"
                : command.subtitle
            items.append(ResultItem(
                title: title,
                subtitle: subtitle,
                icon: .symbol(command.symbol),
                score: 850 + match * 60,
                action: {
                    if command.destructive && !armed {
                        arm(command.title)
                    } else {
                        command.run()
                    }
                }
            ))
        }
        return items
    }

    // NSAppleScript is not safe to run on two threads at once, so every
    // script goes through one serial queue instead of the shared global one.
    private static let scriptQueue = DispatchQueue(label: "dev.opensource.spidey.applescript", qos: .userInitiated)

    static func runAppleScript(_ source: String, completion: (@Sendable (Bool) -> Void)? = nil) {
        scriptQueue.async {
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            if let error {
                NSLog("Spidey AppleScript error: \(error)")
            }
            completion?(error == nil)
        }
    }

    // CGSession no longer exists on current macOS; Control-Command-Q is the
    // system's own lock shortcut.
    static let lockScreenScript =
        "tell application \"System Events\" to keystroke \"q\" using {command down, control down}"

    static func lockScreen() {
        runAppleScript(lockScreenScript) { ok in
            guard !ok else { return }
            // Without the Automation grant, at least turn the display off.
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["displaysleepnow"]
            try? process.run()
        }
    }

    // Tells the user an automation did not work: a notification when they
    // are allowed, otherwise an alert, so a failure is never silent. Safe to
    // call from any thread.
    static func tellUser(title: String, body: String) {
        DispatchQueue.main.async {
            NSSound(named: "Funk")?.play()
            // Notifications need a real app bundle; running bare from .build
            // during development falls straight through to the alert.
            guard Bundle.main.bundleIdentifier != nil else {
                showAlert(title: title, body: body)
                return
            }
            let center = UNUserNotificationCenter.current()
            center.getNotificationSettings { settings in
                let allowed = settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
                guard allowed else {
                    DispatchQueue.main.async { showAlert(title: title, body: body) }
                    return
                }
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
            }
        }
    }

    private static func showAlert(title: String, body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
