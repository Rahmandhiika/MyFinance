import SwiftData
import Foundation

@Model
final class ExchangeRate {
    var fromCurrency: String
    var toCurrency: String
    var rate: Double
    var lastUpdated: Date

    init(fromCurrency: String, toCurrency: String, rate: Double) {
        self.fromCurrency = fromCurrency
        self.toCurrency = toCurrency
        self.rate = rate
        self.lastUpdated = Date()
    }
}
