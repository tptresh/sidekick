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
                    let sent = force ? app.forceTerminate() : app.terminate()
                    if !sent, !app.isTerminated {
                        SystemProvider.tellUser(
                            title: "Could not quit \(name)",
                            body: force
                                ? "macOS refused to force quit it."
                                : "It did not accept the request. Try kill \(name.lowercased()) to force it."
                        )
                    }
                }
            ))
        }

        // Background processes, only for the explicit kill keyword. Several
        // processes often share a name (node, python), so they get one row.
        if force {
            for group in groupedByName(backgroundProcesses(matching: term)).prefix(5) {
                let pidList = group.pids.map(String.init).joined(separator: ", ")
                items.append(ResultItem(
                    title: "Kill \(group.name)",
                    subtitle: group.pids.count == 1
                        ? "Sends SIGKILL to process \(pidList)"
                        : "Sends SIGKILL to all \(group.pids.count) of them (processes \(pidList))",
                    icon: .symbol("bolt.slash.fill"),
                    score: 930,
                    action: { killAll(group) }
                ))
            }
        }

        // Without this, "quit chrome" with Chrome closed left an unrelated
        // row (a streaming search) on top, as if it were the answer.
        if items.isEmpty {
            let name = term.trimmingCharacters(in: .whitespaces).capitalized
            items.append(ResultItem(
                title: "\(name) is not running",
                subtitle: force
                    ? "No open app or background process matches, so there is nothing to kill"
                    : "No open app matches, so there is nothing to quit",
                icon: .symbol("xmark.circle"),
                score: 900,
                action: {}
            ))
        }
        return items
    }

    struct ProcessGroup {
        let name: String
        let pids: [pid_t]
    }

    static func groupedByName(_ processes: [BackgroundProcess]) -> [ProcessGroup] {
        var order: [String] = []
        var pids: [String: [pid_t]] = [:]
        for process in processes {
            if pids[process.name] == nil { order.append(process.name) }
            pids[process.name, default: []].append(process.pid)
        }
        return order.map { ProcessGroup(name: $0, pids: pids[$0] ?? []) }
    }

    private static func killAll(_ group: ProcessGroup) {
        var refused = false
        var failed = 0
        for pid in group.pids where kill(pid, SIGKILL) != 0 {
            // Read errno straight away, before anything else can overwrite it.
            let code = errno
            failed += 1
            if code == EPERM { refused = true }
        }
        guard failed > 0 else { return }
        // Processes owned by root or another user refuse the signal; say so
        // instead of looking like it worked.
        let some = failed < group.pids.count ? "Some of them could not be killed. " : ""
        SystemProvider.tellUser(
            title: "Could not kill \(group.name)",
            body: some + (refused
                ? "\(group.pids.count == 1 ? "It belongs" : "They belong") to the system or another user, "
                    + "so macOS did not allow it."
                : "\(group.pids.count == 1 ? "It" : "They") may have already quit.")
        )
    }

    struct BackgroundProcess {
        let pid: pid_t
        let name: String
    }

    static func backgroundProcesses(matching term: String) -> [BackgroundProcess] {
        // Runs on every keystroke on the main thread, so it is bounded: a
        // stuck pgrep costs at most a second, never a frozen panel.
        let output = Shell.run("/usr/bin/pgrep", ["-il", term], timeout: 1)

        // Names already offered as running apps stay out of the pgrep list.
        let appPids = Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
        let ownPid = ProcessInfo.processInfo.processIdentifier

        return output
            .split(separator: "\n")
            .compactMap { line in
                let parts = line.split(separator: " ", maxSplits: 1)
                guard parts.count == 2, let pid = pid_t(parts[0]),
                      pid != ownPid, !appPids.contains(pid) else { return nil }
                return BackgroundProcess(pid: pid, name: String(parts[1]))
            }
    }
}
