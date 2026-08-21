import AppKit
import ApplicationServices
import Contacts
import EventKit

// One launch-time pass that makes every feature usable without the user
// discovering a missing piece mid-command:
//  - requests every TCC permission Sidekick's features need (Accessibility,
//    Contacts, Calendar, Reminders, and the Automation consents for apps that
//    are already running), instead of each feature prompting on first use.
//    Rebuilds reset these grants (ad-hoc signing), so the pass runs on every
//    launch; it only prompts for grants that are actually missing.
//  - installs the two Homebrew tools some commands shell out to (blueutil for
//    the Bluetooth toggle, brightness for brightness control) and tells the
//    user what was installed.
final class SetupCenter: ObservableObject {
    static let shared = SetupCenter()

    enum ToolState: Equatable {
        case installed
        case installing
        case missing        // Homebrew exists but the install has not succeeded
        case noHomebrew
    }

    struct Tool {
        let name: String        // Homebrew formula and binary name
        let purpose: String     // shown in Settings and install alerts
    }

    static let tools: [Tool] = [
        Tool(name: "blueutil", purpose: "the Bluetooth toggle"),
        Tool(name: "brightness", purpose: "brightness control"),
    ]

    @Published private(set) var toolStates: [String: ToolState] = [:]

    private let installQueue = DispatchQueue(label: "spidey.setup.install", qos: .utility)
    private let automationQueue = DispatchQueue(label: "spidey.setup.automation", qos: .utility)

    private init() {
        for tool in Self.tools {
            toolStates[tool.name] = Self.binaryPath(for: tool.name) != nil ? .installed : .missing
        }
    }

    func runAtLaunch() {
        installMissingTools()
        requestPermissions()
    }

    // MARK: - Homebrew tools

    static func binaryPath(for name: String) -> String? {
        ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static var brewPath: String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func installMissingTools() {
        let missing = Self.tools.filter { Self.binaryPath(for: $0.name) == nil }
        guard !missing.isEmpty else {
            for tool in Self.tools { setState(.installed, for: tool.name) }
            return
        }
        guard let brew = Self.brewPath else {
            for tool in missing { setState(.noHomebrew, for: tool.name) }
            notifyOnce(key: "setupNotifiedNoHomebrew",
                       title: "Some commands need Homebrew",
                       body: missing.map { "\($0.name) (for \($0.purpose))" }.joined(separator: " and ")
                           + " could not be installed because Homebrew is not on this Mac. "
                           + "Install it from brew.sh and Sidekick will add the rest automatically on the next launch.")
            return
        }
        for tool in missing { setState(.installing, for: tool.name) }
        installQueue.async { [weak self] in
            var installed: [Tool] = []
            var failed: [Tool] = []
            for tool in missing {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: brew)
                process.arguments = ["install", tool.name]
                var env = ProcessInfo.processInfo.environment
                env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
                env["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
                process.environment = env
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    NSLog("Spidey setup: could not run brew install \(tool.name): \(error)")
                }
                if Self.binaryPath(for: tool.name) != nil {
                    installed.append(tool)
                } else {
                    failed.append(tool)
                }
            }
            DispatchQueue.main.async {
                for tool in installed { self?.setState(.installed, for: tool.name) }
                for tool in failed { self?.setState(.missing, for: tool.name) }
                // An open panel showing the "needs blueutil" fallback row
                // re-renders into the real toggle right away.
                NotificationCenter.default.post(name: .spideyFaviconLoaded, object: nil)
                if !installed.isEmpty {
                    self?.notify(
                        title: "Sidekick finished setting up",
                        body: "Installed " + installed.map { "\($0.name) for \($0.purpose)" }
                            .joined(separator: " and ") + ". Those commands work now."
                    )
                }
                if !failed.isEmpty {
                    self?.notifyOnce(
                        key: "setupNotifiedInstallFailed-" + failed.map(\.name).joined(separator: ","),
                        title: "Sidekick could not install some tools",
                        body: failed.map(\.name).joined(separator: " and ")
                            + " failed to install with Homebrew. It will retry on the next launch; "
                            + "you can also run: brew install " + failed.map(\.name).joined(separator: " ")
                    )
                }
            }
        }
    }

    // Fallback-row subtitle for a feature whose tool is not usable yet.
    func missingToolHint(_ name: String) -> String {
        switch toolStates[name] ?? .missing {
        case .installing:
            return "Sidekick is installing \(name) in the background - try again in a moment"
        case .noHomebrew:
            return "Needs \(name); install Homebrew (brew.sh) and Sidekick adds it automatically"
        default:
            return "Needs \(name); Sidekick will retry the install on next launch"
        }
    }

    // MARK: - Permissions

    // Grants only stick to a bundled, signed app; a bare `swift build` binary
    // would burn the prompts without gaining anything.
    private var canHoldPermissions: Bool { Bundle.main.bundleIdentifier != nil }

    func requestPermissions() {
        guard canHoldPermissions else { return }
        if !AXIsProcessTrusted() {
            WindowProvider.requestPermission()
        }
        requestContacts { [weak self] in
            self?.requestEventKit(.event) {
                self?.requestEventKit(.reminder) {}
            }
        }
        primeAutomationConsents()
    }

    private func requestContacts(then next: @escaping () -> Void) {
        guard CNContactStore.authorizationStatus(for: .contacts) == .notDetermined else {
            next()
            return
        }
        CNContactStore().requestAccess(for: .contacts) { _, _ in
            // Load the address book as soon as the grant lands, so the first
            // name typed after setup is already searchable.
            ContactIndex.shared.reload()
            DispatchQueue.main.async(execute: next)
        }
    }

    private func requestEventKit(_ type: EKEntityType, then next: @escaping () -> Void) {
        guard EKEventStore.authorizationStatus(for: type) == .notDetermined else {
            next()
            return
        }
        let store = EKEventStore()
        let done: (Bool, Error?) -> Void = { _, _ in
            // Keep the store alive until the request resolves.
            _ = store
            DispatchQueue.main.async(execute: next)
        }
        if #available(macOS 14.0, *) {
            if type == .event {
                store.requestFullAccessToEvents(completion: done)
            } else {
                store.requestFullAccessToReminders(completion: done)
            }
        } else {
            store.requestAccess(to: type, completion: done)
        }
    }

    // Sends one harmless Apple Event to each app Sidekick automates, so the
    // "Sidekick wants to control ..." consents appear now rather than the
    // first time a command runs. System Events and Finder are always alive;
    // players and browsers are only primed while running, because targeting
    // them otherwise would launch them.
    private func primeAutomationConsents() {
        // Each script must round-trip a real Apple Event: asking for `name`
        // (or other application properties) is answered locally by
        // AppleScript from the target's Info.plist, sends nothing, and so
        // never triggers the consent.
        var targets: [(script: String, bundleID: String?)] = [
            ("tell application \"System Events\" to count processes", nil),
            ("tell application \"Finder\" to count windows", nil),
        ]
        let optional: [(String, String)] = [
            ("tell application \"Music\" to get player state", "com.apple.Music"),
            ("tell application \"Spotify\" to get player state", "com.spotify.client"),
            ("tell application \"Brave Browser\" to count windows", "com.brave.Browser"),
            ("tell application \"Google Chrome\" to count windows", "com.google.Chrome"),
            ("tell application \"Terminal\" to count windows", "com.apple.Terminal"),
        ]
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        for (script, bundleID) in optional where running.contains(bundleID) {
            targets.append((script, bundleID))
        }
        automationQueue.async {
            for target in targets {
                // osascript as a child keeps a pending consent dialog from
                // ever blocking the app; consent attributes to Sidekick as
                // the responsible process. The long timeout is the user
                // taking their time on the dialog, not a hang.
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", target.script]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                guard (try? process.run()) != nil else { continue }
                let deadline = Date().addingTimeInterval(120)
                while process.isRunning, Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.25)
                }
                if process.isRunning { process.terminate() }
            }
        }
    }

    // MARK: - Status for the Preferences window

    enum PermissionState {
        case granted
        case pending    // not asked yet, or the user dismissed the prompt
        case denied
    }

    struct PermissionRow: Identifiable {
        let id: String
        let name: String
        let detail: String
        let state: PermissionState
        // Deep link into the matching Privacy pane for denied grants.
        let settingsAnchor: String
    }

    func permissionRows() -> [PermissionRow] {
        var rows: [PermissionRow] = []
        rows.append(PermissionRow(
            id: "ax", name: "Accessibility",
            detail: "window switching, menu search, window layout, Find My",
            state: AXIsProcessTrusted() ? .granted : .pending,
            settingsAnchor: "Privacy_Accessibility"
        ))
        let contacts: PermissionState
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized: contacts = .granted
        case .notDetermined: contacts = .pending
        default: contacts = .denied
        }
        rows.append(PermissionRow(
            id: "contacts", name: "Contacts",
            detail: "copy a phone number or email by typing a name",
            state: contacts, settingsAnchor: "Privacy_Contacts"
        ))
        rows.append(PermissionRow(
            id: "calendar", name: "Calendar",
            detail: "today's events and your next event",
            state: eventKitState(.event), settingsAnchor: "Privacy_Calendars"
        ))
        rows.append(PermissionRow(
            id: "reminders", name: "Reminders",
            detail: "\"remind me to ...\" commands",
            state: eventKitState(.reminder), settingsAnchor: "Privacy_Reminders"
        ))
        return rows
    }

    private func eventKitState(_ type: EKEntityType) -> PermissionState {
        let status = EKEventStore.authorizationStatus(for: type)
        if #available(macOS 14.0, *), status == .fullAccess { return .granted }
        switch status {
        case .authorized: return .granted
        case .notDetermined: return .pending
        default: return .denied
        }
    }

    func openPrivacySettings(anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - User-facing notices

    private func setState(_ state: ToolState, for name: String) {
        if Thread.isMainThread {
            toolStates[name] = state
        } else {
            DispatchQueue.main.async { self.toolStates[name] = state }
        }
    }

    private func notifyOnce(key: String, title: String, body: String) {
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        notify(title: title, body: body)
    }

    private func notify(title: String, body: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = body
            alert.alertStyle = .informational
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}
