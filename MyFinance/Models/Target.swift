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
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SimpanKeTarget.target)
    var riwayat: [SimpanKeTarget] = []

    // Computed
    var tersimpan: Decimal { riwayat.reduce(Decimal(0)) { $0 + $1.nominal } }
    var sisa: Decimal { max(targetNominal - tersimpan, 0) }
    var progressPersen: Double {
        guard targetNominal > 0 else { return 0 }
        return Double(truncating: (tersimpan / targetNominal * 100) as NSDecimalNumber)
    }

    init(nama: String, targetNominal: Decimal = 0, deadline: Date? = nil,
         ikon: String = "target", warna: String = "#22C55E") {
        self.id = UUID()
        self.nama = nama
        self.targetNominal = targetNominal
        self.deadline = deadline
        self.ikonCustom = nil
        self.ikon = ikon
        self.warna = warna
        self.catatan = nil
        self.isSelesai = false
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
