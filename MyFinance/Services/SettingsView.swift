import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var accounts: [Account]
    @Query private var transactions: [Transaction]
    @Query private var categories: [Category]
    @Query private var holdings: [InvestmentHolding]
    @Query private var lots: [StockLot]
    @Query private var prices: [StockPrice]
    @Query private var recurringRules: [RecurringRule]
    @Query private var rates: [ExchangeRate]
    
    @State private var showDeleteConfirmation = false
    @State private var showCategorySheet = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Akun")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(accounts.count)")
                                .font(.title2.bold())
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Total Transaksi")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(transactions.count)")
                                .font(.title2.bold())
                        }
                    }
                    .padding(.vertical, 8)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Investasi")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(holdings.count)")
                                .font(.title2.bold())
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Kategori")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(categories.count)")
                                .font(.title2.bold())
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Statistik Data")
                }
                
                Section {
                    Button {
                        showCategorySheet = true
                    } label: {
                        HStack {
                            Image(systemName: "tag.fill")
                            Text("Kelola Kategori")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Kategori")
                }
                
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Reset Semua Data")
                        }
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Menghapus semua data termasuk akun, transaksi, dan investasi. Tindakan ini tidak dapat dibatalkan.")
                        .font(.caption)
                }
                
                Section {
                    HStack {
                        Text("Versi")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Aplikasi")
                }
            }
            .navigationTitle("Pengaturan")
            .sheet(isPresented: $showCategorySheet) {
                CategoryManagementView()
            }
            .confirmationDialog(
                "Reset Semua Data?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset Semua Data", role: .destructive) {
                    resetAllData()
                }
                Button("Batal", role: .cancel) {}
            } message: {
                Text("Semua data akun, transaksi, dan investasi akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.")
            }
        }
    }
    
    private func resetAllData() {
        accounts.forEach { context.delete($0) }
        transactions.forEach { context.delete($0) }
        holdings.forEach { context.delete($0) }
        lots.forEach { context.delete($0) }
        prices.forEach { context.delete($0) }
        recurringRules.forEach { context.delete($0) }
        rates.forEach { context.delete($0) }
        categories.filter { !$0.isDefault }.forEach { context.delete($0) }
        
        try? context.save()
    }
}
