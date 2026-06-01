import SwiftData

// MARK: - Schema V1 (versi saat ini)
//
// Setiap kali menambahkan field baru ke @Model:
//   1. Buat enum AppSchemaV2: VersionedSchema (copy dari V1, tambah field baru)
//   2. Tambah AppSchemaV2.self ke AppMigrationPlan.schemas
//   3. Tambah MigrationStage ke AppMigrationPlan.stages:
//      - Lightweight (field optional / ada default): .lightweight(fromVersion: AppSchemaV1.self, toVersion: AppSchemaV2.self)
//      - Custom (rename / hapus / ubah tipe): .custom(fromVersion: ..., toVersion: ..., willMigrate: {...}, didMigrate: {...})
//
// Panduan cepat:
//   ✅ Tambah var baru dengan default value  → lightweight migration, aman
//   ✅ Tambah @Model baru ke schema          → lightweight migration, aman
//   ⚠️ Rename property                       → custom migration diperlukan
//   ⚠️ Hapus property                        → custom migration diperlukan
//   ⚠️ Ubah tipe property                    → custom migration diperlukan

enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] = [
        Pocket.self,
        KategoriPocket.self,
        Transaksi.self,
        TransferInternal.self,
        Kategori.self,
        Target.self,
        SimpanKeTarget.self,
        Aset.self,
        Anggaran.self,
        Langganan.self,
        PembayaranLangganan.self,
        UserProfile.self,
        PortofolioConfig.self,
        NetWorthSnapshot.self,
        SavedAIInsight.self
    ]
}

// MARK: - Migration Plan

enum AppMigrationPlan: SchemaMigrationPlan {
    /// Urutan schema dari paling lama ke paling baru.
    /// Tambahkan AppSchemaV2.self, AppSchemaV3.self, dll di sini saat diperlukan.
    static var schemas: [any VersionedSchema.Type] = [
        AppSchemaV1.self
    ]

    /// Stage migrasi antar versi.
    /// Kosong = hanya V1, belum ada migrasi yang perlu dijalankan.
    /// Contoh nanti:
    ///   .lightweight(fromVersion: AppSchemaV1.self, toVersion: AppSchemaV2.self)
    static var stages: [MigrationStage] = []
}
