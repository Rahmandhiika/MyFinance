import SwiftData
import Foundation

@Model
final class Category {
    var id: UUID
    var name: String
    var transactionType: CategoryTransactionType
    var icon: String
    var colorHex: String
    var isDefault: Bool

    init(name: String, transactionType: CategoryTransactionType,
         icon: String, colorHex: String, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.transactionType = transactionType
        self.icon = icon
        self.colorHex = colorHex
        self.isDefault = isDefault
    }
}
