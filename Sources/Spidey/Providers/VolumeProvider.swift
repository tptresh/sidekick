import AppKit

// "volume 50", "volume up/down", "mute"/"unmute", and "brightness 0.8" or
// "brightness up/down" (needs the brightness CLI, else opens Displays settings).
enum VolumeProvider {
    // Looked up per query, not cached: SetupCenter may install the CLI in
    // the background after launch.
    static var brightnessCLI: String? { SetupCenter.binaryPath(for: "brightness") }

    static func results(for query: String) -> [ResultItem] {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)

        if lowered == "mute" || lowered == "volume mute" {
            return [muteRow]
        }
        if lowered == "unmute" || lowered == "volume unmute" {
            return [row(
                title: "Unmute", subtitle: "Restores the output volume", symbol: "speaker.wave.2.fill",
                script: "set volume output muted false"
            )]
        }

        if lowered.hasPrefix("volume") || lowered.hasPrefix("vol ") || lowered == "vol" {
            let rest = lowered.hasPrefix("volume")
                ? String(lowered.dropFirst("volume".count)).trimmingCharacters(in: .whitespaces)
                : String(lowered.dropFirst("vol".count)).trimmingCharacters(in: .whitespaces)
            let upRow = row(
                title: "Volume Up", subtitle: "Raises the output volume by 10", symbol: "speaker.wave.3.fill",
                script: "set volume output volume ((output volume of (get volume settings)) + 10)"
            )
            let downRow = row(
                title: "Volume Down", subtitle: "Lowers the output volume by 10", symbol: "speaker.wave.1.fill",
                script: "set volume output volume ((output volume of (get volume settings)) - 10)"
            )
            switch rest {
            case "up":
                return [upRow]
            case "down":
                return [downRow]
            case "":
                // Bare "volume" offers the whole set rather than nothing.
                return [upRow, downRow, muteRow]
            default:
                if let level = percentage(rest) {
                    return [row(
                        title: "Set Volume to \(level)%",
                        subtitle: "Sets the output volume", symbol: "speaker.wave.2.fill",
                        script: "set volume output volume \(level)"
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

    private static var muteRow: ResultItem {
        row(
            title: "Mute", subtitle: "Silences the output volume", symbol: "speaker.slash.fill",
            script: "set volume output muted true"
        )
    }

    // "50", "50%", "max" and "min" all name a level from 0 to 100.
    static func percentage(_ text: String) -> Int? {
        let cleaned = text.replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespaces)
        switch cleaned {
        case "max", "maximum", "full": return 100
        case "min", "minimum", "zero", "off": return 0
        default:
            guard let value = Double(cleaned) else { return nil }
            return min(max(Int(value.rounded()), 0), 100)
        }
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
            guard rest.isEmpty || rest == "up" || rest == "down" || percentage(rest) != nil else {
                return []
            }
            return [ResultItem(
                title: "Open Display Settings",
                subtitle: SetupCenter.shared.missingToolHint("brightness"),
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
                            // An unreadable display (external only) is left
                            // alone rather than jumped to black or full.
                            target = currentBrightness(cli: cli).map { $0 + delta }
                        }
                        guard let target else { return }
                        // Never fully black: 0% leaves no way to see the screen.
                        _ = Shell.run(cli, [String(format: "%.2f", min(max(target, 0.05), 1))])
                    }
                }
            )
        }

        let up = setRow(title: "Brightness Up", subtitle: "Raises display brightness by 10%",
                        symbol: "sun.max.fill", delta: 0.1, level: nil)
        let down = setRow(title: "Brightness Down", subtitle: "Lowers display brightness by 10%",
                          symbol: "sun.min.fill", delta: -0.1, level: nil)
        switch rest {
        case "up":
            return [up]
        case "down":
            return [down]
        case "":
            // Bare "brightness" offers both directions rather than nothing.
            return [up, down]
        default:
            // "brightness 80", "brightness 80%" and "brightness max" all work;
            // "brightness 0.8" is taken as a fraction.
            var value: Double
            if let percent = percentage(rest), !rest.contains(".") {
                value = Double(percent)
            } else if let raw = Double(rest.replacingOccurrences(of: "%", with: "")) {
                value = raw
            } else {
                return []
            }
            if value > 1 { value /= 100 }
            let clamped = min(max(value, 0.05), 1)
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
