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
    /// Ganti semua `try? context.save()` dengan ini supaya error bisa dideteksi saat debug.
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

    /// Dipanggil saat app pertama buka — hanya seed jika belum ada data.
    /// `executeAutoTransaksi` di-defer ke background Task agar tidak memblokir
    /// synchronous launch path dan HomeView bisa muncul secepat mungkin.
    func ensureUserProfile() {
        let context = container.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? 0
        if count == 0 {
            context.insert(UserProfile(nama: "Dika", greetingText: "Halo"))
            save(context)
        }
        ensureKategoriPocket()
        Task { self.executeAutoTransaksi() }
    }

    /// Jalankan transaksi otomatis yang belum dibuat bulan ini
    func executeAutoTransaksi() {
        let context = container.mainContext
        let cal     = Calendar.current
        let now     = Date()
        let todayDay = cal.component(.day, from: now)

        guard let autoTxs = try? context.fetch(FetchDescriptor<TransaksiOtomatis>()) else { return }
        let aktif = autoTxs.filter { $0.isAktif }
        guard !aktif.isEmpty else { return }

        // Ambil semua transaksi bulan ini — untuk deteksi duplikat
        var comps = cal.dateComponents([.year, .month], from: now); comps.day = 1
        guard let startOfMonth = cal.date(from: comps),
              let endOfMonth   = cal.date(byAdding: .month, value: 1, to: startOfMonth) else { return }

        let monthDesc = FetchDescriptor<Transaksi>(
            predicate: #Predicate { $0.tanggal >= startOfMonth && $0.tanggal < endOfMonth }
        )
        let existingTx      = (try? context.fetch(monthDesc)) ?? []
        let executedThisMonth = Set(existingTx.compactMap { $0.otomatisID })

        var didCreate = false
        for auto in aktif {
            // Hanya jalankan kalau sudah lewat tanggal tagih & belum ada bulan ini
            guard todayDay >= auto.setiapTanggal else { continue }
            guard !executedThisMonth.contains(auto.id) else { continue }

            var txComps = cal.dateComponents([.year, .month], from: now)
            txComps.day = auto.setiapTanggal
            let txDate  = cal.date(from: txComps) ?? now

            let newTx = Transaksi(
                tanggal:  txDate,
                nominal:  auto.nominal,
                tipe:     auto.tipe,
                kategori: auto.kategori,
                pocket:   auto.pocket,
                catatan:  auto.catatan
            )
            newTx.otomatisID = auto.id

            if let pocket = auto.pocket {
                if auto.tipe == .pengeluaran {
                    // Jangan biarkan saldo negatif dari auto-transaksi
                    guard pocket.saldo >= auto.nominal else {
                        print("⚠️ AutoTransaksi '\(auto.catatan ?? auto.id.uuidString)' dilewati — saldo pocket '\(pocket.nama)' tidak cukup (\(pocket.saldo) < \(auto.nominal))")
                        continue
                    }
                    pocket.saldo -= auto.nominal
                } else {
                    pocket.saldo += auto.nominal
                }
            }

            context.insert(newTx)
            didCreate = true
        }

        if didCreate { save(context) }
    }

    /// Dipanggil setelah reset — selalu seed ulang dari nol
    func seedAll() {
        let context = container.mainContext
        context.insert(UserProfile(nama: "Dika", greetingText: "Halo"))
        let defaults = [
            "Rekening Bank",
            "Bank Digital",
            "E-Wallet",
            "Dompet",
            "Kartu Kredit/PayLater",
            "Lainnya"
        ]
        for (index, nama) in defaults.enumerated() {
            context.insert(KategoriPocket(nama: nama, urutan: index))
        }
        save(context)
    }

    // MARK: - Net Worth Snapshot

    /// Upsert snapshot kekayaan bersih untuk bulan `forMonth`.
    /// Defaultnya bulan ini, tapi HomeView juga memanggil ini dengan `selectedMonth`
    /// sehingga user bisa rekap bulan lalu dari tanggal 1 bulan berikutnya.
    /// Snapshot untuk bulan di masa depan (> bulan ini) selalu diabaikan.
    func captureNetWorthSnapshot(cash: Decimal, totalAset: Decimal,
                                 hutang: Decimal, danaTersimpan: Decimal,
                                 forMonth: Date = Date()) {
        let context = container.mainContext
        let cal     = Calendar.current
        let now     = Date()

        // Jangan simpan snapshot untuk bulan yang belum terjadi
        guard cal.compare(forMonth, to: now, toGranularity: .month) != .orderedDescending else { return }

        let targetMonth = cal.component(.month, from: forMonth)
        let targetYear  = cal.component(.year,  from: forMonth)

        // Bersihkan snapshot di masa depan (artefak bug lama) — selalu relative ke now
        if let allSnaps = try? context.fetch(FetchDescriptor<NetWorthSnapshot>()) {
            for snap in allSnaps {
                let comps = DateComponents(calendar: cal, year: snap.tahun, month: snap.bulan)
                if let snapDate = comps.date,
                   cal.compare(snapDate, to: now, toGranularity: .month) == .orderedDescending {
                    context.delete(snap)
                }
            }
        }

        var descriptor = FetchDescriptor<NetWorthSnapshot>(
            predicate: #Predicate { $0.bulan == targetMonth && $0.tahun == targetYear }
        )
        descriptor.fetchLimit = 1
        let existing = (try? context.fetch(descriptor)) ?? []

        if let snapshot = existing.first {
            snapshot.cash          = cash
            snapshot.totalAset     = totalAset
            snapshot.hutang        = hutang
            snapshot.danaTersimpan = danaTersimpan
            snapshot.totalKekayaan = cash + totalAset + danaTersimpan - hutang
        } else {
            let snapshot = NetWorthSnapshot(
                bulan: targetMonth, tahun: targetYear,
                cash: cash, totalAset: totalAset,
                hutang: hutang, danaTersimpan: danaTersimpan
            )
            context.insert(snapshot)
        }
        save(context)
    }

    private func ensureKategoriPocket() {
        let context = container.mainContext
        let descriptor = FetchDescriptor<KategoriPocket>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        if count == 0 {
            let defaults = [
                "Rekening Bank",
                "Bank Digital",
                "E-Wallet",
                "Dompet",
                "Kartu Kredit/PayLater",
                "Lainnya"
            ]
            for (index, nama) in defaults.enumerated() {
                context.insert(KategoriPocket(nama: nama, urutan: index))
            }
            save(context)
        }
    }
}
