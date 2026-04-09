import SwiftData
import Foundation

class ModelContainerService {
    static let shared = ModelContainerService()

    let container: ModelContainer

    private init() {
        let schema = Schema([
            Account.self, Transaction.self, Category.self, RecurringRule.self,
            InvestmentHolding.self, StockLot.self, StockPrice.self,
            ExchangeRate.self, Goal.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
    }

    func seedDefaultCategoriesIfNeeded() {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.isDefault == true })
        guard (try? context.fetch(descriptor))?.isEmpty ?? true else { return }

        let defaults: [(String, CategoryTransactionType, String, String)] = [
            ("Food & Drink",       .expense, "fork.knife",                    "#FF6B35"),
            ("Transport",          .expense, "car.fill",                      "#4ECDC4"),
            ("Bills & Utilities",  .expense, "bolt.fill",                     "#45B7D1"),
            ("Shopping",           .expense, "bag.fill",                      "#F7DC6F"),
            ("Entertainment",      .expense, "gamecontroller.fill",            "#BB8FCE"),
            ("Health",             .expense, "heart.fill",                    "#E74C3C"),
            ("Education",          .expense, "book.fill",                     "#3498DB"),
            ("Investment Buy",     .expense, "chart.line.uptrend.xyaxis",     "#2ECC71"),
            ("Other",              .expense, "ellipsis.circle.fill",          "#95A5A6"),
            ("Salary",             .income,  "banknotes.fill",                "#27AE60"),
            ("Dividend",           .income,  "chart.bar.fill",                "#1ABC9C"),
            ("Freelance",          .income,  "laptopcomputer",                "#2980B9"),
            ("Other Income",       .income,  "plus.circle.fill",              "#16A085"),
        ]

        for (name, type, icon, color) in defaults {
            context.insert(Category(name: name, transactionType: type, icon: icon, colorHex: color, isDefault: true))
        }
        try? context.save()
    }
}
