import SwiftUI
import AppKit

enum HeroTheme: String, CaseIterable, Codable {
    case spiderman
    case batman

    var displayName: String {
        switch self {
        case .spiderman: return "Spider-Man"
        case .batman: return "Batman"
        }
    }

    var searchPlaceholder: String {
        switch self {
        case .spiderman: return "Spidey Search"
        case .batman: return "Explore the Cave"
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
        case .batman:
            return dark ? Color(red: 0.66, green: 0.69, blue: 0.74) : Color(red: 0.36, green: 0.40, blue: 0.45)
        }
    }

    // Tinted running text; picked to pass 4.5:1 on the island fills.
    func accentText(for scheme: ColorScheme) -> Color {
        let dark = scheme == .dark
        switch self {
        case .spiderman:
            return dark ? Color(red: 1.0, green: 0.42, blue: 0.45) : Color(red: 0.70, green: 0.13, blue: 0.17)
        case .batman:
            return dark ? Color(red: 0.80, green: 0.83, blue: 0.87) : Color(red: 0.36, green: 0.40, blue: 0.45)
        }
    }

    // Glyph colour on top of an accent fill.
    func onAccent(for scheme: ColorScheme) -> Color {
        if self == .batman && scheme == .dark { return Color(white: 0.08) }
        return .white
    }
}
