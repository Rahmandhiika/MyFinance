import SwiftUI
import SwiftData

struct AccountDetailView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var categories: [Category]
    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var allAccounts: [Account]

    let account: Account

    @State private var showEdit = false
    @State private var showAddTransaction = false
    @State private var showUpdateBalance = false
    @State private var newBalance: Double = 0

    private var accountTransactions: [Transaction] {
        allTransactions.filter {
            $0.sourceAccountID == account.id || $0.destinationAccountID == account.id
        }
    }

    var body: some View {
        List {
            // Header
            Section {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: account.colorHex))
                            .frame(width: 64, height: 64)
                        Image(systemName: account.icon)
                            .font(.title2)
                            .foregroundStyle(.white)
                    }

                    if account.type == .credit {
                        VStack(spacing: 4) {
                            Text(account.usedLimit.idrFormatted)
                                .font(.title.bold())
                            Text("dari limit \(account.limit.idrFormatted)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ProgressView(value: account.limit > 0 ? account.usedLimit / account.limit : 0)
                                .tint(account.usedLimit / max(account.limit, 1) > 0.8 ? .red : .orange)

                            HStack {
                                Text("Tersedia: \(account.availableLimit.idrFormatted)")
                                    .font(.caption)
                                Spacer()
                                if account.dueDate > 0 {
                                    Text("Jatuh tempo tgl \(account.dueDate)")
                                        .font(.caption)
                                        .foregroundStyle(account.isDueSoon ? .red : .secondary)
                                }
                            }
                        }
                    } else {
                        Text(account.balance.formatted(currency: account.currency))
                            .font(.title.bold())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            // Actions
            Section {
                if account.type != .credit {
                    Button("Update Saldo Manual") {
                        newBalance = account.balance
                        showUpdateBalance = true
                    }
                }
                Button("+ Transaksi Baru") { showAddTransaction = true }
            }

            // Transactions
            Section("Riwayat Transaksi") {
                if accountTransactions.isEmpty {
                    Text("Belum ada transaksi")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(accountTransactions) { tx in
                        TransactionRowView(transaction: tx, accounts: allAccounts, categories: categories)
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            TransactionProcessor.delete(accountTransactions[i], context: context)
                        }
                    }
                }
            }
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            AddEditAccountView(existingAccount: account)
        }
        .sheet(isPresented: $showAddTransaction) {
            AddEditTransactionView(existingTransaction: nil, preselectedAccountID: account.id)
        }
        .alert("Update Saldo", isPresented: $showUpdateBalance) {
            TextField("Saldo baru", value: $newBalance, format: .number)
                .keyboardType(.numberPad)
            Button("Simpan") {
                account.balance = newBalance
                try? context.save()
            }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Masukkan saldo aktual dari akun \(account.name)")
        }
    }
}
