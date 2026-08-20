import AppKit

// "quit chrome" politely quits an app; "kill chrome" force-quits it, and
// "kill node" also reaches background processes via pgrep.
enum ProcessProvider {
    static func results(for query: String) -> [ResultItem] {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
        let force: Bool
        let term: String
        if lowered.hasPrefix("force quit ") {
            force = true
            term = String(lowered.dropFirst("force quit ".count))
        } else if lowered.hasPrefix("kill ") {
            force = true
            term = String(lowered.dropFirst("kill ".count))
        } else if lowered.hasPrefix("quit ") {
            force = false
            term = String(lowered.dropFirst("quit ".count))
        } else {
            return []
        }
        guard term.count >= 2 else { return [] }

        var items: [ResultItem] = []

        // Running apps with a UI.
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0 != NSRunningApplication.current
        }
        for app in running {
            guard let name = app.localizedName,
                  let match = Fuzzy.score(query: term, candidate: name), match >= 0.6 else { continue }
            let icon = app.icon.map { image -> NSImage in
                image.size = NSSize(width: 32, height: 32)
                return image
            }
            items.append(ResultItem(
                title: force ? "Force Quit \(name)" : "Quit \(name)",
                subtitle: force
                    ? "Ends the app immediately, unsaved changes are lost"
                    : "Asks the app to quit normally",
                icon: icon.map { ResultIcon.appIcon($0) } ?? .symbol("xmark.circle.fill"),
                score: 940 + match * 40,
                action: {
                    if force {
                        app.forceTerminate()
                    } else {
                        app.terminate()
                    }
                }
            ))
        }

        // Background processes, only for the explicit kill keyword.
        if force {
            for process in backgroundProcesses(matching: term).prefix(5) {
                items.append(ResultItem(
                    title: "Kill \(process.name)",
                    subtitle: "Sends SIGKILL to process \(process.pid)",
                    icon: .symbol("bolt.slash.fill"),
                    score: 930,
                    action: { kill(process.pid, SIGKILL) }
                ))
            }
        }
        return items
    }

    struct BackgroundProcess {
        let pid: pid_t
        let name: String
    }

    static func backgroundProcesses(matching term: String) -> [BackgroundProcess] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-il", term]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        // Names already offered as running apps stay out of the pgrep list.
        let appPids = Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
        let ownPid = ProcessInfo.processInfo.processIdentifier

        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .compactMap { line in
                let parts = line.split(separator: " ", maxSplits: 1)
                guard parts.count == 2, let pid = pid_t(parts[0]),
                      pid != ownPid, !appPids.contains(pid) else { return nil }
                return BackgroundProcess(pid: pid, name: String(parts[1]))
            }
    }
}
