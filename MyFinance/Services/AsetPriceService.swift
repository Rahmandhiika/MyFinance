import Foundation
import Observation

@Observable
class AsetPriceService {
    static let shared = AsetPriceService()
    var isLoading = false
    var lastUpdated: Date? = nil

    private init() {}

    // MARK: - Refresh All

    func refreshAll(_ asets: [Aset]) async {
        isLoading = true
        defer {
            isLoading = false
            lastUpdated = Date()
        }

        for aset in asets {
            if let nilai = await fetchPrice(for: aset) {
                await MainActor.run { aset.nilaiSaatIni = nilai }
            }
        }
    }

    private func fetchPrice(for aset: Aset) async -> Decimal? {
        switch aset.tipe {
        case .saham:
            guard let harga = await fetchSahamPrice(kode: aset.kode ?? aset.nama) else { return nil }
            let lot = NSDecimalNumber(decimal: aset.lot ?? 0).doubleValue
            return Decimal(Double(truncating: harga as NSDecimalNumber) * lot * 100)

        case .sahamAS:
            guard let kode = aset.kode, !kode.isEmpty else { return nil }
            async let hargaTask = fetchUSStockPrice(ticker: kode)
            async let kursTask = fetchKursValas(.usd)
            let (harga, kurs) = await (hargaTask, kursTask)
            let finalHarga = harga ?? aset.hargaSaatIniUSD
            let finalKurs = kurs ?? aset.kursSaatIniUSD
            guard let h = finalHarga, let k = finalKurs else { return nil }
            await MainActor.run {
                if let h = harga { aset.hargaSaatIniUSD = h }
                if let k = kurs { aset.kursSaatIniUSD = k }
            }
            return aset.jumlahSharesAS * h * k

        case .valas:
            guard let mata = aset.mataUangValas,
                  let jumlah = aset.jumlahValas,
                  let kurs = await fetchKursValas(mata) else { return nil }
            await MainActor.run { aset.kursSaatIni = kurs }
            return jumlah * kurs

        case .reksadana:
            // NAV reksadana Indonesia tidak ada free API — user update manual
            return nil

        case .emas:
            // Harga emas perlu scraping — user update manual
            return nil

        case .deposito:
            // Deposito tidak ada harga pasar — nilaiSaatIni = nominal
            return nil
        }
    }

    // MARK: - Saham IDN (IDX via Yahoo Finance — appends .JK)

    func fetchSahamPrice(kode: String) async -> Decimal? {
        let ticker = kode.uppercased().hasSuffix(".JK") ? kode.uppercased() : "\(kode.uppercased()).JK"
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(ticker)") else { return nil }
        do {
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let chart = json["chart"] as? [String: Any],
               let result = (chart["result"] as? [[String: Any]])?.first,
               let meta = result["meta"] as? [String: Any],
               let price = meta["regularMarketPrice"] as? Double {
                return Decimal(price)
            }
        } catch { }
        return nil
    }

    // MARK: - Saham AS (US Stocks via Yahoo Finance — no .JK suffix)

    func fetchUSStockPrice(ticker: String) async -> Decimal? {
        let symbol = ticker.uppercased()
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)") else { return nil }
        do {
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let chart = json["chart"] as? [String: Any],
               let result = (chart["result"] as? [[String: Any]])?.first,
               let meta = result["meta"] as? [String: Any],
               let price = meta["regularMarketPrice"] as? Double {
                return Decimal(price)
            }
        } catch { }
        return nil
    }

    // MARK: - Valas (Frankfurter API — free, no key needed)
    // Base: IDR, mengambil berapa 1 unit valas = berapa IDR

    func fetchKursValas(_ mata: MataUangValas) async -> Decimal? {
        // Frankfurter: /latest?from=USD&to=IDR → {"rates":{"IDR":16350.0}}
        guard let url = URL(string: "https://api.frankfurter.app/latest?from=\(mata.apiCode)&to=IDR") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rates = json["rates"] as? [String: Any],
               let kurs = rates["IDR"] as? Double {
                return Decimal(kurs)
            }
        } catch { }
        return nil
    }

    /// Fetch semua kurs sekaligus untuk ditampilkan di form
    func fetchAllKurs() async -> [MataUangValas: Decimal] {
        var result: [MataUangValas: Decimal] = [:]
        for mata in MataUangValas.allCases {
            if let kurs = await fetchKursValas(mata) {
                result[mata] = kurs
            }
        }
        return result
    }
}
