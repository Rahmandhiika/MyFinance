import SwiftData
import Foundation

@Model
final class StockLot {
    var id: UUID
    var holdingID: UUID
    var shares: Double
    var buyPrice: Double
    var buyDate: Date
    var fee: Double

    init(holdingID: UUID, shares: Double, buyPrice: Double,
         buyDate: Date = Date(), fee: Double = 0) {
        self.id = UUID()
        self.holdingID = holdingID
        self.shares = shares
        self.buyPrice = buyPrice
        self.buyDate = buyDate
        self.fee = fee
    }

    var totalCost: Double { shares * buyPrice + fee }
}
