import SwiftData
import Foundation

@MainActor
class ModelContainerService {
    static let shared = ModelContainerService()
    let container: ModelContainer

    private init() {
        let storeURL = URL.applicationSupportDirectory
            .appendingPathComponent("myfinance.store")

        // Gunakan AppMigrationPlan agar schema migration ditangani SwiftData secara aman.
        // Saat menambah field baru ke @Model, cukup daftarkan versi baru di AppMigrationPlan.
        let config = ModelConfiguration(
            schema: Schema(AppSchemaV1.models),
            url: storeURL
        )

        do {
            container = try ModelContainer(
                migrationPlan: AppMigrationPlan.self,
                configurations: config
            )
        } catch {
            // Persistent store gagal (misal schema migration) — fallback ke in-memory
            // agar app tidak crash. Data tidak akan persist di sesi ini, tapi app tetap jalan.
            print("⚠️ MyFinance: persistent store gagal (\(error)). Fallback ke in-memory store.")
            do {
                let fallbackConfig = ModelConfiguration(
                    schema: Schema(AppSchemaV1.models),
                    isStoredInMemoryOnly: true
                )
                container = try ModelContainer(
                    migrationPlan: AppMigrationPlan.self,
                    configurations: fallbackConfig
                )
            } catch {
                // In-memory pun gagal — baru boleh crash
                fatalError("Failed to create even in-memory ModelContainer: \(error)")
            }
        }
    }

    // MARK: - Save helper (logs errors instead of silently swallowing them)

    /// Simpan context. Gagal → print warning, bukan crash.
    @discardableResult
    func save(_ context: ModelContext) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            print("⚠️ MyFinance: ModelContext.save() gagal — \(error)")
            return false
        }
    }
}

// Logika bisnis dipecah ke extension di file terpisah agar tiap concern mudah ditemukan:
//   ModelContainerService+Seeding.swift      — ensureUserProfile, ensureKategoriPocket, seedAll
//   ModelContainerService+AutoTransaksi.swift — executeAutoTransaksi
//   ModelContainerService+Snapshot.swift     — captureNetWorthSnapshot
