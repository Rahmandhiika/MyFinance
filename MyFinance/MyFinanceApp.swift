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
        // Migrasi one-time: pindah API key dari UserDefaults (plaintext) ke Keychain (terenkripsi)
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
                .environmentObject(themeManager)
                .environment(\.appTheme, themeManager.current)
                .preferredColorScheme(themeManager.current.colorScheme)
                .task {
                    // Auto-backup sekali per hari ke Documents/MyFinanceBackups/
                    // (folder ini masuk iPhone backup → iCloud otomatis)
                    let ctx = containerService.container.mainContext
                    await AutoBackupService.shared.autoBackupIfNeeded(context: ctx)
                }
        }
    }
}
