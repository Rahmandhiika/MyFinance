import SwiftData
import Foundation

@Model
final class UserProfile {
    var id: UUID
    var nama: String
    var greetingText: String
    var fotoProfil: Data?

    init(nama: String = "Dika", greetingText: String = "Welcome back") {
        self.id = UUID()
        self.nama = nama
        self.greetingText = greetingText
    }
}

@Model
final class DanaDaruratConfig {
    var id: UUID
    var jumlahBulan: Int
    var prioritasIncluded: [String]

    init(jumlahBulan: Int = 3, prioritasIncluded: [String] = []) {
        self.id = UUID()
        self.jumlahBulan = jumlahBulan
        self.prioritasIncluded = prioritasIncluded
    }
}
