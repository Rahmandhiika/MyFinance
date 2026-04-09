import SwiftData
import Foundation

@Model
final class StockPrice {
    var ticker: String
    var currentPrice: Double
    var previousClose: Double
    var changePercent: Double
    var currency: AppCurrency
    var lastUpdated: Date

    init(ticker: String, currentPrice: Double, previousClose: Double = 0,
         changePercent: Double = 0, currency: AppCurrency = .IDR) {
        self.ticker = ticker
        self.currentPrice = currentPrice
        self.previousClose = previousClose
        self.changePercent = changePercent
        self.currency = currency
        self.lastUpdated = Date()
    }
}
