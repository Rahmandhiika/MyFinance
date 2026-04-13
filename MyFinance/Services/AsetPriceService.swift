import Foundation
import Observation

@Observable
class AsetPriceService {
    static let shared = AsetPriceService()
    var isLoading = false
    var lastUpdated: Date? = nil

    private init() {}

    // Fetch all prices for given aset array, update nilaiSaatIni in place
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
            // nilaiSaatIni = harga per lembar × lot × 100
            let lot = NSDecimalNumber(decimal: aset.lot ?? 0).doubleValue
            return Decimal(Double(truncating: harga as NSDecimalNumber) * lot * 100)
        case .kripto:
            return await fetchKriptoPrice(kode: aset.kode ?? aset.nama, mataUang: aset.mataUang ?? .idr)
        case .reksadana:
            return await fetchReksadanaNav(kode: aset.kode ?? aset.nama)
        case .emas:
            return await fetchEmasPrice(jenis: aset.jenisEmas ?? .lmAntam, tahun: aset.tahunCetak)
        }
    }

    // MARK: - Saham (IDX via Yahoo Finance)

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

    // MARK: - Kripto (CoinGecko)

    private func fetchKriptoPrice(kode: String, mataUang: MataUangKripto) async -> Decimal? {
        let coinMap: [String: String] = [
            "BTC": "bitcoin", "ETH": "ethereum", "BNB": "binancecoin",
            "SOL": "solana", "ADA": "cardano", "DOGE": "dogecoin",
            "XRP": "ripple", "DOT": "polkadot", "MATIC": "matic-network",
            "LINK": "chainlink", "AVAX": "avalanche-2", "UNI": "uniswap",
            "LTC": "litecoin", "ATOM": "cosmos", "NEAR": "near",
            "FTM": "fantom", "ALGO": "algorand", "VET": "vechain",
            "TRX": "tron", "XLM": "stellar"
        ]
        let coinID = coinMap[kode.uppercased()] ?? kode.lowercased()
        let currency = mataUang == .idr ? "idr" : "usd"
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(coinID)&vs_currencies=\(currency)") else { return nil }
        do {
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let coinData = json[coinID] as? [String: Any],
               let price = coinData[currency] as? Double {
                return Decimal(price)
            }
        } catch { }
        return nil
    }

    // MARK: - Reksadana (no free API, manual only)

    private func fetchReksadanaNav(kode: String) async -> Decimal? {
        // No reliable free public API for Indonesian reksadana NAV.
        // Return nil so user maintains value manually.
        return nil
    }

    // MARK: - Emas (no free scraping API, manual only)

    private func fetchEmasPrice(jenis: JenisEmas, tahun: Int?) async -> Decimal? {
        // Antam prices require scraping logammulia.com which is complex.
        // Return nil so user maintains value manually.
        return nil
    }
}
