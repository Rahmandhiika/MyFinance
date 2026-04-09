import SwiftData
import Foundation

@Model
final class InvestmentHolding {
    var id: UUID
    var accountID: UUID
    var ticker: String
    var name: String
    var assetType: AssetType
    var subSector: String
    var exchange: String
    var createdAt: Date

    init(accountID: UUID, ticker: String, name: String, assetType: AssetType,
         subSector: String = "", exchange: String = "IDX") {
        self.id = UUID()
        self.accountID = accountID
        self.ticker = ticker.uppercased()
        self.name = name
        self.assetType = assetType
        self.subSector = subSector
        self.exchange = exchange
        self.createdAt = Date()
    }
}
