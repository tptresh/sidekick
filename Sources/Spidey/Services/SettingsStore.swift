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

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    @Published var theme: HeroTheme {
        didSet { defaults.set(theme.rawValue, forKey: "theme") }
    }
    @Published var enabledServices: Set<String> {
        didSet { defaults.set(Array(enabledServices), forKey: "enabledServices") }
    }
    @Published var claudeDirectory: String {
        didSet { defaults.set(claudeDirectory, forKey: "claudeDirectory") }
    }
    @Published var clipboardLimit: Int {
        didSet { defaults.set(clipboardLimit, forKey: "clipboardLimit") }
    }
    @Published var hotKey: HotKeyCombo {
        didSet {
            if let data = try? JSONEncoder().encode(hotKey) {
                defaults.set(data, forKey: "hotKey")
            }
        }
    }
    // The combo actually registered right now (falls back if the preferred one is taken).
    @Published var activeHotKey: HotKeyCombo?

    private init() {
        theme = HeroTheme(rawValue: defaults.string(forKey: "theme") ?? "") ?? .spiderman
        if let stored = defaults.stringArray(forKey: "enabledServices") {
            enabledServices = Set(stored)
        } else {
            enabledServices = Set(StreamingService.all.map(\.id))
        }
        claudeDirectory = defaults.string(forKey: "claudeDirectory") ?? NSHomeDirectory()
        let limit = defaults.integer(forKey: "clipboardLimit")
        clipboardLimit = limit > 0 ? limit : 200
        if let data = defaults.data(forKey: "hotKey"),
           let combo = try? JSONDecoder().decode(HotKeyCombo.self, from: data) {
            hotKey = combo
        } else {
            hotKey = .commandSpace
        }
    }

    var activeStreamingServices: [StreamingService] {
        StreamingService.all.filter { enabledServices.contains($0.id) }
    }
}
