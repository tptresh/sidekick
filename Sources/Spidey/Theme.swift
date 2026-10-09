import SwiftUI
import AppKit

enum HeroTheme: String, CaseIterable, Codable {
    case spiderman

    var displayName: String {
        switch self {
        case .spiderman: return "Spider-Man"
        }
    }

    var searchPlaceholder: String {
        switch self {
        case .spiderman: return "Spidey Search"
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

// Accents for Spidey's own windows, which are always dark.
extension HeroTheme {
    // Fills: selection, switched-on tiles, prominent buttons.
    var accent: Color {
        switch self {
        case .spiderman: return Color(red: 0.86, green: 0.20, blue: 0.25)
        }
    }

    // Tinted running text; brighter than the fill so it passes 4.5:1 on dark glass.
    var accentText: Color {
        switch self {
        case .spiderman: return Color(red: 1.0, green: 0.45, blue: 0.48)
        }
    }

    // Glyph colour on top of an accent fill.
    var onAccent: Color { .white }
}
