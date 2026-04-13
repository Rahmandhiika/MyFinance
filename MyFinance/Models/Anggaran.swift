import SwiftData
import Foundation

@Model final class Anggaran {
    var id: UUID
    var nominal: Decimal
    var tipeAnggaran: TipeAnggaran
    var kategori: Kategori?    // nil = keseluruhan
    var berulang: Bool         // Bulanan: reset otomatis tiap bulan
    var pindahan: Bool         // Bulanan: sisa dibawa ke bulan depan
    var harianBerulang: Bool   // Harian: tampil di semua hari
    var bulan: Int?            // 1–12, untuk Bulanan
    var tahun: Int?            // untuk Bulanan
    var tanggal: Date?         // untuk Harian
    var createdAt: Date

    init(nominal: Decimal, tipeAnggaran: TipeAnggaran, kategori: Kategori? = nil,
         berulang: Bool = false, pindahan: Bool = false, harianBerulang: Bool = false,
         bulan: Int? = nil, tahun: Int? = nil, tanggal: Date? = nil) {
        self.id = UUID()
        self.nominal = nominal
        self.tipeAnggaran = tipeAnggaran
        self.kategori = kategori
        self.berulang = berulang
        self.pindahan = pindahan
        self.harianBerulang = harianBerulang
        self.bulan = bulan
        self.tahun = tahun
        self.tanggal = tanggal
        self.createdAt = Date()
    }
}
