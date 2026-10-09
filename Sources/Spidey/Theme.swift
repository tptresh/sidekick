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

// Futuristic-redesign accents, resolved per theme and system appearance.
extension HeroTheme {
    func accent(for scheme: ColorScheme) -> Color {
        let dark = scheme == .dark
        switch self {
        case .spiderman:
            return dark ? Color(red: 0.90, green: 0.26, blue: 0.30) : Color(red: 0.70, green: 0.13, blue: 0.17)
        }
    }

    // Tinted running text; picked to pass 4.5:1 on the island fills.
    func accentText(for scheme: ColorScheme) -> Color {
        let dark = scheme == .dark
        switch self {
        case .spiderman:
            return dark ? Color(red: 1.0, green: 0.42, blue: 0.45) : Color(red: 0.70, green: 0.13, blue: 0.17)
        }
    }

    // Glyph colour on top of an accent fill.
    func onAccent(for scheme: ColorScheme) -> Color { .white }
}
