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

    // Scripts run through osascript rather than in-process NSAppleScript:
    // NSAppleScript is not safe off the main thread and cannot be stopped,
    // while a child process can be timed out. The timeout is generous because
    // the first run waits on the Automation consent prompt.
    //
    // With a failureTitle, a script that fails or hangs tells the user why;
    // without one the caller handles failure through the completion.
    static func runAppleScript(
        _ source: String, failureTitle: String? = nil, timeout: TimeInterval = 30,
        completion: (@Sendable (Bool) -> Void)? = nil
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Shell.runStatus("/usr/bin/osascript", ["-e", source], timeout: timeout)
            let ok = result.status == 0
            if !ok {
                NSLog("Spidey AppleScript failed (\(result.status.map(String.init) ?? "timed out")): \(result.error)")
                if let failureTitle {
                    tellUser(
                        title: failureTitle,
                        body: scriptFailureText(result.status == nil ? nil : result.error, app: scriptTarget(source))
                    )
                }
            }
            completion?(ok)
        }
    }

    // The app a one-line `tell application "X" ...` script talks to.
    static func scriptTarget(_ source: String) -> String? {
        guard let start = source.range(of: "tell application \"") else { return nil }
        let rest = source[start.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<end])
    }

    // A plain explanation of an osascript failure. A nil error means the
    // script was stopped for taking too long.
    static func scriptFailureText(_ error: String?, app: String?) -> String {
        let name = app ?? "the app"
        guard let error else {
            return "\(name) did not answer in time, so nothing changed."
        }
        if let message = ownScriptMessage(error) { return message }
        if error.contains("-1743") || error.lowercased().contains("not authorized") {
            return "macOS blocked Spidey from controlling \(name). Allow it in System Settings > "
                + "Privacy & Security > Automation, then try again."
        }
        if error.contains("-600") || error.lowercased().contains("isn't running")
            || error.contains("isn\u{2019}t running") {
            return "\(name) is not running, so there was nothing to control."
        }
        return "\(name) reported an error, so nothing changed."
    }

    // Spidey's own scripts raise this error number with a sentence meant for
    // the user, which osascript prints as "execution error: <sentence> (7401)".
    static let messageErrorNumber = 7401

    private static func ownScriptMessage(_ error: String) -> String? {
        let suffix = " (\(messageErrorNumber))"
        guard let marker = error.range(of: "execution error: "),
              let end = error.range(of: suffix, options: .backwards),
              marker.upperBound <= end.lowerBound else { return nil }
        var message = error[marker.upperBound..<end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        // Raised inside a tell block, it can come back as "<App> got an error: <sentence>".
        if let prefix = message.range(of: "got an error: ") {
            message = String(message[prefix.upperBound...])
        }
        return message.isEmpty ? nil : message
    }

    // CGSession no longer exists on current macOS; Control-Command-Q is the
    // system's own lock shortcut.
    static let lockScreenScript =
        "tell application \"System Events\" to keystroke \"q\" using {command down, control down}"

    // Long enough for a first-time Automation prompt to be read and answered;
    // a short limit killed the script while the dialog was still up.
    static let lockScreenTimeout: TimeInterval = 60

    static func lockScreen() {
        runAppleScript(lockScreenScript, timeout: lockScreenTimeout) { ok in
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
