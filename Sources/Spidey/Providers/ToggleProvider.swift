import AppKit

// Quick toggles: dark mode, Wi-Fi, Bluetooth, and caffeinate (keep the Mac awake).
// A query can name the state it wants ("wifi off", "dark mode on") or just the
// subject ("wifi"), which flips whatever it is now.
enum ToggleProvider {
    // What the query asked for, once a trailing on/off is peeled away.
    enum Intent {
        case flip, on, off

        func desired(current: Bool) -> Bool {
            switch self {
            case .flip: return !current
            case .on: return true
            case .off: return false
            }
        }

        // "wifi off" -> (.off, "wifi"); "wifi" -> (.flip, "wifi").
        static func split(_ query: String) -> (intent: Intent, subject: String) {
            if query.hasSuffix(" off") {
                return (.off, String(query.dropLast(" off".count)))
            }
            if query.hasSuffix(" on") {
                return (.on, String(query.dropLast(" on".count)))
            }
            return (.flip, query)
        }
    }

    // A half-typed word ("app", "dar") still offers the toggle, but below an
    // app whose name starts the same way (App Store scores about 876).
    static func score(exact: Bool) -> Double {
        exact ? 950 : 860
    }

    static func results(for query: String) -> [ResultItem] {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard lowered.count >= 3 else { return [] }
        let (intent, subject) = Intent.split(lowered)
        guard !subject.isEmpty else { return [] }
        var items: [ResultItem] = []
        var exactMatch = false

        func matches(_ names: [String], threshold: Double = 0.7) -> Bool {
            let best = names.compactMap { Fuzzy.score(query: subject, candidate: $0) }.max() ?? 0
            exactMatch = best >= 1.0
            return best >= threshold
        }

        // Each add follows its own matches() call, so exactMatch is current.
        func add(_ item: ResultItem) {
            var item = item
            item.score = score(exact: exactMatch)
            items.append(item)
        }

        if matches(["dark mode", "light mode", "appearance", "dark", "theme system"]) {
            let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
                || Shell.run("/usr/bin/defaults", ["read", "-g", "AppleInterfaceStyle"]).contains("Dark")
            add(row(
                intent: intent, current: isDark,
                onTitle: "Switch to Dark Mode", offTitle: "Switch to Light Mode",
                settledTitle: isDark ? "Already in Dark Mode" : "Already in Light Mode",
                subtitle: "Toggles the system appearance",
                symbol: isDark ? "sun.max.fill" : "moon.fill",
                apply: { _ in
                    SystemProvider.runAppleScript(
                        "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
                    ) { ok in
                        guard !ok else { return }
                        SystemProvider.tellUser(
                            title: "Could not switch appearance",
                            body: "macOS blocked Spidey from asking System Events. Allow it in System Settings > "
                                + "Privacy & Security > Automation, then try again."
                        )
                    }
                }
            ))
        }

        if matches(["wifi", "wi-fi", "wireless"]) {
            if let device = WifiControl.device {
                let isOn = WifiControl.isOn(device: device)
                add(row(
                    intent: intent, current: isOn,
                    onTitle: "Turn Wi-Fi On", offTitle: "Turn Wi-Fi Off",
                    settledTitle: "Wi-Fi is already \(isOn ? "on" : "off")",
                    subtitle: "Wi-Fi is currently \(isOn ? "on" : "off") (\(device))",
                    symbol: isOn ? "wifi.slash" : "wifi",
                    apply: { on in
                        // networksetup can take seconds; never on the main thread.
                        DispatchQueue.global(qos: .userInitiated).async {
                            WifiControl.setPower(on, device: device)
                            if WifiControl.isOn(device: device) != on {
                                SystemProvider.tellUser(
                                    title: "Wi-Fi did not turn \(on ? "on" : "off")",
                                    body: "macOS did not accept the change. Try the Wi-Fi menu in the menu bar."
                                )
                            }
                        }
                    }
                ))
            }
        }

        if matches(["bluetooth"]) {
            if let blueutil = Bluetooth.blueutilPath {
                let isOn = Shell.run(blueutil, ["-p"]).trimmingCharacters(in: .whitespacesAndNewlines) == "1"
                add(row(
                    intent: intent, current: isOn,
                    onTitle: "Turn Bluetooth On", offTitle: "Turn Bluetooth Off",
                    settledTitle: "Bluetooth is already \(isOn ? "on" : "off")",
                    subtitle: "Bluetooth is currently \(isOn ? "on" : "off")",
                    symbol: "wave.3.right",
                    apply: { on in
                        DispatchQueue.global(qos: .userInitiated).async {
                            Shell.run(blueutil, ["-p", on ? "1" : "0"])
                            let now = Shell.run(blueutil, ["-p"]).trimmingCharacters(in: .whitespacesAndNewlines)
                            if now != (on ? "1" : "0") {
                                SystemProvider.tellUser(
                                    title: "Bluetooth did not turn \(on ? "on" : "off")",
                                    body: "blueutil could not change it, which usually means Spidey needs "
                                        + "Bluetooth permission in System Settings > Privacy & Security > Bluetooth."
                                )
                            }
                        }
                    }
                ))
            } else {
                add(ResultItem(
                    title: "Open Bluetooth Settings",
                    subtitle: SetupCenter.shared.missingToolHint("blueutil"),
                    icon: .symbol("wave.3.right"),
                    score: 950,
                    action: {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                ))
            }
        }

        if matches(["caffeinate", "keep awake", "awake", "coffee", "no sleep"]) {
            let active = CaffeinateManager.shared.isActive
            add(row(
                intent: intent, current: active,
                onTitle: "Keep Mac Awake", offTitle: "Stop Keeping Mac Awake",
                settledTitle: active ? "Mac is already staying awake" : "Mac already sleeps normally",
                subtitle: active
                    ? "Caffeinate is running, sleep works normally again after this"
                    : "Stops the Mac and display from sleeping until turned off",
                symbol: active ? "cup.and.saucer" : "cup.and.saucer.fill",
                apply: { _ in CaffeinateManager.shared.toggle() }
            ))
        }

        return items
    }

    // One row per toggle: the action row when the state has to change, and an
    // "already off" confirmation when the query asked for the state it is in.
    private static func row(
        intent: Intent,
        current: Bool,
        onTitle: String,
        offTitle: String,
        settledTitle: String,
        subtitle: String,
        symbol: String,
        apply: @escaping (Bool) -> Void
    ) -> ResultItem {
        let desired = intent.desired(current: current)
        guard desired != current else {
            return ResultItem(
                title: settledTitle,
                subtitle: "Nothing to change",
                icon: .symbol(symbol),
                score: 950,
                action: {}
            )
        }
        return ResultItem(
            title: desired ? onTitle : offTitle,
            subtitle: subtitle,
            icon: .symbol(symbol),
            score: 950,
            action: { apply(desired) }
        )
    }
}

// Runs a short command line tool and returns its stdout, or "" on failure or
// timeout. stderr goes to the null device (an undrained Pipe would wedge the
// child once it writes 64KB), and a hung binary is terminated - then killed  - 
// instead of blocking the caller forever.
enum Shell {
    @discardableResult
    static func run(_ path: String, _ arguments: [String], timeout: TimeInterval = 5) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return "" }

        let lock = NSLock()
        var output = Data()
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            // Draining stdout to EOF also unblocks a child stuck writing.
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            lock.lock()
            output = data
            lock.unlock()
            process.waitUntilExit()
            done.signal()
        }
        if done.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if done.wait(timeout: .now() + 1) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
            }
            return ""
        }
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: output, as: UTF8.self)
    }
}

enum WifiControl {
    // The Wi-Fi hardware device (usually en0), found once and cached.
    static let device: String? = {
        let output = Shell.run("/usr/sbin/networksetup", ["-listallhardwareports"])
        var lastPortWasWifi = false
        for line in output.split(separator: "\n") {
            if line.hasPrefix("Hardware Port:") {
                lastPortWasWifi = line.contains("Wi-Fi") || line.contains("AirPort")
            } else if lastPortWasWifi, line.hasPrefix("Device:") {
                return line.replacingOccurrences(of: "Device:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }()

    static func isOn(device: String) -> Bool {
        Shell.run("/usr/sbin/networksetup", ["-getairportpower", device]).contains(": On")
    }

    static func setPower(_ on: Bool, device: String) {
        Shell.run("/usr/sbin/networksetup", ["-setairportpower", device, on ? "on" : "off"])
    }
}

enum Bluetooth {
    // Looked up per query, not cached: SetupCenter may install blueutil in
    // the background after launch.
    static var blueutilPath: String? { SetupCenter.binaryPath(for: "blueutil") }
}

// Keeps a caffeinate child process alive while "keep awake" is on.
final class CaffeinateManager: ObservableObject {
    static let shared = CaffeinateManager()

    private var process: Process?

    // Published so the menu bar can show that the Mac is being kept awake.
    @Published private(set) var isActive = false

    func toggle() {
        if isActive {
            stop()
        } else {
            let caffeinate = Process()
            caffeinate.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
            caffeinate.arguments = ["-di"]
            caffeinate.terminationHandler = { [weak self] ended in
                DispatchQueue.main.async {
                    guard let self, self.process === ended else { return }
                    self.process = nil
                    self.isActive = false
                }
            }
            guard (try? caffeinate.run()) != nil else {
                SystemProvider.tellUser(title: "Could not keep the Mac awake", body: "The caffeinate tool would not start.")
                return
            }
            process = caffeinate
            isActive = true
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        isActive = false
    }
}
