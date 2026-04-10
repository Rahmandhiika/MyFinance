import SwiftData
import Foundation

@Model
final class Goal {
    var id: UUID
    var nama: String
    var tipe: TipeGoal
    var targetNominal: Double
    var deadline: Date?
    var gambar: Data?
    var catatan: String?
    var isSelesai: Bool
    var createdAt: Date

    init(nama: String, tipe: TipeGoal, targetNominal: Double,
         deadline: Date? = nil, catatan: String? = nil) {
        self.id = UUID()
        self.nama = nama
        self.tipe = tipe
        self.targetNominal = targetNominal
        self.deadline = deadline
        self.catatan = catatan
        self.isSelesai = false
        self.createdAt = Date()
    }

}

@Model
final class RiwayatMencicilMenabung {
    var id: UUID
    var goalID: UUID
    var tanggal: Date
    var nominal: Double
    var catatan: String?

    init(goalID: UUID, tanggal: Date, nominal: Double, catatan: String? = nil) {
        self.id = UUID()
        self.goalID = goalID
        self.tanggal = tanggal
        self.nominal = nominal
        self.catatan = catatan
    }
}
