import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var accounts: [Account]
    @Query private var categories: [Category]

    @State private var filter: TransactionType? = nil
    @State private var showAdd = false

    private var filtered: [Transaction] {
        guard let f = filter else { return transactions }
        return transactions.filter { $0.type == f }
    }

    private var grouped: [(String, [Transaction])] {
        let cal = Calendar.current
        let df = DateFormatter()
        df.dateStyle = .medium
        df.doesRelativeDateFormatting = true

        var dict: [Date: [Transaction]] = [:]
        for tx in filtered {
            let day = cal.startOfDay(for: tx.date)
            dict[day, default: []].append(tx)
        }
        return dict.keys.sorted(by: >).map { (df.string(from: $0), dict[$0]!) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        FilterChip(title: "Semua", isSelected: filter == nil) { filter = nil }
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            FilterChip(title: type.displayName, isSelected: filter == type) {
                                filter = filter == type ? nil : type
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                if filtered.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Belum ada transaksi")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(grouped, id: \.0) { date, txs in
                            Section(date) {
                                ForEach(txs) { tx in
                                    TransactionRowView(transaction: tx, accounts: accounts, categories: categories)
                                }
                                .onDelete { idx in
                                    for i in idx { TransactionProcessor.delete(txs[i], context: context) }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Transaksi")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddEditTransactionView(existingTransaction: nil)
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
