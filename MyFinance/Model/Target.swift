import SwiftData
import Foundation

@Model final class Target {
    var id: UUID
    var nama: String
    var targetNominal: Decimal
    var deadline: Date?
    var ikonCustom: String?   // emoji
    var ikon: String          // SF Symbol name
    var warna: String         // hex color
    var catatan: String?
    var isSelesai: Bool
    var jenisTarget: JenisTarget  // biasa atau investasi
    var fotoData: Data?            // foto background kartu (opsional)
    var createdAt: Date
    var urutan: Int = 0            // untuk drag reorder
    var tampilDiHome: Bool = true  // kontrol visibilitas di HomeView

    @Relationship(deleteRule: .cascade, inverse: \SimpanKeTarget.target)
    var riwayat: [SimpanKeTarget] = []

    /// Untuk target investasi: aset yang menjadi "wadah" dana target ini.
    /// Cascade: Target dihapus → Aset TIDAK dihapus (nullify).
    /// Aset dihapus → Target ikut dihapus (dihandle di sisi Aset).
    var linkedAset: Aset?

    /// Untuk target biasa: pocket tempat uang tabungan ini disimpan.
    /// Setiap "Simpan ke Target" akan menambah saldo pocket ini.
    var linkedPocket: Pocket? = nil

    // MARK: - Computed

    /// Nilai yang sudah terkumpul:
    /// - Investasi: pakai nilaiEfektif aset (termasuk growth)
    /// - Biasa: sum dari SimpanKeTarget
    var tersimpan: Decimal {
        if let aset = linkedAset {
            return aset.nilaiEfektif
        }
        return riwayat.reduce(Decimal(0)) { $0 + $1.nominal }
    }

    var sisa: Decimal { max(targetNominal - tersimpan, 0) }

    var progressPersen: Double {
        guard targetNominal > 0 else { return 0 }
        return Double(truncating: (tersimpan / targetNominal * 100) as NSDecimalNumber)
    }

    init(nama: String, targetNominal: Decimal = 0, deadline: Date? = nil,
         ikon: String = "target", warna: String = "#22C55E",
         jenisTarget: JenisTarget = .biasa) {
        self.id = UUID()
        self.nama = nama
        self.targetNominal = targetNominal
        self.deadline = deadline
        self.ikonCustom = nil
        self.ikon = ikon
        self.warna = warna
        self.catatan = nil
        self.isSelesai = false
        self.jenisTarget = jenisTarget
        self.createdAt = Date()
    }
}

@Model final class SimpanKeTarget {
    var id: UUID
    var target: Target?
    var tanggal: Date
    var nominal: Decimal
    var catatan: String?
    var createdAt: Date

    init(target: Target? = nil, tanggal: Date = Date(), nominal: Decimal, catatan: String? = nil) {
        self.id = UUID()
        self.target = target
        self.tanggal = tanggal
        self.nominal = nominal
        self.catatan = catatan
        self.createdAt = Date()
    }
}
