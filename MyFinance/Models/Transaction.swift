import SwiftData
import Foundation

@Model
final class Transaction {
    var id: UUID
    var type: TransactionType
    var amount: Double
    var date: Date
    var note: String
    var categoryID: UUID?
    var sourceAccountID: UUID
    var destinationAccountID: UUID?
    var recurringRuleID: UUID?
    var createdAt: Date

    init(type: TransactionType, amount: Double, date: Date = Date(),
         note: String = "", categoryID: UUID? = nil, sourceAccountID: UUID,
         destinationAccountID: UUID? = nil, recurringRuleID: UUID? = nil) {
        self.id = UUID()
        self.type = type
        self.amount = amount
        self.date = date
        self.note = note
        self.categoryID = categoryID
        self.sourceAccountID = sourceAccountID
        self.destinationAccountID = destinationAccountID
        self.recurringRuleID = recurringRuleID
        self.createdAt = Date()
    }
}
