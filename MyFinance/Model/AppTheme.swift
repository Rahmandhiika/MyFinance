import SwiftUI

struct AppTheme: Identifiable {
    let id: String
    let nama: String
    let emoji: String

    let bgApp: Color
    let bgCard: Color
    let bgListRow: Color

    let textPrimary: Color
    let textSecondary: Color
    let textOnColor: Color

    let accent: Color
    let accentDark: Color
    let danger: Color
    let dangerDark: Color

    let pemasukan: Color
    let pengeluaran: Color

    let separator: Color
    let cardBorder: Color
    let colorScheme: ColorScheme
    let tabBarTint: Color
}

extension AppTheme {
    static let darkNeon = AppTheme(
        id: "dark_neon",
        nama: "Dark Neon",
        emoji: "🌑",
        bgApp: Color(hex: "#0D0D0D"),
        bgCard: Color(hex: "#1A1A1A"),
        bgListRow: Color(hex: "#1A1A1A"),
        textPrimary: Color(hex: "#FFFFFF"),
        textSecondary: Color(hex: "#9CA3AF"),
        textOnColor: Color(hex: "#FFFFFF"),
        accent: Color(hex: "#22C55E"),
        accentDark: Color(hex: "#16A34A"),
        danger: Color(hex: "#EF4444"),
        dangerDark: Color(hex: "#B91C1C"),
        pemasukan: Color(hex: "#22C55E"),
        pengeluaran: Color(hex: "#EF4444"),
        separator: Color.white.opacity(0.08),
        cardBorder: Color.white.opacity(0.10),
        colorScheme: .dark,
        tabBarTint: Color(hex: "#22C55E")
    )

    static let cerah = AppTheme(
        id: "cerah",
        nama: "Cerah",
        emoji: "🌈",
        bgApp: Color(hex: "#F0FAFA"),
        bgCard: Color(hex: "#FFFFFF"),
        bgListRow: Color(hex: "#FFFFFF"),
        textPrimary: Color(hex: "#0D3B36"),
        textSecondary: Color(hex: "#5B8B86"),
        textOnColor: Color(hex: "#FFFFFF"),
        accent: Color(hex: "#00C4A6"),
        accentDark: Color(hex: "#00927B"),
        danger: Color(hex: "#FF5A78"),
        dangerDark: Color(hex: "#D63A57"),
        pemasukan: Color(hex: "#00C4A6"),
        pengeluaran: Color(hex: "#FF5A78"),
        separator: Color(hex: "#00C4A6").opacity(0.12),
        cardBorder: Color(hex: "#00C4A6").opacity(0.18),
        colorScheme: .light,
        tabBarTint: Color(hex: "#00C4A6")
    )

    static let all: [AppTheme] = [.darkNeon, .cerah]
}

// MARK: - Environment Key
private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .darkNeon
}
extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
