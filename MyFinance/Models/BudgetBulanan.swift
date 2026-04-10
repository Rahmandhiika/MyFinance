import SwiftData
import Foundation

@Model
final class BudgetBulanan {
    var id: UUID
    var kategoriExpenseID: UUID
    var nominalBudget: Double
    var bulan: Int
    var tahun: Int

    init(kategoriExpenseID: UUID, nominalBudget: Double, bulan: Int, tahun: Int) {
        self.id = UUID()
        self.kategoriExpenseID = kategoriExpenseID
        self.nominalBudget = nominalBudget
        self.bulan = bulan
        self.tahun = tahun
    }
}

@Model
final class RencanaAnggaranTahunan {
    var id: UUID
    var tahun: Int
    var kategoriExpenseID: UUID
    var nominalBudget: Double

    init(tahun: Int, kategoriExpenseID: UUID, nominalBudget: Double) {
        self.id = UUID()
        self.tahun = tahun
        self.kategoriExpenseID = kategoriExpenseID
        self.nominalBudget = nominalBudget
    }
}
