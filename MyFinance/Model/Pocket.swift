import SwiftData
import Foundation

@Model final class Pocket {
    var id: UUID
    var nama: String
    var kelompokPocket: KelompokPocket
    var kategoriPocket: KategoriPocket?
    var saldo: Decimal
    var saldoUSD: Decimal = 0   // saldo USD (dari konversi IDR→USD di Pluang, dll)
    var logo: Data?
    var isAktif: Bool
    var ikutHitungSisa: Bool = true   // kalau true, saldo ikut dihitung di "Sisa Pocket" Home
    var catatan: String?
    var limit: Decimal?  // untuk Kartu Kredit/PayLater
    var urutan: Int      // untuk drag reorder di tab Pocket
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Transaksi.pocket)
    var transaksi: [Transaksi] = []

    init(nama: String, kelompokPocket: KelompokPocket, kategoriPocket: KategoriPocket? = nil,
         saldo: Decimal = 0, catatan: String? = nil, limit: Decimal? = nil) {
        self.id = UUID()
        self.nama = nama
        self.kelompokPocket = kelompokPocket
        self.kategoriPocket = kategoriPocket
        self.saldo = saldo
        self.logo = nil
        self.isAktif = true
        self.catatan = catatan
        self.limit = limit
        self.urutan = 0
        self.createdAt = Date()
    }
}
