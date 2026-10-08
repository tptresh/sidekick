import SwiftUI
import AppKit
import Combine
import ServiceManagement
import Carbon.HIToolbox

// One scrolling page in the System Settings grouped style: a section per
// topic, labels on the left, controls on the right, one-line footnotes.
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var clipboard = ClipboardStore.shared
    @ObservedObject var linkChecker = LinkChecker.shared
    @ObservedObject var setup = SetupCenter.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?
    // Which media row's ⓘ popover is open, by entry id.
    @State private var infoEntryID: String?
    // Add Site form state - a row is only created once a link is entered.
    @State private var showingAddSite = false
    @State private var newSiteName = ""
    @State private var newSiteURL = ""
    // Permission state has no change notification API, so it is re-read on a
    // slow tick while the window is open.
    @State private var permissionRows: [SetupCenter.PermissionRow] = SetupCenter.shared.permissionRows()
    private let permissionRefresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            appearanceSection
            shortcutSection
            mediaSection
            clipboardSection
            claudeSection
            permissionsSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, idealWidth: 600, minHeight: 480, idealHeight: 720)
        .onReceive(permissionRefresh) { _ in permissionRows = setup.permissionRows() }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section {
            LabeledContent("Theme") {
                HStack(spacing: 10) {
                    ForEach(HeroTheme.allCases, id: \.self) { theme in
                        ThemePreviewButton(
                            theme: theme,
                            isSelected: settings.theme == theme,
                            select: { settings.theme = theme }
                        )
                    }
                }
            }
            Toggle("Switch Light and Dark automatically", isOn: $settings.autoAppearance)
            if settings.autoAppearance {
                DatePicker("Light Mode at", selection: minuteBinding(\.lightModeMinute), displayedComponents: .hourAndMinute)
                DatePicker("Dark Mode at", selection: minuteBinding(\.darkModeMinute), displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Appearance")
        } footer: {
            footnote("A manual switch in between stays until the next scheduled time.")
        }
    }

    // MARK: - Shortcut & startup

    private var shortcutSection: some View {
        Section {
            LabeledContent("Open Sidekick with") {
                HotKeyRecorder(combo: $settings.hotKey)
                    .frame(width: 150, height: 24)
            }
            if let active = settings.activeHotKey, active != settings.hotKey {
                Label("\(settings.hotKey.displayString) is taken, so Sidekick is using \(active.displayString)",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }
            Toggle("Launch at login", isOn: $launchAtLogin)
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
                Text(launchAtLoginError).font(.callout).foregroundStyle(.orange)
            }
        } header: {
            Text("Shortcut & Startup")
        } footer: {
            footnote(settings.hotKey == .commandSpace
                ? "Click the box and press a new combination. For ⌘Space, first turn off Spotlight's shortcut in System Settings > Keyboard > Keyboard Shortcuts."
                : "Click the box and press a new combination.")
        }
    }

    // MARK: - Media sites

    private var mediaSection: some View {
        Section {
            siteHealthRow
            ForEach(settings.orderedMediaEntries) { entry in
                mediaRow(for: entry)
                    .contextMenu { moveMenu(for: entry) }
            }
            .onMove { source, destination in
                settings.moveMediaEntries(fromOffsets: source, toOffset: destination)
            }
            HStack {
                Button("Add Site…") { showingAddSite = true }
                    .popover(isPresented: $showingAddSite, arrowEdge: .bottom) { addSitePopover }
                Spacer()
                if linkChecker.isRunning {
                    ProgressView().controlSize(.small)
                    Text("Checking…").foregroundStyle(.secondary)
                } else {
                    Text(lastCheckDescription).foregroundStyle(.secondary).font(.callout)
                    Button("Check Now") {
                        linkChecker.checkNow()
                        linkChecker.retryFailedDiscoveries()
                    }
                }
            }
        } header: {
            Text("Media Sites")
        } footer: {
            footnote("Typing a show name offers it on each site that is on. Drag or right-click to reorder; ⓘ shows or edits a site's link.")
        }
    }

    // One summary line: offline, failing sites, or all clear.
    @ViewBuilder
    private var siteHealthRow: some View {
        let failing = failingSiteNames
        if linkChecker.lastCheckLooksOffline {
            healthLine(
                symbol: "wifi.slash", tint: .secondary,
                title: "Could not check your sites",
                detail: "This Mac looked offline. The last real results are shown."
            )
        } else if !failing.isEmpty {
            healthLine(
                symbol: "exclamationmark.triangle.fill", tint: .orange,
                title: failing.count == 1 ? "\(failing[0]) is not responding" : "\(failing.count) sites are not responding",
                detail: failing.count == 1
                    ? "It may be down or have moved. Hover its dot for the reason."
                    : failing.joined(separator: ", ") + ". Hover a dot for the reason."
            )
        } else if linkChecker.lastRun != nil {
            healthLine(
                symbol: "checkmark.circle.fill", tint: .green,
                title: "All sites are reachable", detail: nil
            )
        }
    }

    private func healthLine(symbol: String, tint: Color, title: String, detail: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                if let detail {
                    Text(detail).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func moveMenu(for entry: MediaEntry) -> some View {
        let entries = settings.orderedMediaEntries
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            Button("Move Up") {
                settings.moveMediaEntries(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
            }
            .disabled(index == 0)
            Button("Move Down") {
                settings.moveMediaEntries(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
            }
            .disabled(index == entries.count - 1)
        }
    }

    private var addSitePopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Name (optional)", text: $newSiteName)
            TextField("https://example.com", text: $newSiteURL)
            Text("Sidekick then learns the site's own search, usually within a minute.")
                .font(.caption)
                .foregroundStyle(.secondary)
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

    private func mediaRow(for entry: MediaEntry) -> some View {
        HStack(spacing: 10) {
            statusDot(for: entry)
            switch entry {
            case .service(let service):
                Text(service.name)
                Spacer()
                infoButton(for: entry)
                Toggle("", isOn: Binding(
                    get: { settings.enabledServices.contains(service.id) },
                    set: { enabled in
                        if enabled {
                            settings.enabledServices.insert(service.id)
                        } else {
                            settings.enabledServices.remove(service.id)
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            case .custom(let site):
                let binding = siteBinding(site)
                Text(binding.wrappedValue.displayName)
                if let host = binding.wrappedValue.host,
                   linkChecker.discoveringHosts.contains(host) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.6)
                        .help("Learning this site's search - can take a few minutes")
                }
                Spacer()
                infoButton(for: entry)
                Toggle("", isOn: binding.enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Site health

    // Names of enabled sites whose last check failed, in list order.
    private var failingSiteNames: [String] {
        settings.orderedMediaEntries.compactMap { entry in
            guard let status = siteStatus(for: entry), !status.ok else { return nil }
            return entryName(entry)
        }
    }

    private func entryName(_ entry: MediaEntry) -> String {
        switch entry {
        case .service(let service): return service.name
        case .custom(let site): return siteBinding(site).wrappedValue.displayName
        }
    }

    private func siteStatus(for entry: MediaEntry) -> LinkChecker.Status? {
        switch entry {
        case .service(let service):
            guard settings.enabledServices.contains(service.id) else { return nil }
            return linkChecker.status(forKey: service.id)
        case .custom(let site):
            let current = siteBinding(site).wrappedValue
            guard current.enabled, current.isValid else { return nil }
            return linkChecker.status(forKey: site.id.uuidString)
        }
    }

    // Green when the last check passed, orange when it failed, grey when the
    // site is off or has not been checked yet.
    private func statusDot(for entry: MediaEntry) -> some View {
        let status = siteStatus(for: entry)
        let color: Color
        let help: String
        if let status {
            color = status.ok ? .green : .orange
            help = status.ok ? "Reachable at the last check" : status.detail
        } else {
            color = Color.secondary.opacity(0.4)
            help = "Not checked yet"
        }
        return Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .help(help)
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

    // Bridges a minutes-after-midnight setting to a DatePicker's Date.
    private func minuteBinding(_ keyPath: ReferenceWritableKeyPath<SettingsStore, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minute = settings[keyPath: keyPath]
                return Calendar.current.date(
                    bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()
                ) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                settings[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    // MARK: - Clipboard

    private var clipboardSection: some View {
        Section {
            Stepper(value: $settings.clipboardLimit, in: 10...1000, step: 10) {
                LabeledContent("Keep up to", value: "\(settings.clipboardLimit) items")
            }
            Toggle("Keep recent screenshots", isOn: $settings.screenshotsToClipboard)
            LabeledContent("Holding \(clipboard.entries.count) item\(clipboard.entries.count == 1 ? "" : "s")") {
                Button("Clear History", role: .destructive) { clipboard.clear() }
            }
        } header: {
            Text("Clipboard")
        } footer: {
            footnote("Type \"clip\" to browse history, or \"ss\" for the last \(ClipboardStore.screenshotKeepCount) screenshots.")
        }
    }

    // MARK: - Claude Code

    private var claudeSection: some View {
        Section {
            LabeledContent("Default folder") {
                HStack(spacing: 8) {
                    Text(abbreviatedPath(settings.claudeDirectory))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
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
        } header: {
            Text("Claude Code")
        } footer: {
            footnote("\"claude <task>\" starts a Claude Code session in this folder.")
        }
    }

    private func abbreviatedPath(_ path: String) -> String {
        guard !path.isEmpty else { return "Not set" }
        return (path as NSString).abbreviatingWithTildeInPath
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        Section {
            ForEach(permissionRows) { row in
                LabeledContent {
                    permissionStatus(row)
                } label: {
                    Text(row.name)
                    Text(row.detail)
                }
            }
            ForEach(SetupCenter.tools, id: \.name) { tool in
                LabeledContent {
                    toolStatus(setup.toolStates[tool.name] ?? .missing)
                } label: {
                    Text(tool.name)
                    Text("for \(tool.purpose)")
                }
            }
            HStack {
                Spacer()
                Button("Ask Again") { SetupCenter.shared.requestPermissions() }
                Button("Retry Install") { SetupCenter.shared.installMissingTools() }
            }
        } header: {
            Text("Permissions")
        } footer: {
            footnote("Sidekick asks for these at launch and installs its own tools.")
        }
    }

    @ViewBuilder
    private func permissionStatus(_ row: SetupCenter.PermissionRow) -> some View {
        switch row.state {
        case .granted:
            Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .pending:
            Text("Not asked yet").foregroundStyle(.secondary)
        case .denied:
            Button("Open Settings") { setup.openPrivacySettings(anchor: row.settingsAnchor) }
        }
    }

    @ViewBuilder
    private func toolStatus(_ state: SetupCenter.ToolState) -> some View {
        switch state {
        case .installed:
            Label("Installed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .installing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Installing").foregroundStyle(.secondary)
            }
        case .noHomebrew:
            Text("Needs Homebrew").foregroundStyle(.orange)
        case .missing:
            Text("Not installed yet").foregroundStyle(.secondary)
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.palette.background)
                        .frame(width: 96, height: 56)
                    Image(nsImage: StatusIcons.watermark(
                        for: theme, size: 28, color: NSColor(theme.palette.accent)
                    ))
                    .resizable()
                    .frame(width: 28, height: 28)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                                lineWidth: isSelected ? 2.5 : 1)
                )
                Text(theme.displayName)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.displayName) theme")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
