import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction
    let accounts: [Account]
    let categories: [Category]

    private var category: Category? {
        guard let id = transaction.categoryID else { return nil }
        return categories.first { $0.id == id }
    }

    private var sourceAccount: Account? {
        accounts.first { $0.id == transaction.sourceAccountID }
    }

    private var amountColor: Color {
        switch transaction.type {
        case .income:    return .green
        case .expense:   return .red
        case .transfer:  return .blue
        case .payCredit: return .orange
        }
    }

    private var amountPrefix: String {
        switch transaction.type {
        case .income:    return "+"
        case .expense:   return "-"
        case .transfer:  return "→"
        case .payCredit: return "↩"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: category?.colorHex ?? "#95A5A6").opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: category?.icon ?? transaction.type.icon)
                    .foregroundStyle(Color(hex: category?.colorHex ?? "#95A5A6"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(category?.name ?? transaction.type.displayName)
                    .font(.subheadline.bold())
                Text(transaction.note.isEmpty ? (sourceAccount?.name ?? "-") : transaction.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(amountPrefix)\(transaction.amount.idrFormatted)")
                    .font(.subheadline.bold())
                    .foregroundStyle(amountColor)
                Text(transaction.date.formatted(.dateTime.day().month()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
