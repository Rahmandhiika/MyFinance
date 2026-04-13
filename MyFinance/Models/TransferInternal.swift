import SwiftData
import Foundation

@Model final class TransferInternal {
    var id: UUID
    var tanggal: Date
    var nominal: Decimal
    var pocketAsal: Pocket?
    var pocketTujuan: Pocket?
    var catatan: String?
    var createdAt: Date

    init(tanggal: Date = Date(), nominal: Decimal, pocketAsal: Pocket? = nil,
         pocketTujuan: Pocket? = nil, catatan: String? = nil) {
        self.id = UUID()
        self.tanggal = tanggal
        self.nominal = nominal
        self.pocketAsal = pocketAsal
        self.pocketTujuan = pocketTujuan
        self.catatan = catatan
        self.createdAt = Date()
    }
}
