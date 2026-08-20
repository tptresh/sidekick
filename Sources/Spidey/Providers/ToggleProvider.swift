import AppKit

// Quick toggles: dark mode, Wi-Fi, Bluetooth, and caffeinate (keep the Mac awake).
enum ToggleProvider {
    static func results(for query: String) -> [ResultItem] {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard lowered.count >= 3 else { return [] }
        var items: [ResultItem] = []

        func matches(_ names: [String], threshold: Double = 0.7) -> Bool {
            names.contains { candidate in
                (Fuzzy.score(query: lowered, candidate: candidate) ?? 0) >= threshold
            }
        }

        if matches(["dark mode", "light mode", "appearance", "dark", "theme system"]) {
            let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
                || Shell.run("/usr/bin/defaults", ["read", "-g", "AppleInterfaceStyle"]).contains("Dark")
            items.append(ResultItem(
                title: isDark ? "Switch to Light Mode" : "Switch to Dark Mode",
                subtitle: "Toggles the system appearance",
                icon: .symbol(isDark ? "sun.max.fill" : "moon.fill"),
                score: 950,
                action: {
                    SystemProvider.runAppleScript(
                        "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
                    )
                }
            ))
        }

        if matches(["wifi", "wi-fi", "wireless"]) {
            if let device = WifiControl.device {
                let isOn = WifiControl.isOn(device: device)
                items.append(ResultItem(
                    title: isOn ? "Turn Wi-Fi Off" : "Turn Wi-Fi On",
                    subtitle: "Wi-Fi is currently \(isOn ? "on" : "off") (\(device))",
                    icon: .symbol(isOn ? "wifi.slash" : "wifi"),
                    score: 950,
                    action: { WifiControl.setPower(!isOn, device: device) }
                ))
            }
        }

        if matches(["bluetooth"]) {
            if let blueutil = Bluetooth.blueutilPath {
                let isOn = Shell.run(blueutil, ["-p"]).trimmingCharacters(in: .whitespacesAndNewlines) == "1"
                items.append(ResultItem(
                    title: isOn ? "Turn Bluetooth Off" : "Turn Bluetooth On",
                    subtitle: "Bluetooth is currently \(isOn ? "on" : "off")",
                    icon: .symbol("wave.3.right"),
                    score: 950,
                    action: { _ = Shell.run(blueutil, ["-p", isOn ? "0" : "1"]) }
                ))
            } else {
                items.append(ResultItem(
                    title: "Open Bluetooth Settings",
                    subtitle: "Toggling directly needs blueutil (brew install blueutil)",
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
            items.append(ResultItem(
                title: active ? "Stop Keeping Mac Awake" : "Keep Mac Awake",
                subtitle: active
                    ? "Caffeinate is running, sleep works normally again after this"
                    : "Stops the Mac and display from sleeping until turned off",
                icon: .symbol(active ? "cup.and.saucer" : "cup.and.saucer.fill"),
                score: 950,
                action: { CaffeinateManager.shared.toggle() }
            ))
        }

        return items
    }
}

// Runs a short command line tool and returns its stdout, or "" on failure or
// timeout. stderr goes to the null device (an undrained Pipe would wedge the
// child once it writes 64KB), and a hung binary is terminated — then killed —
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
    static let blueutilPath: String? = {
        ["/opt/homebrew/bin/blueutil", "/usr/local/bin/blueutil"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }()
}

// Keeps a caffeinate child process alive while "keep awake" is on.
final class CaffeinateManager {
    static let shared = CaffeinateManager()

    private var process: Process?

    var isActive: Bool { process?.isRunning == true }

    func toggle() {
        if isActive {
            stop()
        } else {
            let caffeinate = Process()
            caffeinate.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
            caffeinate.arguments = ["-di"]
            try? caffeinate.run()
            process = caffeinate
        }
    }

    func stop() {
        process?.terminate()
        process = nil
    }
}
