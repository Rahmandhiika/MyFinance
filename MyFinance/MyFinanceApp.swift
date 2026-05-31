import SwiftUI
import SwiftData

@main
struct MyFinanceApp: App {
    let containerService = ModelContainerService.shared
    @StateObject private var themeManager = ThemeManager.shared

    init() {
        containerService.ensureUserProfile()
        // Bersihkan key UserDefaults lama yang sudah tidak dipakai
        UserDefaults.standard.removeObject(forKey: "asetPriceLastUpdated")
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(containerService.container)
                .environmentObject(themeManager)
                .environment(\.appTheme, themeManager.current)
                .preferredColorScheme(themeManager.current.colorScheme)
        }
    }
}
