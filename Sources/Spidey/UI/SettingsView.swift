import SwiftUI
import AppKit
import ServiceManagement
import Carbon.HIToolbox

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var clipboard = ClipboardStore.shared
    @ObservedObject var linkChecker = LinkChecker.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?
    // Which media row's ⓘ popover is open, by entry id.
    @State private var infoEntryID: String?
    // Add Site form state - a row is only created once a link is entered.
    @State private var showingAddSite = false
    @State private var newSiteName = ""
    @State private var newSiteURL = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                themeSection
                hotkeySection
                mediaSection
                claudeSection
                clipboardSection
                setupSection
                loginSection
            }
            .padding(24)
        }
        .frame(width: 480, height: 560)
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Theme").font(.headline)
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

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Media Sites").font(.headline)
            Text("Typing a show name offers to open it on each enabled site, in Brave. Favourite site not here? Add a link below and we can search directly there! Added links join this list, and every link is auto-checked every \(Self.checkIntervalDays) days.")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Drag rows to set the order results appear in. Press ⓘ to see a site's link. A newly added link joins searches right away; in the background Sidekick opens the site, types into its search box, and learns how its search works so results can jump straight to the right page - usually ready within a minute or two.")
                .font(.caption)
                .foregroundColor(.secondary)
            let entries = settings.orderedMediaEntries
            List {
                ForEach(entries) { entry in
                    mediaRow(for: entry)
                        .frame(height: 24)
                        .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
                        .listRowSeparator(.hidden)
                }
                .onMove { source, destination in
                    settings.moveMediaEntries(fromOffsets: source, toOffset: destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .environment(\.defaultMinListRowHeight, 30)
            .frame(height: CGFloat(entries.count) * 30)
            HStack {
                Button("Add Site") { showingAddSite = true }
                    .popover(isPresented: $showingAddSite, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Name (optional)", text: $newSiteName)
                            TextField("https://example.com", text: $newSiteURL)
                            Text("A link is required. Sidekick then finds and verifies the site's own search page - usually under a minute, up to a few minutes for some sites.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Spacer()
                                Button("Add") {
                                    settings.customMediaSites.append(CustomMediaSite(
                                        name: newSiteName, urlString: newSiteURL
                                    ))
                                    newSiteName = ""
                                    newSiteURL = ""
                                    showingAddSite = false
                                }
                                .keyboardShortcut(.defaultAction)
                                .disabled(!CustomMediaSite(urlString: newSiteURL).isValid)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .padding(12)
                        .frame(width: 320)
                    }
                Spacer()
                if linkChecker.isRunning {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking links…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(lastCheckDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Check Now") {
                        linkChecker.checkNow()
                        linkChecker.retryFailedDiscoveries()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mediaRow(for entry: MediaEntry) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundColor(Color.secondary.opacity(0.6))
            switch entry {
            case .service(let service):
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
            case .custom(let site):
                let binding = siteBinding(site)
                Toggle(binding.wrappedValue.displayName, isOn: binding.enabled)
                if let host = binding.wrappedValue.host,
                   linkChecker.discoveringHosts.contains(host) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.6)
                        .help("Learning this site's search - can take a few minutes")
                }
                deadLinkWarning(for: binding.wrappedValue)
            }
            Spacer()
            infoButton(for: entry)
        }
    }

    private func infoButton(for entry: MediaEntry) -> some View {
        Button {
            infoEntryID = entry.id
        } label: {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .help("Show this site's link")
        .popover(isPresented: Binding(
            get: { infoEntryID == entry.id },
            set: { shown in
                guard !shown else { return }
                infoEntryID = nil
                // A custom site cannot exist without a link: closing the
                // editor with the URL blanked out removes the row.
                if case .custom(let site) = entry,
                   siteBinding(site).wrappedValue.normalizedURLString.isEmpty {
                    settings.customMediaSites.removeAll { $0.id == site.id }
                }
            }
        ), arrowEdge: .trailing) {
            infoPopover(for: entry)
        }
    }

    // Built-in services show where searches go; custom sites are edited here,
    // keeping the list itself as clean as the built-in rows.
    @ViewBuilder
    private func infoPopover(for entry: MediaEntry) -> some View {
        switch entry {
        case .service(let service):
            VStack(alignment: .leading, spacing: 6) {
                Text(service.name).font(.headline)
                Text("Searches go to:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(service.searchURL("query").absoluteString)
                    .font(.caption)
                    .textSelection(.enabled)
            }
            .padding(12)
            .frame(width: 320, alignment: .leading)
        case .custom(let site):
            let binding = siteBinding(site)
            VStack(alignment: .leading, spacing: 8) {
                TextField("Name", text: binding.name)
                TextField("https://example.com", text: binding.urlString)
                if binding.wrappedValue.hasSearchTemplate {
                    Text("Searches go to: \(binding.wrappedValue.normalizedURLString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                } else if let template = binding.wrappedValue.activeDiscoveredTemplate {
                    Text("Searches go to: \(template)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                } else if let api = binding.wrappedValue.activeDiscoveredAPI {
                    Text("Searches ask the site's own search service and open the top matching title. Learned by typing into the site's search box: \(api.apiTemplate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                } else if let host = binding.wrappedValue.host,
                          linkChecker.discoveringHosts.contains(host) {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Learning this site's search - opening the site, typing into its search box, and checking that a test search really returns titles. Usually under a minute, but a stubborn site can take a few minutes. Until then, searches open the site itself.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if binding.wrappedValue.isWalled {
                    Text("This site checks visitors with a bot-protection wall that Sidekick's hidden browser cannot pass, and Sidekick will not try to defeat it. Searches open the site in your browser (which passes the check) with your search copied, ready to paste into its search box. Add \(CustomMediaSite.queryPlaceholder) to the link if you know the site's search URL.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Sidekick could not learn a way to search this site directly yet, so its result opens the site with your search copied, ready to paste into its search box. Add \(CustomMediaSite.queryPlaceholder) to the link to set a search URL yourself.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Button(role: .destructive) {
                        infoEntryID = nil
                        settings.customMediaSites.removeAll { $0.id == site.id }
                    } label: {
                        Text("Remove Site")
                    }
                    Spacer()
                }
            }
            .textFieldStyle(.roundedBorder)
            .padding(12)
            .frame(width: 320)
        }
    }

    // Rows are rendered from the ordered entry list, so field edits route
    // back to the matching element of the source array by id.
    private func siteBinding(_ site: CustomMediaSite) -> Binding<CustomMediaSite> {
        Binding(
            get: { settings.customMediaSites.first { $0.id == site.id } ?? site },
            set: { updated in
                guard let index = settings.customMediaSites.firstIndex(where: { $0.id == site.id })
                else { return }
                settings.customMediaSites[index] = updated
            }
        )
    }

    private static var checkIntervalDays: Int {
        Int(LinkChecker.checkInterval / 86_400)
    }

    private var lastCheckDescription: String {
        guard let lastRun = linkChecker.lastRun else {
            return "Links are auto-checked every \(Self.checkIntervalDays) days."
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Links checked \(formatter.localizedString(for: lastRun, relativeTo: Date()))."
    }

    // Healthy rows stay clean; only a failed link check earns a marker.
    @ViewBuilder
    private func deadLinkWarning(for site: CustomMediaSite) -> some View {
        if site.isValid,
           let status = linkChecker.status(forKey: site.id.uuidString),
           !status.ok {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.orange)
                .help(status.detail)
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
            Toggle(
                "Keep recent screenshots - the last \(ClipboardStore.screenshotKeepCount) land here automatically (type \"ss\")",
                isOn: $settings.screenshotsToClipboard
            )
        }
    }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions & Tools").font(.headline)
            Text("Sidekick asks for everything it needs at launch and installs its command line tools itself. Green means the feature is ready.")
                .font(.caption)
                .foregroundColor(.secondary)
            SetupStatusList()
            HStack {
                Button("Ask for Missing Permissions Again") {
                    SetupCenter.shared.requestPermissions()
                }
                Button("Retry Tool Install") {
                    SetupCenter.shared.installMissingTools()
                }
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

// Live permission and tool readiness rows. Permission state has no change
// notification API, so the list re-reads it on a slow tick while visible.
private struct SetupStatusList: View {
    @ObservedObject var setup = SetupCenter.shared
    @State private var rows: [SetupCenter.PermissionRow] = SetupCenter.shared.permissionRows()
    private let refresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows) { row in
                HStack(spacing: 8) {
                    statusDot(color: color(for: row.state))
                    Text(row.name)
                    Text(row.detail).font(.caption).foregroundColor(.secondary)
                    Spacer()
                    if row.state == .denied {
                        Button("Open Settings") {
                            setup.openPrivacySettings(anchor: row.settingsAnchor)
                        }
                        .font(.caption)
                    }
                }
            }
            ForEach(SetupCenter.tools, id: \.name) { tool in
                let state = setup.toolStates[tool.name] ?? .missing
                HStack(spacing: 8) {
                    statusDot(color: state == .installed ? .green : (state == .installing ? .yellow : .orange))
                    Text(tool.name)
                    Text(toolCaption(state, purpose: tool.purpose))
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .onReceive(refresh) { _ in rows = setup.permissionRows() }
    }

    private func statusDot(color: Color) -> some View {
        Circle().fill(color).frame(width: 8, height: 8)
    }

    private func color(for state: SetupCenter.PermissionState) -> Color {
        switch state {
        case .granted: return .green
        case .pending: return .yellow
        case .denied: return .orange
        }
    }

    private func toolCaption(_ state: SetupCenter.ToolState, purpose: String) -> String {
        switch state {
        case .installed: return purpose
        case .installing: return "installing now for \(purpose)"
        case .noHomebrew: return "needs Homebrew (brew.sh) for \(purpose)"
        case .missing: return "install pending for \(purpose)"
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
