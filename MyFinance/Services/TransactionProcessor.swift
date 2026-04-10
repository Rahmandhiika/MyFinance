import SwiftData
import Foundation

struct TransactionProcessor {
    static func applyExpense(_ expense: Expense, context: ModelContext) {
        guard let pocketID = expense.pocketID else { return }
        let desc = FetchDescriptor<Pocket>(predicate: #Predicate { $0.id == pocketID })
        guard let pocket = (try? context.fetch(desc))?.first else { return }
        pocket.saldo -= expense.nominal
        try? context.save()
    }

    static func revertExpense(_ expense: Expense, context: ModelContext) {
        guard let pocketID = expense.pocketID else { return }
        let desc = FetchDescriptor<Pocket>(predicate: #Predicate { $0.id == pocketID })
        guard let pocket = (try? context.fetch(desc))?.first else { return }
        pocket.saldo += expense.nominal
        try? context.save()
    }

    static func applyIncome(_ income: Income, context: ModelContext) {
        guard let pocketID = income.pocketID else { return }
        let desc = FetchDescriptor<Pocket>(predicate: #Predicate { $0.id == pocketID })
        guard let pocket = (try? context.fetch(desc))?.first else { return }
        pocket.saldo += income.nominal
        try? context.save()
    }

    static func revertIncome(_ income: Income, context: ModelContext) {
        guard let pocketID = income.pocketID else { return }
        let desc = FetchDescriptor<Pocket>(predicate: #Predicate { $0.id == pocketID })
        guard let pocket = (try? context.fetch(desc))?.first else { return }
        pocket.saldo -= income.nominal
        try? context.save()
    }

    static func applyTransfer(_ transfer: TransferInternal, context: ModelContext) {
        let asalID = transfer.pocketAsalID
        let tujuanID = transfer.pocketTujuanID
        let descAsal = FetchDescriptor<Pocket>(predicate: #Predicate { $0.id == asalID })
        let descTujuan = FetchDescriptor<Pocket>(predicate: #Predicate { $0.id == tujuanID })
        if let asal = (try? context.fetch(descAsal))?.first {
            asal.saldo -= transfer.nominal
        }
        if let tujuan = (try? context.fetch(descTujuan))?.first {
            tujuan.saldo += transfer.nominal
        }
        try? context.save()
    }

    static func revertTransfer(_ transfer: TransferInternal, context: ModelContext) {
        let asalID = transfer.pocketAsalID
        let tujuanID = transfer.pocketTujuanID
        let descAsal = FetchDescriptor<Pocket>(predicate: #Predicate { $0.id == asalID })
        let descTujuan = FetchDescriptor<Pocket>(predicate: #Predicate { $0.id == tujuanID })
        if let asal = (try? context.fetch(descAsal))?.first {
            asal.saldo += transfer.nominal
        }
        if let tujuan = (try? context.fetch(descTujuan))?.first {
            tujuan.saldo -= transfer.nominal
        }
        try? context.save()
    }

    static func deleteExpense(_ expense: Expense, context: ModelContext) {
        revertExpense(expense, context: context)
        context.delete(expense)
        try? context.save()
    }

    static func deleteIncome(_ income: Income, context: ModelContext) {
        revertIncome(income, context: context)
        context.delete(income)
        try? context.save()
    }

    static func deleteTransfer(_ transfer: TransferInternal, context: ModelContext) {
        revertTransfer(transfer, context: context)
        context.delete(transfer)
        try? context.save()
    }
}
