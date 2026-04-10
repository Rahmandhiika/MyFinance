import SwiftData
import Foundation

@Model
final class Pocket {
    var id: UUID
    var nama: String
    var kelompokPocket: KelompokPocket
    var kategoriPocket: NamaKategoriPocket
    var saldo: Double
    var logo: Data?
    var isAktif: Bool
    var catatan: String?
    var limit: Double?
    var createdAt: Date

    init(nama: String, kelompokPocket: KelompokPocket, kategoriPocket: NamaKategoriPocket,
         saldo: Double = 0, catatan: String? = nil, limit: Double? = nil) {
        self.id = UUID()
        self.nama = nama
        self.kelompokPocket = kelompokPocket
        self.kategoriPocket = kategoriPocket
        self.saldo = saldo
        self.isAktif = true
        self.catatan = catatan
        self.limit = limit
        self.createdAt = Date()
    }

    var sisaLimit: Double? {
        guard let limit else { return nil }
        return limit - abs(saldo)
    }
}

@Model
final class UpdateSaldo {
    var id: UUID
    var pocketID: UUID
    var tanggal: Date
    var saldo: Double
    var waktuUpdate: WaktuUpdate

    init(pocketID: UUID, tanggal: Date, saldo: Double, waktuUpdate: WaktuUpdate) {
        self.id = UUID()
        self.pocketID = pocketID
        self.tanggal = tanggal
        self.saldo = saldo
        self.waktuUpdate = waktuUpdate
    }
}
