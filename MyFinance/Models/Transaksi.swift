import SwiftData
import Foundation

@Model final class Transaksi {
    var id: UUID
    var tanggal: Date
    var nominal: Decimal
    var tipe: TipeTransaksi
    var subTipe: SubTipeTransaksi
    var kategori: Kategori?
    var pocket: Pocket?
    var catatan: String?
    var goalID: UUID?       // linked Target if subTipe != .normal
    var otomatisID: UUID?   // linked TransaksiOtomatis if auto-generated
    var createdAt: Date

    init(tanggal: Date = Date(), nominal: Decimal, tipe: TipeTransaksi,
         subTipe: SubTipeTransaksi = .normal, kategori: Kategori? = nil,
         pocket: Pocket? = nil, catatan: String? = nil, goalID: UUID? = nil) {
        self.id = UUID()
        self.tanggal = tanggal
        self.nominal = nominal
        self.tipe = tipe
        self.subTipe = subTipe
        self.kategori = kategori
        self.pocket = pocket
        self.catatan = catatan
        self.goalID = goalID
        self.otomatisID = nil
        self.createdAt = Date()
    }
}
