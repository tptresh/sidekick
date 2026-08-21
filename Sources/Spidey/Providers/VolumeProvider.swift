import AppKit

// "volume 50", "volume up/down", "mute"/"unmute", and "brightness 0.8" or
// "brightness up/down" (needs the brightness CLI, else opens Displays settings).
enum VolumeProvider {
    static let brightnessCLI: String? = {
        ["/opt/homebrew/bin/brightness", "/usr/local/bin/brightness"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }()

    static func results(for query: String) -> [ResultItem] {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)

        if lowered == "mute" || lowered == "volume mute" {
            return [row(
                title: "Mute", subtitle: "Silences the output volume", symbol: "speaker.slash.fill",
                script: "set volume output muted true"
            )]
        }
        if lowered == "unmute" || lowered == "volume unmute" {
            return [row(
                title: "Unmute", subtitle: "Restores the output volume", symbol: "speaker.wave.2.fill",
                script: "set volume output muted false"
            )]
        }

        if lowered.hasPrefix("volume") || lowered.hasPrefix("vol ") {
            let rest = lowered.hasPrefix("volume")
                ? String(lowered.dropFirst("volume".count)).trimmingCharacters(in: .whitespaces)
                : String(lowered.dropFirst("vol ".count)).trimmingCharacters(in: .whitespaces)
            switch rest {
            case "up":
                return [row(
                    title: "Volume Up", subtitle: "Raises the output volume by 10", symbol: "speaker.wave.3.fill",
                    script: "set volume output volume ((output volume of (get volume settings)) + 10)"
                )]
            case "down":
                return [row(
                    title: "Volume Down", subtitle: "Lowers the output volume by 10", symbol: "speaker.wave.1.fill",
                    script: "set volume output volume ((output volume of (get volume settings)) - 10)"
                )]
            default:
                if let level = Int(rest) {
                    let clamped = min(max(level, 0), 100)
                    return [row(
                        title: "Set Volume to \(clamped)%",
                        subtitle: "Sets the output volume", symbol: "speaker.wave.2.fill",
                        script: "set volume output volume \(clamped)"
                    )]
                }
            }
            return []
        }

        if lowered.hasPrefix("brightness") {
            let rest = String(lowered.dropFirst("brightness".count))
                .trimmingCharacters(in: .whitespaces)
            return brightnessResults(for: rest)
        }
        return []
    }

    private static func row(
        title: String, subtitle: String, symbol: String, script: String
    ) -> ResultItem {
        ResultItem(
            title: title, subtitle: subtitle, icon: .symbol(symbol), score: 950,
            action: { SystemProvider.runAppleScript(script) }
        )
    }

    // MARK: - Brightness

    private static func brightnessResults(for rest: String) -> [ResultItem] {
        guard let cli = brightnessCLI else {
            guard rest.isEmpty || rest == "up" || rest == "down" || Double(rest) != nil else {
                return []
            }
            return [ResultItem(
                title: "Open Display Settings",
                subtitle: "Changing brightness directly needs the brightness CLI (brew install brightness)",
                icon: .symbol("sun.max"), score: 950,
                action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            )]
        }

        func setRow(title: String, subtitle: String, symbol: String, delta: Double?, level: Double?) -> ResultItem {
            ResultItem(
                title: title, subtitle: subtitle, icon: .symbol(symbol), score: 950,
                action: {
                    // Two Process spawns (read, then set) - keep them off the
                    // main thread so Return never stalls the panel.
                    DispatchQueue.global(qos: .userInitiated).async {
                        var target = level
                        if let delta {
                            target = currentBrightness(cli: cli).map { $0 + delta } ?? (delta > 0 ? 1 : 0)
                        }
                        guard let target else { return }
                        _ = Shell.run(cli, [String(format: "%.2f", min(max(target, 0), 1))])
                    }
                }
            )
        }

        switch rest {
        case "up":
            return [setRow(title: "Brightness Up", subtitle: "Raises display brightness by 10%",
                           symbol: "sun.max.fill", delta: 0.1, level: nil)]
        case "down":
            return [setRow(title: "Brightness Down", subtitle: "Lowers display brightness by 10%",
                           symbol: "sun.min.fill", delta: -0.1, level: nil)]
        default:
            guard var value = Double(rest) else { return [] }
            // "brightness 80" reads as a percentage.
            if value > 1 { value /= 100 }
            let clamped = min(max(value, 0), 1)
            return [setRow(
                title: "Set Brightness to \(Int((clamped * 100).rounded()))%",
                subtitle: "Sets display brightness", symbol: "sun.max.fill",
                delta: nil, level: clamped
            )]
        }
    }

    static func currentBrightness(cli: String) -> Double? {
        // "display 0: brightness 0.812500"
        let output = Shell.run(cli, ["-l"])
        for line in output.split(separator: "\n") where line.contains("brightness") {
            if let raw = line.split(separator: " ").last, let value = Double(raw) {
                return value
            }
        }
        return nil
    }
}
