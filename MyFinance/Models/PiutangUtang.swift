import SwiftData
import Foundation

@Model
final class Debitur {
    var id: UUID
    var nama: String
    var catatan: String?

    init(nama: String, catatan: String? = nil) {
        self.id = UUID()
        self.nama = nama
        self.catatan = catatan
    }
}

@Model
final class Kreditur {
    var id: UUID
    var nama: String
    var catatan: String?

    init(nama: String, catatan: String? = nil) {
        self.id = UUID()
        self.nama = nama
        self.catatan = catatan
    }
}
