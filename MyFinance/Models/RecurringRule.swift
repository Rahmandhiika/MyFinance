import SwiftData
import Foundation

@Model
final class RecurringRule {
    var id: UUID
    var interval: RecurringInterval
    var nextDueDate: Date
    var isActive: Bool
    var notifyBefore: Bool
    var templateAmount: Double
    var templateType: TransactionType
    var templateNote: String
    var templateCategoryID: UUID?
    var templateSourceAccountID: UUID
    var templateDestinationAccountID: UUID?

    init(interval: RecurringInterval, nextDueDate: Date, templateAmount: Double,
         templateType: TransactionType, templateNote: String = "",
         templateCategoryID: UUID? = nil, templateSourceAccountID: UUID,
         templateDestinationAccountID: UUID? = nil) {
        self.id = UUID()
        self.interval = interval
        self.nextDueDate = nextDueDate
        self.isActive = true
        self.notifyBefore = true
        self.templateAmount = templateAmount
        self.templateType = templateType
        self.templateNote = templateNote
        self.templateCategoryID = templateCategoryID
        self.templateSourceAccountID = templateSourceAccountID
        self.templateDestinationAccountID = templateDestinationAccountID
    }
}
