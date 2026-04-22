import SwiftData
import Foundation

@Model final class Aset {
    var id: UUID
    var tipe: TipeAset
    var nama: String
    var kode: String?      // ticker saham (BBCA, BBRI, dll)

    // MARK: - Saham
    var lot: Decimal?
    var hargaPerLembar: Decimal?

    // MARK: - Reksadana
    var jenisReksadana: String?
    var totalInvestasiReksadana: Decimal?
    var hargaBeliPerUnit: Decimal?   // NAV waktu beli
    var navSaatIni: Decimal?         // NAV terkini (user update manual)
    var jumlahUnitReksadana: Decimal? = nil  // unit aktual (override kalkulasi otomatis)

    // MARK: - Saham AS (US Stocks / ETF — Pluang)
    var totalInvestasiUSD: Decimal?   // total USD yang diinvest (misal $60)
    var hargaBeliPerShareUSD: Decimal? // harga per share saat beli (USD)
    var hargaSaatIniUSD: Decimal?     // harga terkini (USD, auto-fetch Yahoo)
    var kursBeliUSD: Decimal?         // kurs IDR/USD saat beli
    var kursSaatIniUSD: Decimal?      // kurs IDR/USD terkini (auto-fetch)

    // MARK: - Valas
    var mataUangValas: MataUangValas?
    var jumlahValas: Decimal?        // unit valas yang dimiliki
    var kursBeliPerUnit: Decimal?    // kurs IDR saat beli
    var kursSaatIni: Decimal?        // kurs IDR terkini (auto-fetch)

    // MARK: - Emas
    var jenisEmas: JenisEmas?
    var tahunCetak: Int?             // nil untuk emas digital
    var beratGram: Decimal?
    var hargaBeliPerGram: Decimal?

    // MARK: - Deposito
    var nominalDeposito: Decimal?
    var bungaPA: Decimal?            // % per annum
    var pphFinal: Decimal?           // % pajak (default 20)
    var tenorBulan: Int?             // 1/3/6/12/24/36
    var tanggalMulaiDeposito: Date?
    var autoRollOver: Bool

    // MARK: - Common
    var nilaiSaatIni: Decimal        // stored, diupdate oleh price service
    var urutan: Int = 0              // urutan tampil di list (drag reorder)
    var portofolio: String? = nil    // nama portofolio/bucket opsional (mis. "Dana Pensiun")
    var logoData: Data? = nil        // foto/logo custom yang di-upload user (optional)
    var catatSbgPengeluaran: Bool
    var pocketSumber: Pocket?        // pocket sumber (pembelian / deposito)
    var createdAt: Date

    /// Target investasi yang menggunakan aset ini sebagai wadah dana.
    /// Cascade: Aset dihapus → Target ikut dihapus otomatis.
    @Relationship(deleteRule: .cascade, inverse: \Target.linkedAset)
    var linkedTarget: Target?

    // MARK: - Computed: Modal (biaya yang dikeluarkan)

    var modal: Decimal {
        switch tipe {
        case .saham:
            return (lot ?? 0) * (hargaPerLembar ?? 0) * 100
        case .sahamAS:
            return (totalInvestasiUSD ?? 0) * (kursBeliUSD ?? 0)
        case .reksadana:
            return totalInvestasiReksadana ?? 0
        case .valas:
            return (jumlahValas ?? 0) * (kursBeliPerUnit ?? 0)
        case .emas:
            return (beratGram ?? 0) * (hargaBeliPerGram ?? 0)
        case .deposito:
            return nominalDeposito ?? 0
        }
    }

    /// Jumlah shares US stock = totalUSD / hargaBeliPerShare
    var jumlahSharesAS: Decimal {
        guard tipe == .sahamAS,
              let total = totalInvestasiUSD,
              let hargaBeli = hargaBeliPerShareUSD,
              hargaBeli > 0 else { return 0 }
        return total / hargaBeli
    }

    /// Nilai efektif: untuk deposito = nominal + bunga bersih s/d hari ini; lainnya = nilaiSaatIni
    var nilaiEfektif: Decimal {
        if tipe == .deposito {
            return (nominalDeposito ?? 0) + bungaBersihDeposito
        }
        return nilaiSaatIni
    }

    var pnl: Decimal { nilaiEfektif - modal }

    var returnPersen: Double {
        guard modal > 0 else { return 0 }
        return Double(truncating: (pnl / modal * 100) as NSDecimalNumber)
    }

    // MARK: - Computed: Deposito helpers

    /// Bunga bersih deposito dihitung dari hari berjalan hingga hari ini
    var bungaBersihDeposito: Decimal {
        guard tipe == .deposito,
              let nominal = nominalDeposito,
              let bunga = bungaPA,
              let pph = pphFinal,
              let start = tanggalMulaiDeposito else { return 0 }
        let hari = max(Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0, 0)
        let bungaKotor = nominal * (bunga / 100) * (Decimal(hari) / 365)
        return bungaKotor * (1 - pph / 100)
    }

    var jatuhTempoDeposito: Date? {
        guard let start = tanggalMulaiDeposito, let tenor = tenorBulan else { return nil }
        return Calendar.current.date(byAdding: .month, value: tenor, to: start)
    }

    var progressDeposito: Double {
        guard let start = tanggalMulaiDeposito,
              let jatuhTempo = jatuhTempoDeposito else { return 0 }
        let total = jatuhTempo.timeIntervalSince(start)
        let elapsed = Date().timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return min(max(elapsed / total, 0), 1)
    }

    var hariLagiDeposito: Int {
        guard let jatuhTempo = jatuhTempoDeposito else { return 0 }
        return max(Calendar.current.dateComponents([.day], from: Date(), to: jatuhTempo).day ?? 0, 0)
    }

    // MARK: - Computed: Reksadana helpers

    /// Jumlah unit reksadana — pakai nilai manual jika ada, fallback ke kalkulasi
    var estimasiUnitReksadana: Decimal {
        if let manual = jumlahUnitReksadana, manual > 0 { return manual }
        guard tipe == .reksadana,
              let total = totalInvestasiReksadana,
              let hargaBeli = hargaBeliPerUnit,
              hargaBeli > 0 else { return 0 }
        return total / hargaBeli
    }

    // MARK: - Init

    init(tipe: TipeAset, nama: String, kode: String? = nil) {
        self.id = UUID()
        self.tipe = tipe
        self.nama = nama
        self.kode = kode
        self.nilaiSaatIni = 0
        self.urutan = 0
        self.catatSbgPengeluaran = false
        self.autoRollOver = false
        self.createdAt = Date()
    }
}
