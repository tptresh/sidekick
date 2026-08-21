import SwiftUI
import AppKit

enum HeroTheme: String, CaseIterable, Codable {
    case spiderman
    case batman
    case ironMan

    var displayName: String {
        switch self {
        case .spiderman: return "Spider-Man"
        case .batman: return "Batman"
        case .ironMan: return "Iron Man"
        }
    }

    var searchPlaceholder: String {
        switch self {
        case .spiderman: return "Spidey Search"
        case .batman: return "Explore the Cave"
        case .ironMan: return "JARVIS, Find It"
        }
    }

    // Light themes draw dark text on a bright panel; consumers that hardcode
    // colors for a dark backdrop (text fields, blur materials) branch on this.
    var isLight: Bool {
        switch self {
        case .spiderman, .batman: return false
        case .ironMan: return true
        }
    }

    var palette: ThemePalette {
        switch self {
        case .spiderman:
            // Near-black with a warm cast and a deep, sophisticated red.
            return ThemePalette(
                background: Color(red: 0.047, green: 0.039, blue: 0.043),
                backgroundTop: Color(red: 0.086, green: 0.071, blue: 0.078),
                accent: Color(red: 0.596, green: 0.153, blue: 0.196),
                textPrimary: Color(red: 0.953, green: 0.945, blue: 0.945),
                textSecondary: Color(red: 0.600, green: 0.557, blue: 0.569),
                fieldOutline: Color(red: 0.596, green: 0.153, blue: 0.196)
            )
        case .batman:
            // Neutral black with silver grey.
            return ThemePalette(
                background: Color(red: 0.035, green: 0.035, blue: 0.039),
                backgroundTop: Color(red: 0.075, green: 0.075, blue: 0.082),
                accent: Color(red: 0.663, green: 0.678, blue: 0.702),
                textPrimary: Color(red: 0.937, green: 0.941, blue: 0.949),
                textSecondary: Color(red: 0.510, green: 0.522, blue: 0.541),
                fieldOutline: Color(red: 0.663, green: 0.678, blue: 0.702)
            )
        case .ironMan:
            // Warm white with a faint gold cast, hot-rod red accent, and a
            // gold field outline for the classic red-and-gold armor duo. Dark
            // warm text keeps every opacity-derived tint (separators, borders,
            // placeholder) readable against the light panel.
            return ThemePalette(
                background: Color(red: 0.976, green: 0.961, blue: 0.933),
                backgroundTop: Color(red: 0.992, green: 0.984, blue: 0.964),
                accent: Color(red: 0.678, green: 0.106, blue: 0.086),
                textPrimary: Color(red: 0.157, green: 0.110, blue: 0.094),
                textSecondary: Color(red: 0.478, green: 0.400, blue: 0.357),
                fieldOutline: Color(red: 0.788, green: 0.596, blue: 0.196)
            )
        }
    }
}

struct ThemePalette {
    let background: Color
    let backgroundTop: Color
    let accent: Color
    let textPrimary: Color
    let textSecondary: Color
    let fieldOutline: Color
}
