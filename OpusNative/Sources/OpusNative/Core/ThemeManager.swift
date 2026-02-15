import SwiftUI

// MARK: - Theme Manager

/// Centralized accent color manager. All views read from `ThemeManager.shared.accent`
/// so the entire app updates when the user picks a new theme color.
@Observable
@MainActor
final class ThemeManager {
    static let shared = ThemeManager()

    /// The currently selected accent color
    var accent: Color {
        Self.themes[currentThemeIndex].color
    }

    /// A lighter variant for gradients
    var accentLight: Color {
        Self.themes[currentThemeIndex].light
    }

    /// A darker variant for gradients
    var accentDark: Color {
        Self.themes[currentThemeIndex].dark
    }

    /// Currently selected theme index
    var currentThemeIndex: Int {
        didSet {
            UserDefaults.standard.set(currentThemeIndex, forKey: "selectedThemeIndex")
        }
    }

    /// Current theme name
    var currentThemeName: String {
        Self.themes[currentThemeIndex].name
    }

    private init() {
        let saved = UserDefaults.standard.integer(forKey: "selectedThemeIndex")
        self.currentThemeIndex = (saved >= 0 && saved < Self.themes.count) ? saved : 0
    }

    // MARK: - Theme Presets

    struct ThemePreset: Identifiable {
        let id: Int
        let name: String
        let color: Color
        let light: Color
        let dark: Color
    }

    static let themes: [ThemePreset] = [
        ThemePreset(
            id: 0, name: "Purple",
            color: Color(red: 0.56, green: 0.44, blue: 1.0),
            light: Color(red: 0.78, green: 0.56, blue: 1.0),
            dark: Color(red: 0.36, green: 0.24, blue: 0.95)
        ),
        ThemePreset(
            id: 1, name: "Blue",
            color: Color(red: 0.25, green: 0.52, blue: 1.0),
            light: Color(red: 0.45, green: 0.68, blue: 1.0),
            dark: Color(red: 0.15, green: 0.35, blue: 0.90)
        ),
        ThemePreset(
            id: 2, name: "Cyan",
            color: Color(red: 0.0, green: 0.75, blue: 0.85),
            light: Color(red: 0.2, green: 0.88, blue: 0.95),
            dark: Color(red: 0.0, green: 0.55, blue: 0.70)
        ),
        ThemePreset(
            id: 3, name: "Teal",
            color: Color(red: 0.18, green: 0.72, blue: 0.68),
            light: Color(red: 0.35, green: 0.85, blue: 0.78),
            dark: Color(red: 0.10, green: 0.55, blue: 0.50)
        ),
        ThemePreset(
            id: 4, name: "Green",
            color: Color(red: 0.20, green: 0.78, blue: 0.35),
            light: Color(red: 0.40, green: 0.90, blue: 0.50),
            dark: Color(red: 0.12, green: 0.58, blue: 0.25)
        ),
        ThemePreset(
            id: 5, name: "Emerald",
            color: Color(red: 0.18, green: 0.75, blue: 0.55),
            light: Color(red: 0.35, green: 0.88, blue: 0.68),
            dark: Color(red: 0.10, green: 0.55, blue: 0.40)
        ),
        ThemePreset(
            id: 6, name: "Gold",
            color: Color(red: 0.90, green: 0.72, blue: 0.20),
            light: Color(red: 1.0, green: 0.85, blue: 0.40),
            dark: Color(red: 0.75, green: 0.58, blue: 0.10)
        ),
        ThemePreset(
            id: 7, name: "Orange",
            color: Color(red: 1.0, green: 0.55, blue: 0.20),
            light: Color(red: 1.0, green: 0.72, blue: 0.40),
            dark: Color(red: 0.88, green: 0.40, blue: 0.10)
        ),
        ThemePreset(
            id: 8, name: "Rose",
            color: Color(red: 0.95, green: 0.30, blue: 0.50),
            light: Color(red: 1.0, green: 0.50, blue: 0.65),
            dark: Color(red: 0.80, green: 0.18, blue: 0.38)
        ),
        ThemePreset(
            id: 9, name: "Pink",
            color: Color(red: 0.92, green: 0.38, blue: 0.72),
            light: Color(red: 1.0, green: 0.55, blue: 0.82),
            dark: Color(red: 0.78, green: 0.22, blue: 0.58)
        ),
        ThemePreset(
            id: 10, name: "Red",
            color: Color(red: 0.92, green: 0.26, blue: 0.26),
            light: Color(red: 1.0, green: 0.45, blue: 0.42),
            dark: Color(red: 0.75, green: 0.15, blue: 0.15)
        ),
        ThemePreset(
            id: 11, name: "Indigo",
            color: Color(red: 0.35, green: 0.34, blue: 0.84),
            light: Color(red: 0.52, green: 0.50, blue: 0.95),
            dark: Color(red: 0.22, green: 0.20, blue: 0.70)
        ),
    ]
}
