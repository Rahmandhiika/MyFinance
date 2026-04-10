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

@Model
final class FGI {
    var id: UUID
    var tanggal: Date
    var nilai: Int

    init(tanggal: Date, nilai: Int) {
        self.id = UUID()
        self.tanggal = tanggal
        self.nilai = max(0, min(100, nilai))
    }

    var label: String {
        switch nilai {
        case 0..<25: return "Extreme Fear"
        case 25..<45: return "Fear"
        case 45..<55: return "Neutral"
        case 55..<75: return "Greed"
        default: return "Extreme Greed"
        }
    }

    var color: String {
        switch nilai {
        case 0..<25: return "#DC2626"
        case 25..<45: return "#F97316"
        case 45..<55: return "#EAB308"
        case 55..<75: return "#22C55E"
        default: return "#16A34A"
        }
    }
}
