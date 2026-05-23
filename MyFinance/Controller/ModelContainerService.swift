import SwiftData
import Foundation

@MainActor
class ModelContainerService {
    static let shared = ModelContainerService()
    let container: ModelContainer

    private init() {
        let schema = Schema([
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
        ])

        let storeURL = URL.applicationSupportDirectory
            .appendingPathComponent("myfinance.store")

        let config = ModelConfiguration(schema: schema, url: storeURL)

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Persistent store gagal (misal schema migration) — fallback ke in-memory
            // agar app tidak crash. Data tidak akan persist di sesi ini, tapi app tetap jalan.
            print("⚠️ MyFinance: persistent store gagal (\(error)). Fallback ke in-memory store.")
            do {
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: fallbackConfig)
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

    /// Dipanggil saat app pertama buka — hanya seed jika belum ada data
    func ensureUserProfile() {
        let context = container.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? 0
        if count == 0 {
            context.insert(UserProfile(nama: "Dika", greetingText: "Halo"))
            save(context)
        }
        ensureKategoriPocket()
        executeAutoTransaksi()
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
                if auto.tipe == .pengeluaran { pocket.saldo -= auto.nominal }
                else                         { pocket.saldo += auto.nominal }
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
