import SwiftUI
import SwiftData

@main
struct MyFinanceApp: App {
    let containerService = ModelContainerService.shared
    @State private var themeManager = ThemeManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        containerService.ensureUserProfile()
        UserDefaults.standard.removeObject(forKey: "asetPriceLastUpdated")
        migrateAPIKeyToKeychain()
    }

    /// Jika API key masih tersimpan di UserDefaults (sesi sebelum fix ini),
    /// pindahkan ke Keychain lalu hapus dari UserDefaults.
    private func migrateAPIKeyToKeychain() {
        let udKey = "anthropicAPIKey"
        guard let oldKey = UserDefaults.standard.string(forKey: udKey), !oldKey.isEmpty else { return }
        // Simpan ke Keychain hanya jika belum ada
        if APIKeyStore.shared.apiKey.isEmpty {
            APIKeyStore.shared.apiKey = oldKey
        }
        UserDefaults.standard.removeObject(forKey: udKey)
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(containerService.container)
                .environment(\.appTheme, themeManager.current)
                .preferredColorScheme(themeManager.current.colorScheme)
                .task {
                    let ctx = containerService.container.mainContext
                    await AutoBackupService.shared.autoBackupIfNeeded(context: ctx)
                    // Request notification permission setelah onboarding selesai
                    if hasCompletedOnboarding {
                        await NotificationService.shared.requestPermission()
                    }
                }
                // Tampilkan onboarding untuk user baru
                .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
                    OnboardingView()
                        .modelContainer(containerService.container)
                        .environment(\.appTheme, themeManager.current)
                        .preferredColorScheme(themeManager.current.colorScheme)
                }
        }
    }
}
