import SwiftData
import Foundation

@Model
final class KategoriExpense {
    var id: UUID
    var nama: String
    var prioritas: Prioritas
    var kelompok: KelompokExpense
    var createdAt: Date

    init(nama: String, prioritas: Prioritas = .blank, kelompok: KelompokExpense = .expense) {
        self.id = UUID()
        self.nama = nama
        self.prioritas = prioritas
        self.kelompok = kelompok
        self.createdAt = Date()
    }
}

@Model
final class KategoriIncome {
    var id: UUID
    var nama: String
    var kelompokIncome: KelompokIncome
    var createdAt: Date

    init(nama: String, kelompokIncome: KelompokIncome = .gaji) {
        self.id = UUID()
        self.nama = nama
        self.kelompokIncome = kelompokIncome
        self.createdAt = Date()
    }
}
