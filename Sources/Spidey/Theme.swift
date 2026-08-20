import SwiftUI
import AppKit

enum HeroTheme: String, CaseIterable, Codable {
    case spiderman
    case batman
    case ironman

    var displayName: String {
        switch self {
        case .spiderman: return "Spider-Man"
        case .batman: return "Batman"
        case .ironman: return "Iron Man"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .spiderman:
            // Midnight navy with a muted crimson accent.
            return ThemePalette(
                background: Color(red: 0.035, green: 0.055, blue: 0.110),
                backgroundTop: Color(red: 0.058, green: 0.086, blue: 0.165),
                accent: Color(red: 0.690, green: 0.180, blue: 0.210),
                textPrimary: Color(red: 0.949, green: 0.957, blue: 0.973),
                textSecondary: Color(red: 0.545, green: 0.596, blue: 0.702),
                fieldOutline: Color(red: 0.690, green: 0.180, blue: 0.210),
                monospacedAccents: false
            )
        case .batman:
            // Graphite black with antique gold.
            return ThemePalette(
                background: Color(red: 0.035, green: 0.035, blue: 0.043),
                backgroundTop: Color(red: 0.075, green: 0.075, blue: 0.086),
                accent: Color(red: 0.788, green: 0.635, blue: 0.212),
                textPrimary: Color(red: 0.945, green: 0.937, blue: 0.914),
                textSecondary: Color(red: 0.545, green: 0.529, blue: 0.478),
                fieldOutline: Color(red: 0.788, green: 0.635, blue: 0.212),
                monospacedAccents: false
            )
        case .ironman:
            // Deep oxblood with champagne gold.
            return ThemePalette(
                background: Color(red: 0.098, green: 0.035, blue: 0.047),
                backgroundTop: Color(red: 0.153, green: 0.059, blue: 0.075),
                accent: Color(red: 0.804, green: 0.635, blue: 0.345),
                textPrimary: Color(red: 0.965, green: 0.945, blue: 0.922),
                textSecondary: Color(red: 0.702, green: 0.596, blue: 0.502),
                fieldOutline: Color(red: 0.804, green: 0.635, blue: 0.345),
                monospacedAccents: true
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
    let monospacedAccents: Bool
}
