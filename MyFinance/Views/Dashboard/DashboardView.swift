import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Account> { !$0.isArchived }, sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var categories: [Category]
    @Query private var holdings: [InvestmentHolding]
    @Query private var lots: [StockLot]
    @Query private var prices: [StockPrice]
    @Query private var rates: [ExchangeRate]

    @State private var showAddTransaction = false
    @State private var showAddAccount = false

    private var usdToIDR: Double {
        rates.first(where: { $0.fromCurrency == "USD" && $0.toCurrency == "IDR" })?.rate ?? 16000
    }

    private var recentTransactions: [Transaction] {
        Array(transactions.prefix(10))
    }

    private var dueSoonAccounts: [Account] {
        accounts.filter { $0.isDueSoon }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    NetWorthCardView(
                        accounts: accounts, holdings: holdings,
                        lots: lots, prices: prices, usdToIDR: usdToIDR
                    )
                    .padding(.horizontal)

                    // Due Soon Banner
                    if !dueSoonAccounts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Tagihan Jatuh Tempo", systemImage: "exclamationmark.circle.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.orange)

                            ForEach(dueSoonAccounts) { acc in
                                HStack {
                                    Text(acc.name)
                                    Spacer()
                                    Text(acc.usedLimit.idrFormatted)
                                        .bold()
                                    Text("due tgl \(acc.dueDate)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Accounts horizontal scroll
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Akun & Wallet")
                                .font(.headline)
                            Spacer()
                            Button("+ Tambah") { showAddAccount = true }
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(accounts) { account in
                                    NavigationLink(destination: AccountDetailView(account: account)) {
                                        AccountCardView(account: account)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Recent transactions
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Transaksi Terbaru")
                                .font(.headline)
                            Spacer()
                            NavigationLink("Lihat Semua") {
                                TransactionListView()
                            }
                            .font(.caption)
                        }
                        .padding(.horizontal)

                        if recentTransactions.isEmpty {
                            Text("Belum ada transaksi")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(recentTransactions) { tx in
                                    TransactionRowView(transaction: tx, accounts: accounts, categories: categories)
                                    Divider().padding(.leading, 56)
                                }
                            }
                            .padding(.horizontal)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 80) // space for FAB
                }
                .padding(.top)
            }
            .navigationTitle("MyFinance")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddTransaction = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddEditTransactionView(existingTransaction: nil)
            }
            .sheet(isPresented: $showAddAccount) {
                AddEditAccountView(existingAccount: nil)
            }
        }
    }
}
