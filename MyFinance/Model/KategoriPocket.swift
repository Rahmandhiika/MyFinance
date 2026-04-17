import SwiftData
import Foundation

@Model final class KategoriPocket {
    var id: UUID
    var nama: String
    var urutan: Int = 0

    init(nama: String, urutan: Int = 0) {
        self.id = UUID()
        self.nama = nama
        self.urutan = urutan
    }
}
