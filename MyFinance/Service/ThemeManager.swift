import SwiftUI
import Observation

@Observable final class ThemeManager {
    static let shared = ThemeManager()

    var currentID: String {
        didSet { UserDefaults.standard.set(currentID, forKey: "selectedThemeID") }
    }

    var current: AppTheme {
        AppTheme.all.first { $0.id == currentID } ?? .darkNeon
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "selectedThemeID") ?? "dark_neon"
        // Migrate old id "merah_putih" → "cerah"
        self.currentID = saved == "merah_putih" ? "cerah" : saved
    }
}
