import SwiftData
import Foundation

// MARK: - Net Worth Snapshot

extension ModelContainerService {

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

        guard cal.compare(forMonth, to: now, toGranularity: .month) != .orderedDescending else { return }

        let targetMonth = cal.component(.month, from: forMonth)
        let targetYear  = cal.component(.year,  from: forMonth)

        // Bersihkan snapshot di masa depan (artefak bug lama)
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
}
