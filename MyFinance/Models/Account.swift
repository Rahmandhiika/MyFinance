import SwiftData
import Foundation

@Model
final class Account {
    var id: UUID
    var name: String
    var type: AccountType
    var currency: AppCurrency
    var balance: Double
    var limit: Double
    var usedLimit: Double
    var dueDate: Int
    var icon: String
    var colorHex: String
    var isArchived: Bool
    var createdAt: Date

    init(name: String, type: AccountType, currency: AppCurrency = .IDR,
         balance: Double = 0, limit: Double = 0, dueDate: Int = 0,
         icon: String = "creditcard", colorHex: String = "#4ECDC4") {
        self.id = UUID()
        self.name = name
        self.type = type
        self.currency = currency
        self.balance = balance
        self.limit = limit
        self.usedLimit = 0
        self.dueDate = dueDate
        self.icon = icon
        self.colorHex = colorHex
        self.isArchived = false
        self.createdAt = Date()
    }

    var availableLimit: Double { limit - usedLimit }

    var isDueSoon: Bool {
        guard type == .credit, dueDate > 0 else { return false }
        let day = Calendar.current.component(.day, from: Date())
        let diff = dueDate >= day ? dueDate - day : (dueDate + 30) - day
        return diff <= 3
    }

    static let availableColors = [
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
        "#DDA0DD", "#F7DC6F", "#BB8FCE", "#F8A488", "#82C0CC"
    ]

    static let availableIcons = [
        "banknotes", "creditcard", "creditcard.fill", "wallet.pass",
        "building.columns", "chart.line.uptrend.xyaxis", "dollarsign.circle",
        "bitcoinsign.circle", "briefcase", "bag.fill"
    ]
}
