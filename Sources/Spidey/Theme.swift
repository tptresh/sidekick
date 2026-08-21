import SwiftUI
import AppKit

enum HeroTheme: String, CaseIterable, Codable {
    case spiderman
    case batman
    case sasuke

    var displayName: String {
        switch self {
        case .spiderman: return "Spider-Man"
        case .batman: return "Batman"
        case .sasuke: return "Sasuke"
        }
    }

    var searchPlaceholder: String {
        switch self {
        case .spiderman: return "Spidey Search"
        case .batman: return "Explore the Cave"
        case .sasuke: return "Awaken the Sharingan"
        }
    }

    // Light themes draw dark text on a bright panel; consumers that hardcode
    // colors for a dark backdrop (text fields, blur materials) branch on this.
    var isLight: Bool {
        switch self {
        case .spiderman, .batman: return false
        case .sasuke: return true
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
        case .sasuke:
            // Cool grey panel with a lilac cast, deep Uchiha purple accent and
            // a muted mauve field outline, taken from his lavender shirt and
            // slate blue trousers. Dark text with the same purple cast keeps
            // every opacity-derived tint readable on the light panel.
            return ThemePalette(
                background: Color(red: 0.918, green: 0.910, blue: 0.933),
                backgroundTop: Color(red: 0.961, green: 0.957, blue: 0.973),
                accent: Color(red: 0.396, green: 0.310, blue: 0.573),
                textPrimary: Color(red: 0.137, green: 0.125, blue: 0.161),
                textSecondary: Color(red: 0.412, green: 0.396, blue: 0.459),
                fieldOutline: Color(red: 0.494, green: 0.400, blue: 0.549)
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
