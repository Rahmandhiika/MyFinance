import SwiftData
import Foundation

/// Snapshot kekayaan bersih per bulan — di-capture otomatis tiap awal bulan baru
@Model final class NetWorthSnapshot {
    var id: UUID
    var bulan: Int          // 1–12
    var tahun: Int
    var cash: Decimal
    var totalAset: Decimal
    var hutang: Decimal
    var danaTersimpan: Decimal
    var totalKekayaan: Decimal
    var createdAt: Date

    init(bulan: Int, tahun: Int,
         cash: Decimal, totalAset: Decimal,
         hutang: Decimal, danaTersimpan: Decimal) {
        self.id = UUID()
        self.bulan = bulan
        self.tahun = tahun
        self.cash = cash
        self.totalAset = totalAset
        self.hutang = hutang
        self.danaTersimpan = danaTersimpan
        self.totalKekayaan = cash + totalAset + danaTersimpan - hutang
        self.createdAt = Date()
    }
}
