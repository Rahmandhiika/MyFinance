import SwiftData
import Foundation

@MainActor
class ModelContainerService {
    static let shared = ModelContainerService()
    let container: ModelContainer

    private init() {
        let storeURL = URL.applicationSupportDirectory
            .appendingPathComponent("myfinance.store")

        // Schema diambil dari AppSchemaV1.models agar satu source of truth dengan AppMigrationPlan.
        //
        // CATATAN: migrationPlan: TIDAK dipakai sekarang karena store lama dibuat dengan
        // plain Schema([...]) tanpa VersionedSchema. Menambahkan migrationPlan: ke store
        // yang tidak punya version history akan menyebabkan SwiftData gagal init atau
        // corrupt persistent history (entity not found saat restore).
        //
        // Cara aktifkan migration (saat benar-benar perlu tambah field baru):
        //   1. Buat AppSchemaV2 di AppMigrationPlan.swift
        //   2. Tambah .lightweight(from: AppSchemaV1.self, to: AppSchemaV2.self) ke stages
        //   3. Ganti ModelContainer(for:) menjadi ModelContainer(migrationPlan:configurations:)
        //      — HANYA setelah seluruh user base sudah di versi yang punya AppSchemaV1
        let schema = Schema(AppSchemaV1.models)
        let config = ModelConfiguration(schema: schema, url: storeURL)

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            print("⚠️ MyFinance: persistent store gagal (\(error)). Fallback ke in-memory store.")
            do {
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: fallbackConfig)
            } catch {
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
