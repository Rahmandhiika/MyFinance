import SwiftData
import Foundation

@Model
final class UserProfile {
    var id: UUID
    var nama: String
    var greetingText: String
    var fotoProfil: Data?
    var tanggalGajian: Int?

    init(nama: String = "Dika", greetingText: String = "Welcome back") {
        self.id = UUID()
        self.nama = nama
        self.greetingText = greetingText
    }
}
