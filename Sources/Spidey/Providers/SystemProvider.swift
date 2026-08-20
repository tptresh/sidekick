import AppKit

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
            names: ["sleep"], title: "Sleep", subtitle: "Put the Mac to sleep",
            symbol: "moon.zzz.fill", destructive: false,
            run: { runAppleScript("tell application \"System Events\" to sleep") }
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

    static func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            if let error {
                NSLog("Spidey AppleScript error: \(error)")
            }
        }
    }

    static func lockScreen() {
        // CGSession -suspend is the real lock; fall back to display sleep.
        let cgSession = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
        if FileManager.default.isExecutableFile(atPath: cgSession) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cgSession)
            process.arguments = ["-suspend"]
            try? process.run()
        } else {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["displaysleepnow"]
            try? process.run()
        }
    }
}
