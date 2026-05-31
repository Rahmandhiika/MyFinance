import Foundation
import Observation

@Observable
class AsetPriceService {
    static let shared = AsetPriceService()
    var isLoading = false

    /// Waktu terakhir harga diupdate — in-memory saja (tidak di-persist).
    /// Artinya: kill app + relaunch = selalu fetch fresh.
    /// Guard hanya berlaku dalam satu sesi (tab switch, scroll, dll).
    var lastUpdated: Date? = nil

    /// Harga dianggap masih fresh selama 15 menit dalam satu sesi.
    private let freshnessInterval: TimeInterval = 15 * 60

    private init() {}

    // MARK: - Refresh All (concurrent — all fetches start simultaneously)

    /// - Parameter force: true = selalu fetch, abaikan cache (tombol refresh manual / pull-to-refresh).
    ///                    false (default) = skip kalau data masih fresh (< 15 menit).
    func refreshAll(_ asets: [Aset], force: Bool = false) async {
        // Staleness guard — skip kalau bukan force dan data masih fresh
        if !force, let last = lastUpdated,
           Date().timeIntervalSince(last) < freshnessInterval {
            return
        }
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
            // Decimal × Decimal — no Double roundtrip, precision preserved
            aset.nilaiSaatIni = harga * (aset.lot ?? 0) * 100

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

    // MARK: - Retry helper

    /// Coba fetch sampai maxAttempts kali — tunggu 1 detik antar percobaan
    private func withRetry<T>(maxAttempts: Int = 2, fetch: () async -> T?) async -> T? {
        for attempt in 1...maxAttempts {
            if let result = await fetch() { return result }
            if attempt < maxAttempts { try? await Task.sleep(for: .seconds(1)) }
        }
        return nil
    }

    // MARK: - Saham IDN (IDX via Yahoo Finance — appends .JK)

    func fetchSahamPrice(kode: String) async -> Decimal? {
        await withRetry { [self] in await _fetchYahooPrice(ticker: kode.uppercased().hasSuffix(".JK") ? kode.uppercased() : "\(kode.uppercased()).JK") }
    }

    // MARK: - Saham AS (US Stocks via Yahoo Finance)

    func fetchUSStockPrice(ticker: String) async -> Decimal? {
        await withRetry { [self] in await _fetchYahooPrice(ticker: ticker.uppercased()) }
    }

    // MARK: - Valas (Yahoo Finance — same source as stock prices, real-time market rate)

    func fetchKursValas(_ mata: MataUangValas) async -> Decimal? {
        await withRetry { [self] in await _fetchYahooPrice(ticker: "\(mata.apiCode)IDR=X") }
    }

    /// Shared Yahoo Finance fetch — gunakan ticker langsung
    private func _fetchYahooPrice(ticker: String) async -> Decimal? {
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(ticker)") else { return nil }
        do {
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let chart  = json["chart"] as? [String: Any],
               let result = (chart["result"] as? [[String: Any]])?.first,
               let meta   = result["meta"] as? [String: Any],
               let price  = meta["regularMarketPrice"] as? Double {
                return Decimal(price)
            }
        } catch { }
        return nil
    }

    // MARK: - Fundamental Data (saham IDN & AS)

    struct SahamFundamental {
        let pe: Double?           // P/E ratio (trailing)
        let eps: Double?          // EPS (trailing)
        let marketCap: Double?    // Market cap (raw)
        let dividendYield: Double? // Dividend yield (0.02 = 2%)
    }

    func fetchFundamental(ticker: String) async -> SahamFundamental? {
        let symbol = ticker.uppercased().hasSuffix(".JK") ? ticker.uppercased() : ticker.uppercased()
        guard let url = URL(string: "https://query1.finance.yahoo.com/v10/finance/quoteSummary/\(symbol)?modules=summaryDetail,defaultKeyStatistics") else { return nil }

        do {
            var req = URLRequest(url: url, timeoutInterval: 10)
            req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json     = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result   = (json["quoteSummary"] as? [String: Any])?["result"] as? [[String: Any]],
                  let first    = result.first else { return nil }

            let summary = first["summaryDetail"] as? [String: Any]
            let stats   = first["defaultKeyStatistics"] as? [String: Any]

            func raw(_ dict: [String: Any]?, _ key: String) -> Double? {
                (dict?[key] as? [String: Any])?["raw"] as? Double
            }

            return SahamFundamental(
                pe:            raw(summary, "trailingPE"),
                eps:           raw(stats,   "trailingEps"),
                marketCap:     raw(summary, "marketCap"),
                dividendYield: raw(summary, "dividendYield")
            )
        } catch { return nil }
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
