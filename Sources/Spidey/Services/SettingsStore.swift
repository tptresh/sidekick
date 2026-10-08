import Foundation
import Combine
import Carbon.HIToolbox

struct HotKeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let commandSpace = HotKeyCombo(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(cmdKey))
    static let optionSpace = HotKeyCombo(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(optionKey))

    var displayString: String {
        var parts = ""
        if carbonModifiers & UInt32(controlKey) != 0 { parts += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { parts += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { parts += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { parts += "⌘" }
        return parts + HotKeyCombo.keyName(for: keyCode)
    }

    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Escape: return "Esc"
        case kVK_UpArrow: return "Up"
        case kVK_DownArrow: return "Down"
        case kVK_LeftArrow: return "Left"
        case kVK_RightArrow: return "Right"
        default: break
        }
        // Translate the virtual key code through the current keyboard layout.
        guard let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData)
        else { return "Key \(keyCode)" }
        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> OSStatus in
            let layout = bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress!
            return UCKeyTranslate(
                layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState, chars.count, &length, &chars
            )
        }
        guard status == noErr, length > 0 else { return "Key \(keyCode)" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}

struct StreamingService: Identifiable {
    let id: String
    let name: String
    let searchURL: (String) -> URL

    static let all: [StreamingService] = [
        StreamingService(id: "netflix", name: "Netflix") { q in
            URL(string: "https://www.netflix.com/search?q=\(q)")!
        },
        StreamingService(id: "crunchyroll", name: "Crunchyroll") { q in
            URL(string: "https://www.crunchyroll.com/search?q=\(q)")!
        },
        StreamingService(id: "primevideo", name: "Prime Video") { q in
            URL(string: "https://www.primevideo.com/search/ref=atv_nb_sr?phrase=\(q)")!
        },
        StreamingService(id: "disneyplus", name: "Disney+") { q in
            URL(string: "https://www.disneyplus.com/browse/search?q=\(q)")!
        },
    ]
}

// One row in the unified media list: a built-in streaming service or a
// user-added custom site, shown and searched in the user's chosen order.
enum MediaEntry: Identifiable {
    case service(StreamingService)
    case custom(CustomMediaSite)

    var id: String {
        switch self {
        case .service(let service): return service.id
        case .custom(let site): return site.id.uuidString
        }
    }
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    @Published var theme: HeroTheme {
        didSet { defaults.set(theme.rawValue, forKey: "theme") }
    }
    @Published var enabledServices: Set<String> {
        didSet { defaults.set(Array(enabledServices), forKey: "enabledServices") }
    }
    @Published var customMediaSites: [CustomMediaSite] {
        didSet {
            if let data = try? JSONEncoder().encode(customMediaSites) {
                defaults.set(data, forKey: "customMediaSites")
            }
        }
    }
    // Ids (service ids and custom-site UUIDs) in the user's display order.
    @Published var mediaOrder: [String] {
        didSet { defaults.set(mediaOrder, forKey: "mediaOrder") }
    }
    @Published var claudeDirectory: String {
        didSet { defaults.set(claudeDirectory, forKey: "claudeDirectory") }
    }
    @Published var clipboardLimit: Int {
        didSet { defaults.set(clipboardLimit, forKey: "clipboardLimit") }
    }
    @Published var screenshotsToClipboard: Bool {
        didSet { defaults.set(screenshotsToClipboard, forKey: "screenshotsToClipboard") }
    }
    @Published var hotKey: HotKeyCombo {
        didSet {
            if let data = try? JSONEncoder().encode(hotKey) {
                defaults.set(data, forKey: "hotKey")
            }
        }
    }
    // Automatic appearance switching; times are minutes after midnight.
    @Published var autoAppearance: Bool {
        didSet { defaults.set(autoAppearance, forKey: "autoAppearance") }
    }
    @Published var lightModeMinute: Int {
        didSet { defaults.set(lightModeMinute, forKey: "lightModeMinute") }
    }
    @Published var darkModeMinute: Int {
        didSet { defaults.set(darkModeMinute, forKey: "darkModeMinute") }
    }
    // The combo actually registered right now (falls back if the preferred one is taken).
    @Published var activeHotKey: HotKeyCombo?

    private init() {
        let storedTheme = defaults.string(forKey: "theme") ?? ""
        // Retired themes (Sasuke, Sharingan, Iron Man) fall back to the default.
        theme = HeroTheme(rawValue: storedTheme) ?? .spiderman
        if let stored = defaults.stringArray(forKey: "enabledServices") {
            enabledServices = Set(stored)
        } else {
            enabledServices = Set(StreamingService.all.map(\.id))
        }
        if let data = defaults.data(forKey: "customMediaSites"),
           let sites = try? JSONDecoder().decode([CustomMediaSite].self, from: data) {
            // Rows without a link cannot exist; drop any strays from before
            // the Add Site form required one.
            customMediaSites = sites.filter { !$0.normalizedURLString.isEmpty }
        } else {
            customMediaSites = []
        }
        mediaOrder = defaults.stringArray(forKey: "mediaOrder") ?? []
        // The Claude app refuses to remember trust for the home directory, so a
        // home-dir default makes every deep-link launch re-show the trust prompt.
        var claudeDir = defaults.string(forKey: "claudeDirectory") ?? Self.defaultClaudeDirectory
        if claudeDir == NSHomeDirectory() || claudeDir == "/" {
            claudeDir = Self.defaultClaudeDirectory
        }
        claudeDirectory = claudeDir
        let limit = defaults.integer(forKey: "clipboardLimit")
        clipboardLimit = limit > 0 ? limit : 200
        screenshotsToClipboard = defaults.object(forKey: "screenshotsToClipboard") as? Bool ?? true
        autoAppearance = defaults.object(forKey: "autoAppearance") as? Bool ?? true
        lightModeMinute = defaults.object(forKey: "lightModeMinute") as? Int ?? 6 * 60
        darkModeMinute = defaults.object(forKey: "darkModeMinute") as? Int ?? 16 * 60 + 30
        if let data = defaults.data(forKey: "hotKey"),
           let combo = try? JSONDecoder().decode(HotKeyCombo.self, from: data) {
            hotKey = combo
        } else {
            hotKey = .commandSpace
        }
    }

    static var defaultClaudeDirectory: String {
        let dir = NSHomeDirectory() + "/Claude"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    var activeStreamingServices: [StreamingService] {
        StreamingService.all.filter { enabledServices.contains($0.id) }
    }

    // Entries whose URL parses to a real host; half-typed rows are ignored.
    var validCustomMediaSites: [CustomMediaSite] {
        customMediaSites.filter(\.isValid)
    }

    // Valid sites that are also ticked on - the custom-site counterpart of
    // activeStreamingServices.
    var activeCustomMediaSites: [CustomMediaSite] {
        validCustomMediaSites.filter(\.enabled)
    }

    var orderedMediaEntries: [MediaEntry] {
        Self.orderedMediaEntries(
            order: mediaOrder,
            services: StreamingService.all,
            customSites: customMediaSites,
            enabledServices: enabledServices
        )
    }

    // Ids missing from the stored order (new rows, first launch) keep their
    // canonical position at the end; stale ids from removed rows are dropped.
    // Unticked rows sink below everything enabled, keeping their relative
    // order, and float back to their stored slot when re-ticked.
    static func orderedMediaEntries(
        order: [String], services: [StreamingService], customSites: [CustomMediaSite],
        enabledServices: Set<String>
    ) -> [MediaEntry] {
        var byID: [String: MediaEntry] = [:]
        var canonical: [String] = []
        for service in services {
            byID[service.id] = .service(service)
            canonical.append(service.id)
        }
        for site in customSites {
            byID[site.id.uuidString] = .custom(site)
            canonical.append(site.id.uuidString)
        }
        let entries = (order + canonical).compactMap { byID.removeValue(forKey: $0) }
        func isDisabled(_ entry: MediaEntry) -> Bool {
            switch entry {
            case .service(let service): return !enabledServices.contains(service.id)
            case .custom(let site): return !site.enabled
            }
        }
        return entries.filter { !isDisabled($0) } + entries.filter(isDisabled)
    }

    func moveMediaEntries(fromOffsets source: IndexSet, toOffset destination: Int) {
        var order = orderedMediaEntries.map(\.id)
        order.move(fromOffsets: source, toOffset: destination)
        mediaOrder = order
    }
}
