import SwiftUI
import AppKit
import Combine
import ServiceManagement
import Carbon.HIToolbox

// One scrolling page of Liquid Glass cards over a dark backdrop: a section per
// topic, labels on the left, controls on the right, a footnote under each card.
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    // Tokens are injected here so SettingsPage reads the themed environment.
    var body: some View {
        SettingsPage(settings: settings).futuristicTheme(settings.theme)
    }
}

private struct SettingsPage: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var clipboard = ClipboardStore.shared
    @ObservedObject var linkChecker = LinkChecker.shared
    @ObservedObject var setup = SetupCenter.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?
    // Which media row's info popover is open, by entry id.
    @State private var infoEntryID: String?
    // Add Site form state - a row is only created once a link is entered.
    @State private var showingAddSite = false
    @State private var newSiteName = ""
    @State private var newSiteURL = ""
    @State private var addHovering = false
    // Permission state has no change notification API, so it is re-read on a
    // slow tick while the window is open.
    @State private var permissionRows: [SetupCenter.PermissionRow] = SetupCenter.shared.permissionRows()
    private let permissionRefresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    @Environment(\.fxTokens) private var fx

    private typealias Space = FuturisticStyle.Space
    private typealias Radius = FuturisticStyle.Radius

    var body: some View {
        ScrollView {
            GlassGroup(spacing: Space.l) {
                VStack(spacing: Space.xl) {
                    appearanceSection
                    shortcutSection
                    mediaSection
                    weatherSection
                    clipboardSection
                    claudeSection
                    permissionsSection
                }
                .padding(Space.xl)
            }
        }
        .background(alignment: .top) {
            // A faint red wash at the top gives the glass something to bend.
            ZStack(alignment: .top) {
                Color(nsColor: .windowBackgroundColor)
                RadialGradient(colors: [fx.ambient, .clear], center: .top, startRadius: 0, endRadius: 420)
                    .frame(height: 420)
            }
            .ignoresSafeArea()
        }
        .frame(minWidth: 520, idealWidth: 600, minHeight: 480, idealHeight: 720)
        .onReceive(permissionRefresh) { _ in permissionRows = setup.permissionRows() }
    }

    // MARK: - Row building blocks

    // A 36pt row: label on the left, control on the right.
    private func prefsRow<Control: View>(
        _ label: String, detail: String? = nil, @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: Space.m) {
            VStack(alignment: .leading, spacing: 1) {
                // Labels never wrap or squeeze; a wide control gives way first.
                Text(label).font(.system(size: 13)).lineLimit(1).fixedSize()
                if let detail {
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Space.s)
            control()
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, detail == nil ? 0 : 4)
        .frame(minHeight: 36)
    }

    private var rowLine: some View { RowLine() }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        prefsRow(label) {
            Toggle(label, isOn: isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Island(label: "Appearance",
               footnote: "A manual switch in between stays until the next scheduled time.",
               padding: 0) {
            VStack(spacing: 0) {
                toggleRow("Switch Light and Dark automatically", isOn: $settings.autoAppearance)
                if settings.autoAppearance {
                    rowLine
                    prefsRow("Light Mode at") {
                        DatePicker("Light Mode at", selection: minuteBinding(\.lightModeMinute),
                                   displayedComponents: .hourAndMinute).labelsHidden()
                    }
                    rowLine
                    prefsRow("Dark Mode at") {
                        DatePicker("Dark Mode at", selection: minuteBinding(\.darkModeMinute),
                                   displayedComponents: .hourAndMinute).labelsHidden()
                    }
                }
            }
        }
    }

    // MARK: - Shortcut & startup

    private var shortcutSection: some View {
        Island(label: "Shortcut & Startup",
               footnote: settings.hotKey == .commandSpace
                ? "Click the box and press a new combination. For ⌘Space, first turn off Spotlight's shortcut in System Settings > Keyboard > Keyboard Shortcuts."
                : "Click the box and press a new combination.",
               padding: 0) {
            VStack(spacing: 0) {
                prefsRow("Open Sidekick with") {
                    HotKeyRecorder(combo: $settings.hotKey, accent: NSColor(fx.accent)).frame(width: 150, height: 26)
                }
                if let active = settings.activeHotKey, active != settings.hotKey {
                    rowLine
                    HStack(spacing: Space.s) {
                        Chip("Using \(active.displayString)", tone: .warning,
                             symbol: "exclamationmark.triangle.fill")
                        Text("\(settings.hotKey.displayString) is taken, so Sidekick is using \(active.displayString)")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Space.m)
                    .padding(.vertical, Space.s)
                }
                rowLine
                toggleRow("Launch at login", isOn: $launchAtLogin)
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
                    Text(launchAtLoginError)
                        .font(.system(size: 11)).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Space.m).padding(.bottom, Space.s)
                }
            }
        }
    }

    // MARK: - Media sites

    private var mediaSection: some View {
        let entries = settings.orderedMediaEntries
        return Island(label: "Media Sites",
                      footnote: "Typing a show name offers it on each site that is on. Drag or right-click to reorder; the info button shows or edits a site's link.",
                      padding: Space.m) {
            VStack(spacing: Space.s) {
                siteHealthStrip
                List {
                    ForEach(entries) { entry in
                        siteRow(for: entry)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: Space.xs, trailing: 0))
                            .listRowBackground(Color.clear)
                            .contextMenu { moveMenu(for: entry) }
                    }
                    .onMove { source, destination in
                        settings.moveMediaEntries(fromOffsets: source, toOffset: destination)
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .frame(height: CGFloat(entries.count) * 48)
                addSiteTile
                siteStatusLine
            }
        }
    }

    private enum StripTone { case neutral, warning, success }

    // One summary strip: offline, failing sites, or all clear.
    @ViewBuilder
    private var siteHealthStrip: some View {
        let failing = failingSiteNames
        if linkChecker.lastCheckLooksOffline {
            healthStrip(
                symbol: "wifi.slash", tone: .neutral,
                title: "Could not check your sites",
                detail: "This Mac looked offline. The last real results are shown."
            )
        } else if !failing.isEmpty {
            healthStrip(
                symbol: "exclamationmark.triangle.fill", tone: .warning,
                title: failing.count == 1 ? "\(failing[0]) is not responding" : "\(failing.count) sites are not responding",
                detail: failing.count == 1
                    ? "It may be down or have moved. Hover its dot for the reason."
                    : failing.joined(separator: ", ") + ". Hover a dot for the reason."
            )
        } else if linkChecker.lastRun != nil {
            healthStrip(
                symbol: "checkmark.circle.fill", tone: .success,
                title: "All sites are reachable", detail: nil
            )
        }
    }

    private func healthStrip(symbol: String, tone: StripTone, title: String, detail: String?) -> some View {
        let color: Color = tone == .warning ? .orange : (tone == .success ? .green : .secondary)
        return HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Image(systemName: symbol).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                if let detail {
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Space.s + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill((tone == .neutral ? Color.white : color).opacity(tone == .neutral ? 0.06 : 0.12))
        )
        .accessibilityElement(children: .combine)
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

    private var addSiteTile: some View {
        Button { showingAddSite = true } label: {
            HStack(spacing: Space.s) {
                Image(systemName: "plus.circle")
                Text("Add Site").font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(addHovering ? AnyShapeStyle(fx.accentText) : AnyShapeStyle(.secondary))
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(fx.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { addHovering = $0 }
        .popover(isPresented: $showingAddSite, arrowEdge: .bottom) { addSitePopover }
    }

    private var siteStatusLine: some View {
        HStack(spacing: Space.s) {
            if linkChecker.isRunning {
                ProgressView().controlSize(.small)
                Text("Checking…").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                Text(lastCheckDescription)
                    .font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
                Spacer(minLength: Space.s)
                PillButton("Check Now", symbol: "arrow.clockwise") {
                    linkChecker.checkNow()
                    linkChecker.retryFailedDiscoveries()
                }
            }
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

    private func siteRow(for entry: MediaEntry) -> some View {
        let name = entryName(entry)
        let isOn = entryEnabledBinding(entry)
        let status = siteStatus(for: entry)
        let learning = isLearning(entry) && isOn.wrappedValue
        return SiteRowChrome(dimmed: !isOn.wrappedValue) {
            Monogram(name, active: isOn.wrappedValue)
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(0)
            Spacer(minLength: Space.s)
            if isOn.wrappedValue {
                if learning {
                    ProgressView().controlSize(.small)
                    Chip("Learning search", tone: .accent).layoutPriority(1)
                } else if let status {
                    if status.ok {
                        StatusDot(tone: .healthy, help: "Reachable at the last check")
                    } else {
                        StatusDot(tone: .failing, help: status.detail)
                        Chip("Not responding", tone: .warning).layoutPriority(1)
                    }
                } else {
                    Chip("Not checked", tone: .neutral).layoutPriority(1)
                }
            }
            infoButton(for: entry)
            Toggle(name, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(siteAccessibilityLabel(name: name, on: isOn.wrappedValue, status: status, learning: learning))
    }

    private func siteAccessibilityLabel(name: String, on: Bool, status: LinkChecker.Status?, learning: Bool) -> String {
        guard on else { return "\(name), off" }
        if learning { return "\(name), on, learning search" }
        guard let status else { return "\(name), on, not checked" }
        return status.ok ? "\(name), on, reachable" : "\(name), on, not responding"
    }

    private func entryEnabledBinding(_ entry: MediaEntry) -> Binding<Bool> {
        switch entry {
        case .service(let service):
            return Binding(
                get: { settings.enabledServices.contains(service.id) },
                set: { enabled in
                    if enabled {
                        settings.enabledServices.insert(service.id)
                    } else {
                        settings.enabledServices.remove(service.id)
                    }
                }
            )
        case .custom(let site):
            return siteBinding(site).enabled
        }
    }

    private func isLearning(_ entry: MediaEntry) -> Bool {
        guard case .custom(let site) = entry,
              let host = siteBinding(site).wrappedValue.host else { return false }
        return linkChecker.discoveringHosts.contains(host)
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

    private func infoButton(for entry: MediaEntry) -> some View {
        InfoButton {
            infoEntryID = entry.id
        }
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

    // MARK: - Weather

    private var weatherSection: some View {
        Island(label: "Weather",
               footnote: "Leave empty to use your Mac's location. Otherwise weather follows this city.",
               padding: 0) {
            prefsRow("City") {
                TextField("Automatic", text: $settings.weatherCity)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .frame(width: 220)
            }
        }
    }

    // MARK: - Clipboard

    private var clipboardSection: some View {
        Island(label: "Clipboard",
               footnote: "Type \"clip\" to browse history, or \"ss\" for the last \(ClipboardStore.screenshotKeepCount) screenshots.",
               padding: 0) {
            VStack(spacing: 0) {
                prefsRow("Keep up to") {
                    HStack(spacing: Space.s) {
                        // Fixed width so the stepper does not shift as the count grows.
                        Text("\(settings.clipboardLimit) items")
                            .font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
                            .frame(minWidth: 72, alignment: .trailing)
                        Stepper("Keep up to", value: $settings.clipboardLimit, in: 10...1000, step: 10)
                            .labelsHidden()
                    }
                }
                rowLine
                toggleRow("Keep recent screenshots", isOn: $settings.screenshotsToClipboard)
                rowLine
                prefsRow("Holding \(clipboard.entries.count) item\(clipboard.entries.count == 1 ? "" : "s")") {
                    PillButton("Clear History", tone: .destructive) { clipboard.clear() }
                }
            }
        }
    }

    // MARK: - Claude Code

    private var claudeSection: some View {
        Island(label: "Claude Code",
               footnote: "\"claude <task>\" starts a Claude Code session in this folder.",
               padding: 0) {
            prefsRow("Default folder") {
                HStack(spacing: Space.s) {
                    Text(abbreviatedPath(settings.claudeDirectory))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    PillButton("Choose…") {
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
    }

    private func abbreviatedPath(_ path: String) -> String {
        guard !path.isEmpty else { return "Not set" }
        return (path as NSString).abbreviatingWithTildeInPath
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        Island(label: "Permissions",
               footnote: "Sidekick asks for these at launch and installs its own tools.",
               padding: 0) {
            VStack(spacing: 0) {
                ForEach(permissionRows) { row in
                    prefsRow(row.name, detail: row.detail) { permissionStatus(row) }
                    rowLine
                }
                ForEach(SetupCenter.tools, id: \.name) { tool in
                    prefsRow(tool.name, detail: "for \(tool.purpose)") {
                        toolStatus(setup.toolStates[tool.name] ?? .missing)
                    }
                    rowLine
                }
                HStack(spacing: Space.s) {
                    Spacer()
                    PillButton("Ask Again") { SetupCenter.shared.requestPermissions() }
                    PillButton("Retry Install") { SetupCenter.shared.installMissingTools() }
                }
                .padding(.horizontal, Space.m)
                .padding(.vertical, Space.s)
            }
        }
    }

    @ViewBuilder
    private func permissionStatus(_ row: SetupCenter.PermissionRow) -> some View {
        switch row.state {
        case .granted:
            Chip("Allowed", tone: .success, symbol: "checkmark.circle.fill")
        case .pending:
            Chip("Not asked yet", tone: .neutral)
        case .denied:
            PillButton("Open Settings") { setup.openPrivacySettings(anchor: row.settingsAnchor) }
        }
    }

    @ViewBuilder
    private func toolStatus(_ state: SetupCenter.ToolState) -> some View {
        switch state {
        case .installed:
            Chip("Installed", tone: .success)
        case .installing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Installing").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        case .noHomebrew:
            Chip("Needs Homebrew", tone: .warning)
        case .missing:
            Chip("Not installed yet", tone: .neutral)
        }
    }
}

// MARK: - Site row pieces

// The 44pt card behind one media site: fill, hover and Reduce Motion handling.
private struct SiteRowChrome<Content: View>: View {
    let dimmed: Bool
    @ViewBuilder var content: () -> Content
    @Environment(\.fxTokens) private var fx
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) { content() }
            .padding(.horizontal, FuturisticStyle.Space.m)
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: FuturisticStyle.Radius.md, style: .continuous)
                    .fill(hovering ? fx.fillHover : fx.fill)
            )
            .opacity(dimmed ? 0.55 : 1)
            .onHover { hovering = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: hovering)
    }
}

// Always a real Button so keyboard users reach it; brighter on hover or focus.
private struct InfoButton: View {
    let action: () -> Void
    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: "info.circle")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .opacity(hovering || focused ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focused)
        .onHover { hovering = $0 }
        .help("Show this site's link")
        .accessibilityLabel("Site link")
    }
}

// Click to focus, then press a key combo. Esc cancels, Delete resets to Cmd+Space.
private struct HotKeyRecorder: NSViewRepresentable {
    @Binding var combo: HotKeyCombo
    let accent: NSColor

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.accent = accent
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
        var accent: NSColor = .controlAccentColor
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
                needsDisplay = true
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
            needsDisplay = true
        }

        override func draw(_ dirtyRect: NSRect) {
            let inset = bounds.insetBy(dx: 1, dy: 1)
            let background = NSBezierPath(roundedRect: inset, xRadius: inset.height / 2, yRadius: inset.height / 2)
            (recording ? accent.withAlphaComponent(0.22) : NSColor.white.withAlphaComponent(0.07)).setFill()
            background.fill()
            (recording ? accent : NSColor.white.withAlphaComponent(0.12)).setStroke()
            background.lineWidth = recording ? 1.5 : 1
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
