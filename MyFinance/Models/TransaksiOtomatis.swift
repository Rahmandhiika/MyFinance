import SwiftData
import Foundation

@Model final class TransaksiOtomatis {
    var id: UUID
    var nominal: Decimal
    var tipe: TipeTransaksi
    var kategori: Kategori?
    var pocket: Pocket?
    var setiapTanggal: Int   // 1–28
    var catatan: String?
    var isAktif: Bool
    var createdAt: Date

    init(nominal: Decimal, tipe: TipeTransaksi, kategori: Kategori? = nil,
         pocket: Pocket? = nil, setiapTanggal: Int = 1, catatan: String? = nil) {
        self.id = UUID()
        self.nominal = nominal
        self.tipe = tipe
        self.kategori = kategori
        self.pocket = pocket
        self.setiapTanggal = setiapTanggal
        self.catatan = catatan
        self.isAktif = true
        self.createdAt = Date()
    }
}
