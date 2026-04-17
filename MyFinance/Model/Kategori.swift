import SwiftData
import Foundation

@Model final class Kategori {
    var id: UUID
    var nama: String
    var tipe: TipeTransaksi
    var klasifikasi: KlasifikasiExpense?   // only for Pengeluaran
    var kelompokIncome: KelompokIncome?    // only for Pemasukan
    var ikon: String                       // SF Symbol name
    var ikonCustom: String?                // emoji
    var warna: String                      // hex color e.g. "#22C55E"
    var urutan: Int
    var isNabung: Bool = false      // → masuk Nabung Bulan Ini
    var isAdmin: Bool = false       // → auto-assign ke biaya admin transfer/jual
    var isHasilAset: Bool = false   // → auto-assign ke pemasukan hasil jual aset
    var createdAt: Date

    init(nama: String, tipe: TipeTransaksi, klasifikasi: KlasifikasiExpense? = nil,
         kelompokIncome: KelompokIncome? = nil, ikon: String = "tag",
         warna: String = "#6B7280", urutan: Int = 0) {
        self.id = UUID()
        self.nama = nama
        self.tipe = tipe
        self.klasifikasi = klasifikasi
        self.kelompokIncome = kelompokIncome
        self.ikon = ikon
        self.ikonCustom = nil
        self.warna = warna
        self.urutan = urutan
        self.createdAt = Date()
    }
}
