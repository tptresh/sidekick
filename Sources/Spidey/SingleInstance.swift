import AppKit

// One Sidekick at a time.
//
// Any checkout of this repo can build a Sidekick.app, and every one of those
// bundles carries the same bundle id. macOS keys apps by that id but still
// launches bundles by path, so an old copy left in .claude/worktrees can end
// up running beside the build ship.sh just made: two menu bar icons, two
// registrations of the same global hot key, and two clipboard and screenshot
// watchers writing the same history.
//
// The last launch is always the newest build, so it wins - it terminates the
// older instances and carries on alone.
enum SingleInstance {
    static func enforce() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let me = NSRunningApplication.current
        let older = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != me.processIdentifier && isOlder($0, than: me) }
        guard !older.isEmpty else { return }

        for app in older { app.terminate() }

        // A pending modal (a permission prompt, say) can hold an instance past
        // a polite terminate, and a survivor is exactly the bug this guards
        // against, so escalate instead of giving up.
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline, !stillRunning(older, bundleID: bundleID).isEmpty {
            Thread.sleep(forTimeInterval: 0.1)
        }
        for app in stillRunning(older, bundleID: bundleID) { app.forceTerminate() }
    }

    private static func isOlder(_ other: NSRunningApplication, than me: NSRunningApplication) -> Bool {
        if let theirs = other.launchDate, let mine = me.launchDate, theirs != mine {
            return theirs < mine
        }
        // Same instant, or a launch date macOS would not tell us: the pid keeps
        // the ordering strict so two simultaneous launches cannot terminate
        // each other and leave none running.
        return other.processIdentifier < me.processIdentifier
    }

    // Re-asks the system rather than reading the cached isTerminated flags,
    // which only refresh on a run loop we have not started yet.
    private static func stillRunning(_ apps: [NSRunningApplication], bundleID: String) -> [NSRunningApplication] {
        let pids = Set(apps.map(\.processIdentifier))
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { pids.contains($0.processIdentifier) }
    }
}
