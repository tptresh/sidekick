import AppKit

// Spotlight-backed file search via mdfind, restricted to the home folder.
enum FileProvider {
    private static var currentProcess: Process?

    static func search(_ query: String, completion: @escaping ([ResultItem]) -> Void) {
        currentProcess?.terminate()
        guard query.count >= 3 else {
            completion([])
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-onlyin", NSHomeDirectory(), "-name", query]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        currentProcess = process

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try process.run()
            } catch {
                DispatchQueue.main.async { completion([]) }
                return
            }
            // Give slow queries a hard stop.
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                if process.isRunning { process.terminate() }
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let paths = String(decoding: data, as: UTF8.self)
                .split(separator: "\n")
                .map(String.init)
                .filter { !$0.contains("/Library/") }
                .sorted { $0.count < $1.count }
                .prefix(12)

            let items: [ResultItem] = paths.map { path in
                let url = URL(fileURLWithPath: path)
                let icon = NSWorkspace.shared.icon(forFile: path)
                icon.size = NSSize(width: 32, height: 32)
                let shortPath = path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
                return ResultItem(
                    title: url.lastPathComponent,
                    subtitle: shortPath + "  (⌘↩ reveals in Finder)",
                    icon: .appIcon(icon),
                    score: 400 - Double(path.count) * 0.01,
                    dragFileURL: url,
                    secondaryAction: { NSWorkspace.shared.activateFileViewerSelecting([url]) },
                    action: { NSWorkspace.shared.open(url) }
                )
            }
            DispatchQueue.main.async { completion(items) }
        }
    }
}
