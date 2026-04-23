import Foundation
import Observation

@Observable
class AsetPriceService {
    static let shared = AsetPriceService()
    var isLoading = false
    var lastUpdated: Date? = nil

    private init() {}

    // MARK: - Refresh All (concurrent — all fetches start simultaneously)

    func refreshAll(_ asets: [Aset]) async {
        isLoading = true
        defer {
            isLoading = false
            lastUpdated = Date()
        }

        // Kick off all price fetches in parallel, then apply results in one pass
        await withTaskGroup(of: Void.self) { group in
            for aset in asets {
                group.addTask { @MainActor in
                    await self.fetchAndApply(aset: aset)
                }
            }
        }
    }

    // MARK: - Per-aset fetch + apply

    private func fetchAndApply(aset: Aset) async {
        switch aset.tipe {

        case .saham:
            guard let harga = await fetchSahamPrice(kode: aset.kode ?? aset.nama) else { return }
            let lot = NSDecimalNumber(decimal: aset.lot ?? 0).doubleValue
            aset.nilaiSaatIni = Decimal(Double(truncating: harga as NSDecimalNumber) * lot * 100)

        case .sahamAS:
            guard let kode = aset.kode, !kode.isEmpty else { return }
            // Fetch harga & kurs concurrently for this single asset
            async let hargaTask = fetchUSStockPrice(ticker: kode)
            async let kursTask  = fetchKursValas(.usd)
            let (harga, kurs)   = await (hargaTask, kursTask)
            let finalHarga = harga ?? aset.hargaSaatIniUSD
            let finalKurs  = kurs  ?? aset.kursSaatIniUSD
            guard let h = finalHarga, let k = finalKurs else { return }
            if let h = harga { aset.hargaSaatIniUSD = h }
            if let k = kurs  { aset.kursSaatIniUSD  = k }
            aset.nilaiSaatIni = aset.jumlahSharesAS * h * k

        case .valas:
            guard let mata   = aset.mataUangValas,
                  let jumlah = aset.jumlahValas,
                  let kurs   = await fetchKursValas(mata) else { return }
            aset.kursSaatIni  = kurs
            aset.nilaiSaatIni = jumlah * kurs

        case .reksadana, .emas, .deposito:
            // User update manual — no auto-fetch
            break
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
               let chart  = json["chart"] as? [String: Any],
               let result = (chart["result"] as? [[String: Any]])?.first,
               let meta   = result["meta"] as? [String: Any],
               let price  = meta["regularMarketPrice"] as? Double {
                return Decimal(price)
            }
        } catch { }
        return nil
    }

    // MARK: - Saham AS (US Stocks via Yahoo Finance)

    func fetchUSStockPrice(ticker: String) async -> Decimal? {
        let symbol = ticker.uppercased()
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)") else { return nil }
        do {
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let chart  = json["chart"] as? [String: Any],
               let result = (chart["result"] as? [[String: Any]])?.first,
               let meta   = result["meta"] as? [String: Any],
               let price  = meta["regularMarketPrice"] as? Double {
                return Decimal(price)
            }
        } catch { }
        return nil
    }

    // MARK: - Valas (Yahoo Finance — same source as stock prices, real-time market rate)

    func fetchKursValas(_ mata: MataUangValas) async -> Decimal? {
        let ticker = "\(mata.apiCode)IDR=X"
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(ticker)") else { return nil }
        do {
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let chart  = json["chart"] as? [String: Any],
               let result = (chart["result"] as? [[String: Any]])?.first,
               let meta   = result["meta"] as? [String: Any],
               let kurs   = meta["regularMarketPrice"] as? Double {
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
