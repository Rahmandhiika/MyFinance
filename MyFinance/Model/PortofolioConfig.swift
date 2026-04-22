import SwiftData
import Foundation

@Model final class PortofolioConfig {
    var id: UUID
    var nama: String
    var warna: String       // hex color string, e.g. "#A78BFA"
    var urutan: Int
    var createdAt: Date

    init(nama: String, warna: String = "#A78BFA", urutan: Int = 0) {
        self.id = UUID()
        self.nama = nama
        self.warna = warna
        self.urutan = urutan
        self.createdAt = Date()
    }
}
