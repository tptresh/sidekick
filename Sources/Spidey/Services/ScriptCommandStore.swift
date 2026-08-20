import AppKit

struct ScriptCommand: Equatable {
    let keyword: String
    let url: URL
    let description: String?
}

// Executable files in ~/Library/Application Support/Spidey/scripts become
// commands: the filename (minus extension) is the keyword. The directory is
// rescanned whenever its modification time changes.
final class ScriptCommandStore {
    static let shared = ScriptCommandStore()

    static let timeout: TimeInterval = 10
    static let maxOutputBytes = 1_000_000

    static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Spidey/scripts", isDirectory: true)
    }()

    private var cached: [ScriptCommand] = []
    private var cachedMTime: Date?

    private init() {}

    var commands: [ScriptCommand] {
        let attributes = try? FileManager.default.attributesOfItem(atPath: Self.directory.path)
        let mtime = attributes?[.modificationDate] as? Date
        if let mtime, mtime == cachedMTime { return cached }
        cachedMTime = mtime
        cached = Self.scan(directory: Self.directory)
        return cached
    }

    func command(keyword: String) -> ScriptCommand? {
        let lowered = keyword.lowercased()
        return commands.first { $0.keyword == lowered }
    }

    static func scan(directory: URL) -> [ScriptCommand] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: directory.path) else { return [] }
        return names.sorted().compactMap { name in
            guard !name.hasPrefix(".") else { return nil }
            let url = directory.appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue,
                  fm.isExecutableFile(atPath: url.path) else { return nil }
            let keyword = url.deletingPathExtension().lastPathComponent.lowercased()
            guard !keyword.isEmpty else { return nil }
            return ScriptCommand(keyword: keyword, url: url, description: description(ofScriptAt: url))
        }
    }

    // Reads a "# spidey: <description>" comment (any comment leader) from the
    // first 5 lines of the script.
    static func description(ofScriptAt url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4096) else { return nil }
        return description(fromSource: String(decoding: data, as: UTF8.self))
    }

    static func description(fromSource source: String) -> String? {
        let leaders = Set("#/;*%-! \t")
        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false).prefix(5) {
            var line = rawLine
            while let first = line.first, leaders.contains(first) {
                line = line.dropFirst()
            }
            guard line.lowercased().hasPrefix("spidey:") else { continue }
            let description = line.dropFirst("spidey:".count).trimmingCharacters(in: .whitespaces)
            return description.isEmpty ? nil : description
        }
        return nil
    }

    // MARK: - Output contract

    struct ScriptItem: Equatable {
        enum Action: String {
            case copy
            case open
        }

        let title: String
        let subtitle: String
        let arg: String
        let action: Action
    }

    enum ScriptOutput: Equatable {
        case items([ScriptItem])
        case plain(String)
    }

    // {"items": [{"title": "...", "subtitle": "...", "arg": "...", "action": "copy"|"open"}]}
    // becomes .items; anything else is .plain. arg defaults to the title and
    // action defaults to copy.
    static func parseOutput(_ stdout: String) -> ScriptOutput {
        struct Payload: Decodable {
            struct Item: Decodable {
                let title: String
                let subtitle: String?
                let arg: String?
                let action: String?
            }
            let items: [Item]
        }
        if let data = stdout.data(using: .utf8),
           let payload = try? JSONDecoder().decode(Payload.self, from: data) {
            let items = payload.items.compactMap { item -> ScriptItem? in
                let title = item.title.trimmingCharacters(in: .whitespaces)
                guard !title.isEmpty else { return nil }
                return ScriptItem(
                    title: title,
                    subtitle: item.subtitle ?? "",
                    arg: item.arg ?? title,
                    action: ScriptItem.Action(rawValue: item.action ?? "copy") ?? .copy
                )
            }
            if !items.isEmpty { return .items(items) }
        }
        return .plain(stdout)
    }

    // MARK: - Execution

    struct RunResult {
        let exitCode: Int32
        let timedOut: Bool
        let stdout: String
        let stderr: String
    }

    // Runs the script file directly (never through a shell) with the given
    // argv, cwd = the scripts directory, a 10s timeout, and stdout capped at
    // 1 MB. Completion is delivered on the main queue.
    static func run(_ command: ScriptCommand, args: [String], completion: @escaping (RunResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = command.url
            process.arguments = args
            process.currentDirectoryURL = directory
            process.standardInput = FileHandle.nullDevice
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            let lock = NSLock()
            var outData = Data()
            var errData = Data()
            var timedOut = false
            // Keep draining both pipes so a chatty script never blocks on a
            // full buffer; bytes past the cap are read and discarded.
            let drain: (FileHandle, @escaping (Data) -> Void) -> Void = { handle, append in
                handle.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    guard !chunk.isEmpty else { return }
                    lock.lock()
                    append(chunk)
                    lock.unlock()
                }
            }
            drain(outPipe.fileHandleForReading) { chunk in
                outData.append(chunk.prefix(max(0, maxOutputBytes - outData.count)))
            }
            drain(errPipe.fileHandleForReading) { chunk in
                errData.append(chunk.prefix(max(0, 65_536 - errData.count)))
            }

            do {
                try process.run()
            } catch {
                let failure = RunResult(exitCode: -1, timedOut: false, stdout: "", stderr: error.localizedDescription)
                DispatchQueue.main.async { completion(failure) }
                return
            }

            let pid = process.processIdentifier
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                guard process.isRunning else { return }
                lock.lock()
                timedOut = true
                lock.unlock()
                process.terminate()
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                    if process.isRunning { kill(pid, SIGKILL) }
                }
            }

            process.waitUntilExit()
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            if let rest = try? outPipe.fileHandleForReading.readToEnd() {
                lock.lock()
                outData.append(rest.prefix(max(0, maxOutputBytes - outData.count)))
                lock.unlock()
            }

            lock.lock()
            let result = RunResult(
                exitCode: process.terminationStatus,
                timedOut: timedOut,
                stdout: String(decoding: outData, as: UTF8.self),
                stderr: String(decoding: errData, as: UTF8.self)
            )
            lock.unlock()
            DispatchQueue.main.async { completion(result) }
        }
    }

    // MARK: - First-run setup

    static func createDirectoryWithExample() {
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let example = directory.appendingPathComponent("hello.sh")
        if !fm.fileExists(atPath: example.path) {
            let source = """
            #!/bin/bash
            # spidey: Example script command, type "hello" in Spidey
            # Every executable file in this folder becomes a command; the filename
            # (minus extension) is the keyword. Plain output is copied on Return.
            # Print {"items": [{"title": "...", "subtitle": "...", "arg": "...", "action": "copy"}]}
            # for rich results ("action" is "copy" or "open").
            echo "Hello from Spidey, $USER"
            """
            try? source.write(to: example, atomically: true, encoding: .utf8)
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: example.path)
        }
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }
}
