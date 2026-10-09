import AppKit

// Exact-word music commands ("play", "pause", "next", "now playing") for
// whichever of Spotify and Music is running.
enum MusicProvider {
    private struct Player {
        let name: String
        let bundleID: String
    }

    private static let players = [
        Player(name: "Spotify", bundleID: "com.spotify.client"),
        Player(name: "Music", bundleID: "com.apple.Music"),
    ]

    private enum Command: CaseIterable {
        case play, pause, toggle, next, previous, nowPlaying

        var phrases: [String] {
            switch self {
            case .play: return ["play"]
            case .pause: return ["pause"]
            case .toggle: return ["play pause", "playpause"]
            case .next: return ["next", "skip"]
            case .previous: return ["prev", "previous", "back"]
            case .nowPlaying: return ["now playing", "playing"]
            }
        }

        var title: String {
            switch self {
            case .play: return "Play"
            case .pause: return "Pause"
            case .toggle: return "Play/Pause"
            case .next: return "Next Track"
            case .previous: return "Previous Track"
            case .nowPlaying: return "Now Playing"
            }
        }

        // The AppleScript verb; Spotify and Music share the same vocabulary.
        var verb: String? {
            switch self {
            case .play: return "play"
            case .pause: return "pause"
            case .toggle: return "playpause"
            case .next: return "next track"
            case .previous: return "previous track"
            case .nowPlaying: return nil
            }
        }
    }

    // "play" and friends are common words, so only an exact phrase matches.
    // Score 890 sits above every partial app match (a prefix like "Playgrounds"
    // for "play" tops out at 876) but below AppProvider's 900 for an exact
    // name, so an app literally named "Play" still wins its own name.
    private static let controlScore: Double = 890
    private static let launchScore: Double = 870
    // Contract with CalendarProvider: with a player running, "Next Track"
    // scores 955 for the exact query "next" so it outranks the calendar
    // next-event row's 950; with no player running, calendar keeps the top.
    private static let nextQueryScore: Double = 955

    static func results(for query: String) -> [ResultItem] {
        let normalized = query.lowercased()
            .split(separator: " ").joined(separator: " ")
        guard let command = Command.allCases.first(where: { $0.phrases.contains(normalized) }) else {
            return []
        }

        let running = players.compactMap { player -> (Player, NSRunningApplication)? in
            let app = NSWorkspace.shared.runningApplications.first {
                $0.bundleIdentifier == player.bundleID
            }
            return app.map { (player, $0) }
        }

        // With no player running, only "play" gets rows: launch offers.
        guard !running.isEmpty else {
            return command == .play ? launchRows() : []
        }

        let baseScore = (command == .next && normalized == "next") ? nextQueryScore : controlScore
        return running.enumerated().map { index, pair in
            let (player, app) = pair
            let score = baseScore - Double(index)
            if command == .nowPlaying {
                return nowPlayingRow(player: player, app: app, score: score)
            }
            return controlRow(command: command, player: player, app: app, score: score)
        }
    }

    private static func controlRow(
        command: Command, player: Player, app: NSRunningApplication, score: Double
    ) -> ResultItem {
        let source = "tell application \"\(player.name)\" to \(command.verb ?? "playpause")"
        return ResultItem(
            title: "\(command.title) (\(player.name))",
            subtitle: "Controls \(player.name) - macOS may ask for permission once",
            icon: icon(for: player, running: app),
            score: score,
            action: {
                SystemProvider.runAppleScript(source, failureTitle: "Could not control \(player.name)", timeout: 15)
            }
        )
    }

    private static func nowPlayingRow(
        player: Player, app: NSRunningApplication, score: Double
    ) -> ResultItem {
        guard let entry = cachedNowPlaying(player) else {
            scheduleNowPlayingFetch(player)
            return ResultItem(
                title: "Now Playing - fetching\u{2026}",
                subtitle: "Asking \(player.name) for the current track",
                icon: icon(for: player, running: app),
                score: score,
                action: {}
            )
        }
        guard let track = entry else {
            return ResultItem(
                title: "Nothing playing",
                subtitle: "\(player.name) has no current track",
                icon: icon(for: player, running: app),
                score: score,
                action: {}
            )
        }
        return ResultItem(
            title: track,
            subtitle: "Now playing in \(player.name) - Return copies track and artist",
            icon: icon(for: player, running: app),
            score: score,
            action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(track, forType: .string)
            }
        )
    }

    private static func launchRows() -> [ResultItem] {
        players.enumerated().compactMap { index, player in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.bundleID) else {
                return nil
            }
            return ResultItem(
                title: "Open \(player.name)",
                subtitle: "\(player.name) isn't running - launch it to start playing",
                icon: icon(for: player, running: nil),
                score: launchScore - Double(index),
                action: {
                    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                }
            )
        }
    }

    // MARK: - Now-playing cache
    //
    // The "track - artist" string per player, fetched off the main thread with
    // a short TTL so results(for:) never blocks: a cold cache shows a
    // "fetching…" row, and the landed fetch posts the shared refresh
    // notification so the visible query re-renders from the warm cache.
    // The cached value is nil when the player has no current track.

    private static let nowPlayingLock = NSLock()
    private static var nowPlayingCache: [String: (track: String?, fetchedAt: Date)] = [:]
    private static var nowPlayingInFlight: Set<String> = []
    private static let nowPlayingTTL: TimeInterval = 3

    // Outer nil: no fresh cache entry. Inner nil: nothing playing.
    private static func cachedNowPlaying(_ player: Player) -> String?? {
        nowPlayingLock.lock()
        defer { nowPlayingLock.unlock() }
        guard let entry = nowPlayingCache[player.name],
              Date().timeIntervalSince(entry.fetchedAt) < nowPlayingTTL else { return nil }
        return .some(entry.track)
    }

    private static func scheduleNowPlayingFetch(_ player: Player) {
        nowPlayingLock.lock()
        let alreadyRunning = nowPlayingInFlight.contains(player.name)
        if !alreadyRunning { nowPlayingInFlight.insert(player.name) }
        nowPlayingLock.unlock()
        guard !alreadyRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            // osascript instead of NSAppleScript: NSAppleScript is documented
            // main-thread-only, and a subprocess can be timed out safely.
            // Generous timeout: the first run blocks on the Automation consent.
            let source = "tell application \"\(player.name)\" to name of current track & \" - \" & artist of current track"
            let output = Shell.run("/usr/bin/osascript", ["-e", source], timeout: 15)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            nowPlayingLock.lock()
            nowPlayingCache[player.name] = (output.isEmpty ? nil : output, Date())
            nowPlayingInFlight.remove(player.name)
            nowPlayingLock.unlock()
            // Nudge the query engine to re-render against the warm cache.
            NotificationCenter.default.post(name: .spideyFaviconLoaded, object: nil)
        }
    }

    private static func icon(for player: Player, running: NSRunningApplication?) -> ResultIcon {
        let image = running?.icon
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.bundleID)
                .map { NSWorkspace.shared.icon(forFile: $0.path) }
        guard let image else { return .symbol("music.note") }
        image.size = NSSize(width: 32, height: 32)
        return .appIcon(image)
    }
}
