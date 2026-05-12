import Foundation
import Observation

// MARK: - Model

struct MarketIndexData: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let flag: String
    let currentPrice: Double
    let previousClose: Double
    let chartPoints: [Double]   // daily close, last ~30 days

    var changeAbs: Double { currentPrice - previousClose }
    var changePct: Double {
        guard previousClose > 0 else { return 0 }
        return (currentPrice - previousClose) / previousClose * 100
    }
    var isPositive: Bool { changeAbs >= 0 }

    var priceFormatted: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        return f.string(from: NSNumber(value: currentPrice)) ?? "\(currentPrice)"
    }

    var changePctFormatted: String {
        String(format: "%+.2f%%", changePct)
    }

    var changeAbsFormatted: String {
        String(format: "%+.2f", changeAbs)
    }
}

// MARK: - Service

@Observable
class MarketIndexService {
    static let shared = MarketIndexService()

    var ihsg: MarketIndexData?
    var sp500: MarketIndexData?
    var isLoading = false
    var lastUpdated: Date?
    var errorMessage: String?

    private init() {}

    func refresh() async {
        guard !isLoading else { return }
        await MainActor.run { isLoading = true; errorMessage = nil }

        async let ihsgTask  = fetchIndex(symbol: "^JKSE",  name: "IHSG",    flag: "🇮🇩")
        async let sp500Task = fetchIndex(symbol: "^GSPC",  name: "S&P 500", flag: "🇺🇸")
        let (i, s) = await (ihsgTask, sp500Task)

        await MainActor.run {
            if let i { self.ihsg  = i }
            if let s { self.sp500 = s }
            self.isLoading  = false
            self.lastUpdated = Date()
        }
    }

    // MARK: - Fetch single index with 1-month chart data

    private func fetchIndex(symbol: String, name: String, flag: String) async -> MarketIndexData? {
        // Encode ^ → %5E so URL parses correctly
        let encoded = symbol.replacingOccurrences(of: "^", with: "%5E")
        let urlStr = "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?interval=1d&range=1mo"
        guard let url = URL(string: urlStr) else { return nil }

        do {
            var req = URLRequest(url: url, timeoutInterval: 12)
            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: req)

            guard
                let json   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let chart  = json["chart"] as? [String: Any],
                let result = (chart["result"] as? [[String: Any]])?.first,
                let meta   = result["meta"] as? [String: Any],
                let current = meta["regularMarketPrice"] as? Double,
                let prevClose = meta["chartPreviousClose"] as? Double
                    ?? meta["previousClose"] as? Double
            else { return nil }

            // Daily close prices for mini chart
            var closes: [Double] = []
            if let indicators = result["indicators"] as? [String: Any],
               let quoteArr   = indicators["quote"] as? [[String: Any]],
               let quote      = quoteArr.first,
               let rawCloses  = quote["close"] as? [Double?] {
                closes = rawCloses.compactMap { $0 }.filter { $0 > 0 }
            }
            // Append current price as last point
            closes.append(current)

            return MarketIndexData(
                symbol: symbol,
                name: name,
                flag: flag,
                currentPrice: current,
                previousClose: prevClose,
                chartPoints: closes
            )
        } catch {
            return nil
        }
    }
}
