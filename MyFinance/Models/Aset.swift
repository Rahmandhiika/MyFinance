import SwiftData
import Foundation

@Model final class Aset {
    var id: UUID
    var tipe: TipeAset
    var nama: String
    var kode: String?

    // Saham
    var lot: Decimal?
    var hargaPerLembar: Decimal?

    // Kripto
    var mataUang: MataUangKripto?
    var totalInvestasiKripto: Decimal?
    var hargaPerUnit: Decimal?

    // Reksadana
    var jenisReksadana: String?
    var totalInvestasiReksadana: Decimal?
    var nav: Decimal?

    // Emas
    var jenisEmas: JenisEmas?
    var tahunCetak: Int?
    var beratGram: Decimal?
    var hargaBeliPerGram: Decimal?

    // Common
    var nilaiSaatIni: Decimal
    var catatSbgPengeluaran: Bool
    var pocketSumber: Pocket?
    var createdAt: Date

    // Computed
    var modal: Decimal {
        switch tipe {
        case .saham:
            return (lot ?? 0) * (hargaPerLembar ?? 0) * 100  // 1 lot = 100 lembar
        case .kripto:
            return totalInvestasiKripto ?? 0
        case .reksadana:
            return totalInvestasiReksadana ?? 0
        case .emas:
            return (beratGram ?? 0) * (hargaBeliPerGram ?? 0)
        }
    }
    var pnl: Decimal { nilaiSaatIni - modal }
    var returnPersen: Double {
        guard modal > 0 else { return 0 }
        return Double(truncating: (pnl / modal * 100) as NSDecimalNumber)
    }

    init(tipe: TipeAset, nama: String, kode: String? = nil) {
        self.id = UUID()
        self.tipe = tipe
        self.nama = nama
        self.kode = kode
        self.nilaiSaatIni = 0
        self.catatSbgPengeluaran = false
        self.createdAt = Date()
    }
}
