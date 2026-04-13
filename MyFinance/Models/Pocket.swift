import SwiftData
import Foundation

@Model final class Pocket {
    var id: UUID
    var nama: String
    var kelompokPocket: KelompokPocket
    var kategoriPocket: KategoriPocket?
    var saldo: Decimal
    var logo: Data?
    var isAktif: Bool
    var catatan: String?
    var limit: Decimal?  // untuk Kartu Kredit/PayLater
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
        self.createdAt = Date()
    }
}
