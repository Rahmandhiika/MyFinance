import SwiftData
import Foundation

// MARK: - Auto-Transaksi (transaksi otomatis bulanan)

extension ModelContainerService {

    /// Jalankan transaksi otomatis yang belum dibuat bulan ini.
    /// Dipanggil dari ensureUserProfile (deferred Task) dan pull-to-refresh TransaksiTabView.
    func executeAutoTransaksi() {
        let context  = container.mainContext
        let cal      = Calendar.current
        let now      = Date()
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
        let existingTx        = (try? context.fetch(monthDesc)) ?? []
        let executedThisMonth = Set(existingTx.compactMap { $0.otomatisID })

        var didCreate = false
        for auto in aktif {
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
}
