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

    // Resuming: once the reopened page starts playing from near the start,
    // jump it to the saved time. Waits in one osascript process (polling Now
    // Playing once a second) because the user usually has to press play, and
    // checks the jump took, falling back to the plain seek command.
    private static let seekScript = """
    function run(argv) {
        ObjC.import("Foundation");
        $.NSBundle.bundleWithPath("/System/Library/PrivateFrameworks/MediaRemote.framework").load;
        ObjC.bindFunction("MRMediaRemoteSetElapsedTime", ["void", ["double"]]);
        ObjC.bindFunction("MRMediaRemoteSendCommand", ["bool", ["int", "id"]]);
        const bundleID = argv[0], name = argv[1];
        const target = parseFloat(argv[2]), wait = parseFloat(argv[3]);
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
        const landed = () => { const n = now(); return n && n.position >= target - 5; };
        const start = Date.now();
        while ((Date.now() - start) / 1000 < wait) {
            const n = now();
            if (n && n.position >= target - 10) return "already there";
            if (n && n.rate > 0) {
                $.MRMediaRemoteSetElapsedTime(target);
                delay(1.5);
                if (landed()) return "jumped";
                const options = $.NSDictionary.dictionaryWithObjectForKey(
                    $.NSNumber.numberWithDouble(target), $("kMRMediaRemoteOptionPlaybackPosition"));
                $.MRMediaRemoteSendCommand(24, options);
                delay(1.5);
                return landed() ? "jumped" : "ignored";
            }
            delay(1);
        }
        return "never played";
    }
    """

    private static var pendingSeek: Process?

    // A newer resume replaces any jump still waiting on an older one.
    static func seekWhenPlaying(bundleID: String?, show: String, to time: Double, wait: TimeInterval = 600) {
        pendingSeek?.terminate()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-l", "JavaScript", "-e", seekScript,
            bundleID ?? "", WatchStore.normalize(show), String(time), String(wait),
        ]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return }
        pendingSeek = process
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
