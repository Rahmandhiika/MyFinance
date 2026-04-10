import SwiftUI
import SwiftData

// MARK: - Recent Transaction Item

struct RecentTransactionItem: Identifiable {
    let id: UUID
    let tanggal: Date
    let nominal: Double
    let isExpense: Bool
    let categoryName: String
    let catatan: String?
}

// MARK: - HomeView

struct HomeView: View {
    @Environment(\.modelContext) private var context

    @Query private var userProfiles: [UserProfile]
    @Query(filter: #Predicate<Pocket> { $0.isAktif }) private var pockets: [Pocket]
    @Query(sort: \Expense.tanggal, order: .reverse) private var expenses: [Expense]
    @Query(sort: \Income.tanggal, order: .reverse) private var incomes: [Income]
    @Query private var kategoriExpenses: [KategoriExpense]
    @Query private var kategoriIncomes: [KategoriIncome]
    @Query private var asetNonFinansials: [AsetNonFinansial]

    @State private var showSettings = false

    // MARK: - User Profile

    private var userProfile: UserProfile? {
        userProfiles.first
    }

    private var greetingName: String {
        userProfile?.nama ?? "User"
    }

    private var greetingText: String {
        userProfile?.greetingText ?? "Welcome back"
    }

    // MARK: - Net Worth

    private var totalPocketBiasaInvestasi: Double {
        pockets
            .filter { $0.kelompokPocket == .biasa || $0.kelompokPocket == .investasi }
            .reduce(0) { $0 + $1.saldo }
    }

    private var totalUtang: Double {
        pockets
            .filter { $0.kelompokPocket == .utang }
            .reduce(0) { $0 + abs($1.saldo) }
    }

    private var totalAsetNonFinansial: Double {
        asetNonFinansials.reduce(0) { $0 + $1.nilaiPasarTerakhir }
    }

    private var totalNetWorth: Double {
        totalPocketBiasaInvestasi + totalAsetNonFinansial - totalUtang
    }

    // MARK: - Monthly Summary

    private var startOfMonth: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }

    private var monthlyIncome: Double {
        incomes
            .filter { $0.tanggal >= startOfMonth }
            .reduce(0) { $0 + $1.nominal }
    }

    private var monthlyExpense: Double {
        expenses
            .filter { $0.tanggal >= startOfMonth }
            .reduce(0) { $0 + $1.nominal }
    }

    private var monthlySaving: Double {
        monthlyIncome - monthlyExpense
    }

    // MARK: - Recent Transactions

    private var recentTransactions: [RecentTransactionItem] {
        let expenseItems = expenses.prefix(10).map { exp in
            RecentTransactionItem(
                id: exp.id,
                tanggal: exp.tanggal,
                nominal: exp.nominal,
                isExpense: true,
                categoryName: kategoriExpenses.first(where: { $0.id == exp.kategoriID })?.nama ?? "Tanpa Kategori",
                catatan: exp.catatan
            )
        }

        let incomeItems = incomes.prefix(10).map { inc in
            RecentTransactionItem(
                id: inc.id,
                tanggal: inc.tanggal,
                nominal: inc.nominal,
                isExpense: false,
                categoryName: kategoriIncomes.first(where: { $0.id == inc.kategoriID })?.nama ?? "Tanpa Kategori",
                catatan: inc.catatan
            )
        }

        return (expenseItems + incomeItems)
            .sorted { $0.tanggal > $1.tanggal }
            .prefix(10)
            .map { $0 }
    }

    // MARK: - Date Formatter

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "id_ID")
        return f
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    greetingSection
                    netWorthCard
                    monthlySummarySection
                    recentTransactionsSection
                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(greetingName)
                    .font(.title.bold())
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Net Worth Card

    private var netWorthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Net Worth")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            Text(totalNetWorth.idrFormatted)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Divider()
                .background(.white.opacity(0.3))

            HStack(spacing: 0) {
                netWorthDetailItem(
                    title: "Finansial",
                    value: totalPocketBiasaInvestasi.shortFormatted,
                    icon: "banknote.fill"
                )
                Spacer()
                netWorthDetailItem(
                    title: "Non-Finansial",
                    value: totalAsetNonFinansial.shortFormatted,
                    icon: "building.2.fill"
                )
                Spacer()
                netWorthDetailItem(
                    title: "Utang",
                    value: totalUtang.shortFormatted,
                    icon: "creditcard.fill"
                )
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "1A1A2E"), Color(hex: "16213E"), Color(hex: "0F3460")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color(hex: "0F3460").opacity(0.4), radius: 12, x: 0, y: 6)
        .padding(.horizontal)
    }

    private func netWorthDetailItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Monthly Summary

    private var monthlySummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ringkasan Bulan Ini")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 12) {
                summaryCard(
                    title: "Pemasukan",
                    value: monthlyIncome.shortFormatted,
                    fullValue: monthlyIncome.idrFormatted,
                    color: Color(hex: "22C55E"),
                    icon: "arrow.down.circle.fill"
                )
                summaryCard(
                    title: "Pengeluaran",
                    value: monthlyExpense.shortFormatted,
                    fullValue: monthlyExpense.idrFormatted,
                    color: Color(hex: "EF4444"),
                    icon: "arrow.up.circle.fill"
                )
                summaryCard(
                    title: "Saving",
                    value: monthlySaving.shortFormatted,
                    fullValue: monthlySaving.idrFormatted,
                    color: monthlySaving >= 0 ? Color(hex: "3B82F6") : Color(hex: "F97316"),
                    icon: "banknote.fill"
                )
            }
            .padding(.horizontal)
        }
    }

    private func summaryCard(title: String, value: String, fullValue: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recent Transactions

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Transaksi Terbaru")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)

            if recentTransactions.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Belum ada transaksi")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(recentTransactions) { item in
                        recentTransactionRow(item)
                        if item.id != recentTransactions.last?.id {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }

    private func recentTransactionRow(_ item: RecentTransactionItem) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(item.isExpense ? Color(hex: "EF4444").opacity(0.15) : Color(hex: "22C55E").opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: item.isExpense ? "arrow.up.right" : "arrow.down.left")
                        .font(.caption.bold())
                        .foregroundStyle(item.isExpense ? Color(hex: "EF4444") : Color(hex: "22C55E"))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.categoryName)
                    .font(.subheadline.weight(.medium))
                Text(item.catatan ?? dateFormatter.string(from: item.tanggal))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(item.isExpense ? "-" : "+")\(item.nominal.idrFormatted)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.isExpense ? Color(hex: "EF4444") : Color(hex: "22C55E"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

}
