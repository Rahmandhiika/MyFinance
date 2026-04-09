import SwiftData
import Foundation

struct TransactionProcessor {

    static func apply(_ transaction: Transaction, context: ModelContext) {
        let descriptor = FetchDescriptor<Account>()
        guard let accounts = try? context.fetch(descriptor) else { return }

        let source = accounts.first { $0.id == transaction.sourceAccountID }
        let dest   = accounts.first { $0.id == transaction.destinationAccountID }

        switch transaction.type {
        case .income:
            source?.balance += transaction.amount
        case .expense:
            if let acc = source {
                if acc.type == .credit { acc.usedLimit += transaction.amount }
                else { acc.balance -= transaction.amount }
            }
        case .transfer:
            source?.balance -= transaction.amount
            dest?.balance   += transaction.amount
        case .payCredit:
            source?.balance -= transaction.amount
            if let creditAcc = dest {
                creditAcc.usedLimit = max(0, creditAcc.usedLimit - transaction.amount)
            }
        }
    }

    static func revert(_ transaction: Transaction, context: ModelContext) {
        let descriptor = FetchDescriptor<Account>()
        guard let accounts = try? context.fetch(descriptor) else { return }

        let source = accounts.first { $0.id == transaction.sourceAccountID }
        let dest   = accounts.first { $0.id == transaction.destinationAccountID }

        switch transaction.type {
        case .income:
            source?.balance -= transaction.amount
        case .expense:
            if let acc = source {
                if acc.type == .credit { acc.usedLimit = max(0, acc.usedLimit - transaction.amount) }
                else { acc.balance += transaction.amount }
            }
        case .transfer:
            source?.balance += transaction.amount
            dest?.balance   -= transaction.amount
        case .payCredit:
            source?.balance += transaction.amount
            dest?.usedLimit = (dest?.usedLimit ?? 0) + transaction.amount
        }
    }

    static func delete(_ transaction: Transaction, context: ModelContext) {
        revert(transaction, context: context)
        context.delete(transaction)
        try? context.save()
    }
}
