import SwiftData
import Foundation

// MARK: - Budget Bulanan

@Model
final class BudgetBulanan {
    var id: UUID
    var kategoriID: UUID
    var nominalBudget: Double
    var bulan: Int    // 1–12
    var tahun: Int

    init(kategoriID: UUID, nominalBudget: Double, bulan: Int, tahun: Int) {
        self.id = UUID()
        self.kategoriID = kategoriID
        self.nominalBudget = nominalBudget
        self.bulan = bulan
        self.tahun = tahun
    }
}

// MARK: - Rencana Anggaran Tahunan

@Model
final class RencanaAnggaranTahunan {
    var id: UUID
    var tahun: Int
    var kategoriID: UUID
    var nominalBudget: Double

    init(tahun: Int, kategoriID: UUID, nominalBudget: Double) {
        self.id = UUID()
        self.tahun = tahun
        self.kategoriID = kategoriID
        self.nominalBudget = nominalBudget
    }
}

// MARK: - Dana Darurat Config

@Model
final class DanaDaruratConfig {
    var id: UUID
    var jumlahBulan: Int
    var prioritasIncluded: [String]  // ["p0","p1","p2"] — Prioritas.rawValue

    init(jumlahBulan: Int = 3, prioritasIncluded: [String] = ["p0", "p1", "p2"]) {
        self.id = UUID()
        self.jumlahBulan = jumlahBulan
        self.prioritasIncluded = prioritasIncluded
    }
}
