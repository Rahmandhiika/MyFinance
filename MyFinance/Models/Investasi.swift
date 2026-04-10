import SwiftData
import Foundation

@Model
final class InvestasiHolding {
    var id: UUID
    var pocketID: UUID
    var nama: String
    var tipe: TipeInvestasi
    var catatan: String?

    init(pocketID: UUID, nama: String, tipe: TipeInvestasi, catatan: String? = nil) {
        self.id = UUID()
        self.pocketID = pocketID
        self.nama = nama
        self.tipe = tipe
        self.catatan = catatan
    }
}
