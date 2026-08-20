import SwiftUI
import AppKit
import ServiceManagement
import Carbon.HIToolbox

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var clipboard = ClipboardStore.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                themeSection
                hotkeySection
                streamingSection
                claudeSection
                clipboardSection
                loginSection
            }
            .padding(24)
        }
        .frame(width: 480, height: 560)
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hero Theme").font(.headline)
            HStack(spacing: 12) {
                ForEach(HeroTheme.allCases, id: \.self) { theme in
                    ThemePreviewButton(
                        theme: theme,
                        isSelected: settings.theme == theme,
                        select: { settings.theme = theme }
                    )
                }
            }
        }
    }

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Open Sidekick With").font(.headline)
            HStack(spacing: 12) {
                HotKeyRecorder(combo: $settings.hotKey)
                    .frame(width: 160, height: 28)
                if let active = settings.activeHotKey, active != settings.hotKey {
                    Label("Using \(active.displayString) instead", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            if settings.hotKey == .commandSpace {
                Text("For ⌘Space to reach Sidekick, turn off Spotlight's shortcut first: System Settings > Keyboard > Keyboard Shortcuts > Spotlight > untick \"Show Spotlight search\".")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text("Click the box, then press the new key combination.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var streamingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Streaming Services").font(.headline)
            Text("Typing a show name offers to open it on each enabled service, in Brave.")
                .font(.caption)
                .foregroundColor(.secondary)
            ForEach(StreamingService.all) { service in
                Toggle(service.name, isOn: Binding(
                    get: { settings.enabledServices.contains(service.id) },
                    set: { enabled in
                        if enabled {
                            settings.enabledServices.insert(service.id)
                        } else {
                            settings.enabledServices.remove(service.id)
                        }
                    }
                ))
            }
        }
    }

    private var claudeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Claude Code").font(.headline)
            Text("Typing \"claude <task>\" starts a Claude Code session in the Claude Code app, using this folder.")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                TextField("Default folder", text: $settings.claudeDirectory)
                    .textFieldStyle(.roundedBorder)
                Button("Choose…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        settings.claudeDirectory = url.path
                    }
                }
            }
        }
    }

    private var clipboardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Clipboard History").font(.headline)
            Text("Type \"clip\" in Sidekick to browse. Currently holding \(clipboard.entries.count) item\(clipboard.entries.count == 1 ? "" : "s").")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                Stepper(
                    "Keep up to \(settings.clipboardLimit) items",
                    value: $settings.clipboardLimit,
                    in: 10...1000, step: 10
                )
                Spacer()
                Button("Clear History") { clipboard.clear() }
            }
        }
    }

    private var loginSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("General").font(.headline)
            Toggle("Launch Sidekick at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                        launchAtLoginError = nil
                    } catch {
                        launchAtLoginError = error.localizedDescription
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            if let launchAtLoginError {
                Text(launchAtLoginError).font(.caption).foregroundColor(.orange)
            }
        }
    }
}

private struct ThemePreviewButton: View {
    let theme: HeroTheme
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.palette.background)
                        .frame(width: 120, height: 64)
                    Image(nsImage: StatusIcons.watermark(
                        for: theme, size: 36, color: NSColor(theme.palette.accent)
                    ))
                    .resizable()
                    .frame(width: 36, height: 36)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? theme.palette.accent : Color.gray.opacity(0.3),
                                lineWidth: isSelected ? 2.5 : 1)
                )
                Text(theme.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
        }
        .buttonStyle(.plain)
    }
}

// Click to focus, then press a key combo. Esc cancels, Delete resets to Cmd+Space.
private struct HotKeyRecorder: NSViewRepresentable {
    @Binding var combo: HotKeyCombo

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onCombo = { combo = $0 }
        view.display = combo.displayString
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.display = combo.displayString
        nsView.needsDisplay = true
    }

    final class RecorderView: NSView {
        var onCombo: ((HotKeyCombo) -> Void)?
        var display: String = ""
        private var recording = false

        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) {
            recording = true
            window?.makeFirstResponder(self)
            needsDisplay = true
        }

        override func resignFirstResponder() -> Bool {
            recording = false
            needsDisplay = true
            return super.resignFirstResponder()
        }

        override func keyDown(with event: NSEvent) {
            guard recording else {
                super.keyDown(with: event)
                return
            }
            if event.keyCode == UInt16(kVK_Escape) {
                recording = false
                window?.makeFirstResponder(nil)
                needsDisplay = true
                return
            }
            if event.keyCode == UInt16(kVK_Delete) {
                onCombo?(.commandSpace)
                recording = false
                window?.makeFirstResponder(nil)
                return
            }
            var carbon: UInt32 = 0
            let flags = event.modifierFlags
            if flags.contains(.command) { carbon |= UInt32(cmdKey) }
            if flags.contains(.option) { carbon |= UInt32(optionKey) }
            if flags.contains(.control) { carbon |= UInt32(controlKey) }
            if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
            // Require at least one modifier so plain typing cannot become the hotkey.
            guard carbon != 0 else { return }
            onCombo?(HotKeyCombo(keyCode: UInt32(event.keyCode), carbonModifiers: carbon))
            recording = false
            window?.makeFirstResponder(nil)
        }

        override func draw(_ dirtyRect: NSRect) {
            let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
            (recording ? NSColor.controlAccentColor.withAlphaComponent(0.2) : NSColor.controlBackgroundColor).setFill()
            background.fill()
            (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
            background.lineWidth = recording ? 2 : 1
            background.stroke()

            let text = recording ? "Press keys…" : display
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.labelColor,
            ]
            let size = text.size(withAttributes: attributes)
            text.draw(
                at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
                withAttributes: attributes
            )
        }
    }
}
