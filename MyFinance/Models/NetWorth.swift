import SwiftData
import Foundation

@Model
final class KategoriAset {
    var id: UUID
    var nama: String

    init(nama: String) {
        self.id = UUID()
        self.nama = nama
    }
}

@Model
final class AsetNonFinansial {
    var id: UUID
    var kategoriAsetID: UUID
    var namaAset: String
    var nilaiPasarTerakhir: Double
    var catatan: String?
    var updatedAt: Date

    init(kategoriAsetID: UUID, namaAset: String, nilaiPasarTerakhir: Double = 0, catatan: String? = nil) {
        self.id = UUID()
        self.kategoriAsetID = kategoriAsetID
        self.namaAset = namaAset
        self.nilaiPasarTerakhir = nilaiPasarTerakhir
        self.catatan = catatan
        self.updatedAt = Date()
    }
}
