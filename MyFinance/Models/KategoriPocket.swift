import SwiftData
import Foundation

@Model final class KategoriPocket {
    var id: UUID
    var nama: String

    init(nama: String) {
        self.id = UUID()
        self.nama = nama
    }
}
