import SwiftUI
import SwiftData

// MARK: - Analytics Section (embedded in HomeView scroll)

struct AnalyticsSectionView: View {
    @Query(sort: \Expense.tanggal, order: .reverse) private var expenses: [Expense]
    @Query(sort: \Income.tanggal, order: .reverse) private var incomes: [Income]
    @Query private var expenseCategories: [KategoriExpense]
    @Query private var incomeCategories: [KategoriIncome]
    @Query(filter: #Predicate<Pocket> { $0.isAktif }) private var pockets: [Pocket]
    @Query private var danaDaruratConfigs: [DanaDaruratConfig]
    @Query private var budgets: [BudgetBulanan]

    @State private var selectedTab: AnalyticsTab = .expense

    enum AnalyticsTab: String, CaseIterable {
        case expense = "Expense"
        case income = "Income"
        case bulanan = "Bulanan"
        case tahunan = "Tahunan"
        case pocket = "Pocket"
        case danaDarurat = "Dana Darurat"
    }

    private var currentMonth: Int { Calendar.current.component(.month, from: Date()) }
    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }

    private var startOfMonth: Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
    }

    private var startOfYear: Date {
        let cal = Calendar.current
        return cal.date(from: DateComponents(year: currentYear, month: 1, day: 1)) ?? Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analitik")
                .font(.headline)
                .padding(.horizontal)

            // Tab scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AnalyticsTab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = tab
                            }
                        } label: {
                            Text(tab.rawValue)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(selectedTab == tab ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(selectedTab == tab ? analyticsColor : Color(.tertiarySystemGroupedBackground))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            // Tab content
            Group {
                switch selectedTab {
                case .expense: expenseAnalytics
                case .income: incomeAnalytics
                case .bulanan: bulananAnalytics
                case .tahunan: tahunanAnalytics
                case .pocket: pocketAnalytics
                case .danaDarurat: danaDaruratAnalytics
                }
            }
            .padding(.horizontal)
        }
    }

    private var analyticsColor: Color {
        switch selectedTab {
        case .expense: .red
        case .income: .green
        case .bulanan: .blue
        case .tahunan: .purple
        case .pocket: .orange
        case .danaDarurat: .teal
        }
    }

    // MARK: - Expense Analytics

    private var expenseAnalytics: some View {
        let monthlyExpenses = expenses.filter { $0.tanggal >= startOfMonth }
        let total = monthlyExpenses.reduce(0) { $0 + $1.nominal }
        let grouped = Dictionary(grouping: monthlyExpenses) { $0.kategoriID }

        let items: [(String, Double, Prioritas)] = grouped.compactMap { katID, exps in
            guard let katID else { return nil }
            let kat = expenseCategories.first(where: { $0.id == katID })
            let sum = exps.reduce(0) { $0 + $1.nominal }
            return (kat?.nama ?? "Tanpa Kategori", sum, kat?.prioritas ?? .blank)
        }.sorted { $0.1 > $1.1 }

        return analyticsCard {
            VStack(alignment: .leading, spacing: 12) {
                analyticsHeader("Pengeluaran Bulan Ini", value: total, color: .red)

                if items.isEmpty {
                    emptyAnalytics("Belum ada pengeluaran bulan ini")
                } else {
                    ForEach(items.prefix(6), id: \.0) { name, amount, prioritas in
                        analyticsBarRow(
                            label: name,
                            amount: amount,
                            total: total,
                            color: prioritas == .blank ? .red : prioritas.color
                        )
                    }
                }
            }
        }
    }

    // MARK: - Income Analytics

    private var incomeAnalytics: some View {
        let monthlyIncomes = incomes.filter { $0.tanggal >= startOfMonth }
        let total = monthlyIncomes.reduce(0) { $0 + $1.nominal }
        let grouped = Dictionary(grouping: monthlyIncomes) { $0.kategoriID }

        let items: [(String, Double)] = grouped.compactMap { katID, incs in
            guard let katID else { return nil }
            let kat = incomeCategories.first(where: { $0.id == katID })
            let sum = incs.reduce(0) { $0 + $1.nominal }
            return (kat?.nama ?? "Tanpa Kategori", sum)
        }.sorted { $0.1 > $1.1 }

        return analyticsCard {
            VStack(alignment: .leading, spacing: 12) {
                analyticsHeader("Pemasukan Bulan Ini", value: total, color: .green)

                if items.isEmpty {
                    emptyAnalytics("Belum ada pemasukan bulan ini")
                } else {
                    ForEach(items.prefix(6), id: \.0) { name, amount in
                        analyticsBarRow(label: name, amount: amount, total: total, color: .green)
                    }
                }
            }
        }
    }

    // MARK: - Bulanan Analytics (last 6 months)

    private var bulananAnalytics: some View {
        let months = last6Months()
        let maxValue = months.map { max($0.expense, $0.income) }.max() ?? 1

        return analyticsCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("6 Bulan Terakhir")
                    .font(.subheadline.weight(.semibold))

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(months, id: \.label) { m in
                        VStack(spacing: 4) {
                            // Stacked bars
                            VStack(spacing: 2) {
                                // Income bar
                                let incomeH = maxValue > 0 ? CGFloat(m.income / maxValue) * 80 : 0
                                Capsule()
                                    .fill(Color.green.opacity(0.8))
                                    .frame(height: max(incomeH, 2))

                                // Expense bar
                                let expenseH = maxValue > 0 ? CGFloat(m.expense / maxValue) * 80 : 0
                                Capsule()
                                    .fill(Color.red.opacity(0.8))
                                    .frame(height: max(expenseH, 2))
                            }
                            .frame(height: 90, alignment: .bottom)

                            Text(m.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // Legend
                HStack(spacing: 16) {
                    legendDot(color: .green, label: "Pemasukan")
                    legendDot(color: .red, label: "Pengeluaran")
                }
            }
        }
    }

    private struct MonthData {
        let label: String
        let income: Double
        let expense: Double
    }

    private func last6Months() -> [MonthData] {
        let cal = Calendar.current
        let now = Date()
        let monthNames = ["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"]

        return (0..<6).reversed().map { offset in
            guard let date = cal.date(byAdding: .month, value: -offset, to: now) else {
                return MonthData(label: "", income: 0, expense: 0)
            }
            let m = cal.component(.month, from: date)
            let y = cal.component(.year, from: date)
            let start = cal.date(from: DateComponents(year: y, month: m, day: 1)) ?? date
            let end = cal.date(byAdding: .month, value: 1, to: start) ?? date

            let inc = incomes.filter { $0.tanggal >= start && $0.tanggal < end }.reduce(0) { $0 + $1.nominal }
            let exp = expenses.filter { $0.tanggal >= start && $0.tanggal < end }.reduce(0) { $0 + $1.nominal }
            return MonthData(label: monthNames[m - 1], income: inc, expense: exp)
        }
    }

    // MARK: - Tahunan Analytics (monthly this year)

    private var tahunanAnalytics: some View {
        let months = monthlyThisYear()
        let maxValue = months.map { max($0.expense, $0.income) }.max() ?? 1

        return analyticsCard {
            VStack(alignment: .leading, spacing: 12) {
                analyticsHeader("Total \(currentYear)",
                                value: months.reduce(0) { $0 + $1.expense },
                                color: .purple)

                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(months, id: \.label) { m in
                        VStack(spacing: 3) {
                            let expH = maxValue > 0 ? CGFloat(m.expense / maxValue) * 70 : 0
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.purple.opacity(0.7))
                                .frame(height: max(expH, 2))

                            Text(m.label)
                                .font(.system(size: 7))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 80, alignment: .bottom)

                HStack {
                    Text("Total Pengeluaran \(currentYear)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(months.reduce(0) { $0 + $1.income }.idrFormatted)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private func monthlyThisYear() -> [MonthData] {
        let cal = Calendar.current
        let monthNames = ["J","F","M","A","M","J","J","A","S","O","N","D"]

        return (1...12).map { m in
            let start = cal.date(from: DateComponents(year: currentYear, month: m, day: 1)) ?? Date()
            let end = cal.date(byAdding: .month, value: 1, to: start) ?? Date()
            let inc = incomes.filter { $0.tanggal >= start && $0.tanggal < end }.reduce(0) { $0 + $1.nominal }
            let exp = expenses.filter { $0.tanggal >= start && $0.tanggal < end }.reduce(0) { $0 + $1.nominal }
            return MonthData(label: monthNames[m - 1], income: inc, expense: exp)
        }
    }

    // MARK: - Pocket Analytics

    private var pocketAnalytics: some View {
        let byKelompok = Dictionary(grouping: pockets) { $0.kelompokPocket }
        let totalAll = pockets.reduce(0) { $0 + max($1.saldo, 0) }

        return analyticsCard {
            VStack(alignment: .leading, spacing: 12) {
                analyticsHeader("Total Saldo", value: totalAll, color: .orange)

                ForEach(KelompokPocket.allCases, id: \.self) { kelompok in
                    let filtered = byKelompok[kelompok] ?? []
                    if !filtered.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: kelompok.icon)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(kelompok.displayName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(filtered.reduce(0) { $0 + $1.saldo }.idrFormatted)
                                    .font(.caption.weight(.bold))
                            }

                            ForEach(filtered) { pocket in
                                HStack {
                                    pocketLogoView(pocket)
                                        .frame(width: 24, height: 24)

                                    Text(pocket.nama)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(pocket.saldo.idrFormatted)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(pocket.saldo >= 0 ? .primary : .red)
                                }
                            }
                        }
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Dana Darurat Analytics

    private var danaDaruratAnalytics: some View {
        let config = danaDaruratConfigs.first ?? DanaDaruratConfig()
        let monthlyExpense = averageMonthlyExpense(prioritasIncluded: config.prioritasIncluded)
        let target = monthlyExpense * Double(config.jumlahBulan)
        let saldoSaatIni = pockets
            .filter { $0.kelompokPocket == .biasa }
            .reduce(0) { $0 + max($1.saldo, 0) }
        let ratio = target > 0 ? min(saldoSaatIni / target, 1.0) : 0

        return analyticsCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Dana Darurat")
                    .font(.subheadline.weight(.semibold))

                // Target vs actual
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Saldo Saat Ini")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(saldoSaatIni.idrFormatted)
                            .font(.title3.bold())
                            .foregroundStyle(ratio >= 1 ? .green : (ratio >= 0.5 ? .orange : .red))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Target (\(config.jumlahBulan) bulan)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(target.idrFormatted)
                            .font(.subheadline.weight(.semibold))
                    }
                }

                // Progress
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.systemFill))
                                .frame(height: 12)
                            Capsule()
                                .fill(ratio >= 1.0 ? Color.green : (ratio >= 0.5 ? Color.orange : Color.red))
                                .frame(width: geo.size.width * ratio, height: 12)
                        }
                    }
                    .frame(height: 12)

                    HStack {
                        Text(String(format: "%.1f bulan", target > 0 ? saldoSaatIni / monthlyExpense : 0))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ratio >= 1 ? .green : .secondary)
                        Spacer()
                        Text(String(format: "%.0f%%", ratio * 100))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ratio >= 1 ? .green : (ratio >= 0.5 ? .orange : .red))
                    }
                }

                Divider()

                // Monthly expense used for calculation
                HStack {
                    Text("Rata-rata pengeluaran/bulan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(monthlyExpense.idrFormatted)
                        .font(.caption.weight(.semibold))
                }

                Text("Prioritas: \(config.prioritasIncluded.joined(separator: ", ").uppercased())")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func averageMonthlyExpense(prioritasIncluded: [String]) -> Double {
        let prioritasSet = Set(prioritasIncluded)
        let filteredCategories = expenseCategories.filter { kat in
            prioritasSet.contains(kat.prioritas.rawValue) || kat.prioritas == .blank
        }
        let filteredCatIDs = Set(filteredCategories.map { $0.id })
        let filtered = expenses.filter { exp in
            guard let katID = exp.kategoriID else { return false }
            return filteredCatIDs.contains(katID)
        }

        // Average over last 3 months
        let cal = Calendar.current
        let now = Date()
        var totals: [Double] = []
        for offset in 0..<3 {
            guard let date = cal.date(byAdding: .month, value: -offset, to: now) else { continue }
            let m = cal.component(.month, from: date)
            let y = cal.component(.year, from: date)
            let start = cal.date(from: DateComponents(year: y, month: m, day: 1)) ?? date
            let end = cal.date(byAdding: .month, value: 1, to: start) ?? date
            let total = filtered.filter { $0.tanggal >= start && $0.tanggal < end }.reduce(0) { $0 + $1.nominal }
            totals.append(total)
        }
        let avg = totals.isEmpty ? 0 : totals.reduce(0, +) / Double(totals.count)
        return avg
    }

    // MARK: - Shared Components

    private func analyticsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func analyticsHeader(_ title: String, value: Double, color: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value.idrFormatted)
                    .font(.title3.bold())
                    .foregroundStyle(color)
            }
            Spacer()
        }
    }

    private func analyticsBarRow(label: String, amount: Double, total: Double, color: Color) -> some View {
        let ratio = total > 0 ? amount / total : 0

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
                Text(amount.shortFormatted)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Text(String(format: "%.0f%%", ratio * 100))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemFill)).frame(height: 5)
                    Capsule()
                        .fill(color.opacity(0.8))
                        .frame(width: geo.size.width * ratio, height: 5)
                }
            }
            .frame(height: 5)
        }
    }

    private func emptyAnalytics(_ message: String) -> some View {
        HStack {
            Spacer()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 16)
            Spacer()
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func pocketLogoView(_ pocket: Pocket) -> some View {
        Group {
            if let logoData = pocket.logo, let uiImage = UIImage(data: logoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue.opacity(0.15))
                    .overlay(
                        Text(String(pocket.nama.prefix(1)).uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.blue)
                    )
            }
        }
    }
}
