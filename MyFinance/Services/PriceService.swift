import Foundation
import SwiftData

class PriceService {
    static let shared = PriceService()
    private init() {}

    func fetchAll(holdings: [InvestmentHolding], context: ModelContext) async {
        await withTaskGroup(of: Void.self) { group in
            for holding in holdings {
                group.addTask {
                    await self.fetch(ticker: holding.ticker, assetType: holding.assetType, context: context)
                }
            }
        }
    }

    func fetch(ticker: String, assetType: AssetType, context: ModelContext) async {
        switch assetType {
        case .stock, .etf, .commodity, .custom:
            await fetchStock(ticker: ticker, context: context)
        }
    }

    private func fetchStock(ticker: String, context: ModelContext) async {
        let urlStr = "https://query1.finance.yahoo.com/v8/finance/chart/\(ticker)?interval=1d&range=1d"
        guard let url = URL(string: urlStr) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let resp = try JSONDecoder().decode(YFResponse.self, from: data)
            guard let meta = resp.chart.result?.first?.meta else { return }
            let curr = meta.regularMarketPrice
            let prev = meta.previousClose ?? meta.chartPreviousClose ?? curr
            let chg  = prev > 0 ? ((curr - prev) / prev) * 100 : 0
            await upsert(ticker: ticker, price: curr, prev: prev, change: chg, currency: .IDR, context: context)
        } catch {}
    }

    private func upsert(ticker: String, price: Double, prev: Double, change: Double, currency: AppCurrency, context: ModelContext) async {
        let desc = FetchDescriptor<StockPrice>(predicate: #Predicate { $0.ticker == ticker })
        if let existing = (try? context.fetch(desc))?.first {
            existing.currentPrice  = price
            existing.previousClose = prev
            existing.changePercent = change
            existing.lastUpdated   = Date()
        } else {
            context.insert(StockPrice(ticker: ticker, currentPrice: price, previousClose: prev, changePercent: change, currency: currency))
        }
        try? context.save()
    }

    func cachedPrice(for ticker: String, context: ModelContext) -> StockPrice? {
        let desc = FetchDescriptor<StockPrice>(predicate: #Predicate { $0.ticker == ticker })
        return (try? context.fetch(desc))?.first
    }
}

// MARK: - Response Models
private struct YFResponse: Decodable {
    let chart: YFChart
}
private struct YFChart: Decodable {
    let result: [YFResult]?
}
private struct YFResult: Decodable {
    let meta: YFMeta
}
private struct YFMeta: Decodable {
    let regularMarketPrice: Double
    let previousClose: Double?
    let chartPreviousClose: Double?
}
