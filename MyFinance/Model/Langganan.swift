import SwiftData
import Foundation

@Model final class Langganan {
    var id: UUID
    var nama: String
    var nominal: Decimal
    var tanggalTagih: Int       // 1–28
    var kategori: Kategori?
    var logo: Data?             // foto custom
    var catatan: String?
    var isAktif: Bool = true
    var urutan: Int = 0
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PembayaranLangganan.langganan)
    var pembayaran: [PembayaranLangganan] = []

    init(nama: String, nominal: Decimal, tanggalTagih: Int,
         kategori: Kategori? = nil, catatan: String? = nil) {
        self.id = UUID()
        self.nama = nama
        self.nominal = nominal
        self.tanggalTagih = tanggalTagih
        self.kategori = kategori
        self.catatan = catatan
        self.createdAt = Date()
    }
}

@Model final class PembayaranLangganan {
    var id: UUID
    var langganan: Langganan?
    var bulan: Int              // 1–12
    var tahun: Int
    var pocket: Pocket?
    var transaksiID: UUID?      // untuk rollback kalau di-uncheck
    var createdAt: Date

    init(langganan: Langganan? = nil, bulan: Int, tahun: Int,
         pocket: Pocket? = nil, transaksiID: UUID? = nil) {
        self.id = UUID()
        self.langganan = langganan
        self.bulan = bulan
        self.tahun = tahun
        self.pocket = pocket
        self.transaksiID = transaksiID
        self.createdAt = Date()
    }
}
