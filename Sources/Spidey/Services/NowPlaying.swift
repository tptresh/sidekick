import Foundation

// What macOS shows under Now Playing: which app, the page title, and how far
// in. Browsers report this even when the video sits in a cross-site frame,
// which is the only way to learn the time in a streaming site's player.
//
// MediaRemote is private and refuses callers that are not Apple-signed, so
// the read runs inside osascript, which is.
enum NowPlaying {
    struct Info: Equatable {
        let bundleID: String
        let title: String
        let position: Double
        let duration: Double?
        let playing: Bool
    }

    private static let script = """
    ObjC.import("Foundation");
    $.NSBundle.bundleWithPath("/System/Library/PrivateFrameworks/MediaRemote.framework").load;
    const request = $.NSClassFromString("MRNowPlayingRequest");
    const item = request ? request.localNowPlayingItem : null;
    const path = request ? request.localNowPlayingPlayerPath : null;
    if (!item || !path || !item.metadata) { "" } else {
        const md = item.metadata;
        JSON.stringify({
            bundleID: ObjC.unwrap(path.client.bundleIdentifier) || "",
            title: ObjC.unwrap(md.title) || "",
            position: md.calculatedPlaybackPosition || md.elapsedTime || 0,
            duration: md.duration || 0,
            rate: md.playbackRate || 0
        });
    }
    """

    private static let queue = DispatchQueue(label: "dev.opensource.spidey.nowplaying", qos: .userInitiated)

    static func read(timeout: TimeInterval, completion: @escaping (Info?) -> Void) {
        queue.async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-l", "JavaScript", "-e", script]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            guard (try? process.run()) != nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            killer.cancel()
            let info = parse(data)
            DispatchQueue.main.async { completion(info) }
        }
    }

    static func parse(_ data: Data) -> Info? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let bundleID = object["bundleID"] as? String, !bundleID.isEmpty,
              let title = object["title"] as? String,
              let position = (object["position"] as? NSNumber)?.doubleValue, position > 0
        else { return nil }
        let duration = (object["duration"] as? NSNumber)?.doubleValue
        return Info(
            bundleID: bundleID,
            title: title,
            position: position,
            duration: (duration ?? 0) > 0 ? duration : nil,
            playing: ((object["rate"] as? NSNumber)?.doubleValue ?? 0) > 0
        )
    }

    // Resuming: jump the reopened page to the saved time. Streaming sites
    // often stall, error or reload in the first seconds, and a jump made then
    // is lost, so it only fires after 5 seconds of steady playback (the time
    // advancing about a second per second, never going backwards). Anything
    // else restarts that count rather than giving up. After a jump it keeps
    // watching, and jumps again if a reload throws the player back to the
    // start. Runs in one osascript process polling Now Playing once a second.
    private static let seekScript = """
    function run(argv) {
        ObjC.import("Foundation");
        $.NSBundle.bundleWithPath("/System/Library/PrivateFrameworks/MediaRemote.framework").load;
        ObjC.bindFunction("MRMediaRemoteSetElapsedTime", ["void", ["double"]]);
        ObjC.bindFunction("MRMediaRemoteSendCommand", ["bool", ["int", "id"]]);
        const bundleID = argv[0], name = argv[1];
        const target = parseFloat(argv[2]), wait = parseFloat(argv[3]);
        const steadyFor = 5, holdFor = 15;
        const request = $.NSClassFromString("MRNowPlayingRequest");
        const norm = s => s.toLowerCase().replace(/[^\\p{L}\\p{N}]+/gu, " ").trim();
        function now() {
            const item = request.localNowPlayingItem, path = request.localNowPlayingPlayerPath;
            if (!item || !path || !item.metadata) return null;
            const md = item.metadata;
            const bundle = ObjC.unwrap(path.client.bundleIdentifier) || "";
            const title = norm(ObjC.unwrap(md.title) || "");
            if ((bundleID && bundle !== bundleID) || !title.includes(name)) return null;
            return { position: md.calculatedPlaybackPosition || 0, rate: md.playbackRate || 0 };
        }
        function jump(useCommand) {
            if (useCommand) {
                const options = $.NSDictionary.dictionaryWithObjectForKey(
                    $.NSNumber.numberWithDouble(target), $("kMRMediaRemoteOptionPlaybackPosition"));
                $.MRMediaRemoteSendCommand(24, options);
            } else {
                $.MRMediaRemoteSetElapsedTime(target);
            }
        }
        const start = Date.now();
        const elapsed = () => (Date.now() - start) / 1000;
        let steady = 0, last = null, lastAt = 0, attempts = 0, heldSince = null;
        while (elapsed() < wait) {
            const n = now(), at = elapsed();
            const advancing = n && n.rate > 0 && last !== null
                && n.position - last >= 0.3 * (at - lastAt)
                && n.position - last <= 3 * (at - lastAt) + 1;
            steady = advancing ? steady + (at - lastAt) : 0;
            last = n ? n.position : null;
            lastAt = at;
            if (n && n.position >= target - 10) {
                // There, either by our jump or the site's own memory. Done once
                // it stays there through the window where reloads happen.
                if (heldSince === null) heldSince = at;
                if (advancing && at - heldSince >= holdFor) return "held";
            } else {
                heldSince = null;
                if (steady >= steadyFor) {
                    // Alternate the two ways in, in case the site honours one.
                    jump(attempts % 2 === 1);
                    attempts += 1;
                    steady = 0;
                    last = null;
                }
            }
            delay(1);
        }
        return "gave up";
    }
    """

    private static var pendingSeek: (process: Process, show: String, time: Double)?

    // A skip still waiting for this show, so a save made meanwhile (from a
    // player that just restarted at 0:07) does not overwrite the saved time.
    static func pendingSkipTime(forShow show: String) -> Double? {
        guard let pending = pendingSeek, pending.process.isRunning,
              pending.show == WatchStore.normalize(show)
        else { return nil }
        return pending.time
    }

    // A newer resume replaces any jump still waiting on an older one.
    static func seekWhenPlaying(bundleID: String?, show: String, to time: Double, wait: TimeInterval = 1800) {
        pendingSeek?.process.terminate()
        let key = WatchStore.normalize(show)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-l", "JavaScript", "-e", seekScript,
            bundleID ?? "", key, String(time), String(wait),
        ]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return }
        pendingSeek = (process, key, time)
        DispatchQueue.main.asyncAfter(deadline: .now() + wait + 10) {
            if process.isRunning { process.terminate() }
        }
    }

    // "1:04:04", or "23:10" under an hour.
    static func timeLabel(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        let (hours, minutes, secs) = (total / 3600, total / 60 % 60, total % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}
