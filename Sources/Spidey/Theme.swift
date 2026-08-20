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
            return ThemePalette(
                background: Color(red: 0.043, green: 0.106, blue: 0.290),
                backgroundTop: Color(red: 0.075, green: 0.145, blue: 0.360),
                accent: Color(red: 0.878, green: 0.129, blue: 0.157),
                textPrimary: .white,
                textSecondary: Color(red: 0.72, green: 0.79, blue: 0.95),
                fieldOutline: Color(red: 0.878, green: 0.129, blue: 0.157),
                monospacedAccents: false
            )
        case .batman:
            return ThemePalette(
                background: Color(red: 0.039, green: 0.039, blue: 0.047),
                backgroundTop: Color(red: 0.09, green: 0.09, blue: 0.11),
                accent: Color(red: 0.961, green: 0.773, blue: 0.094),
                textPrimary: .white,
                textSecondary: Color(red: 0.65, green: 0.65, blue: 0.60),
                fieldOutline: Color(red: 0.961, green: 0.773, blue: 0.094),
                monospacedAccents: false
            )
        case .ironman:
            return ThemePalette(
                background: Color(red: 0.231, green: 0.039, blue: 0.055),
                backgroundTop: Color(red: 0.32, green: 0.07, blue: 0.09),
                accent: Color(red: 0.941, green: 0.702, blue: 0.161),
                textPrimary: .white,
                textSecondary: Color(red: 0.95, green: 0.82, blue: 0.60),
                fieldOutline: Color(red: 0.941, green: 0.702, blue: 0.161),
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
