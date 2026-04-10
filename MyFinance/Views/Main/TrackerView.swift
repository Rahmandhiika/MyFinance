import SwiftUI
import SwiftData

struct TrackerView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Expense.tanggal, order: .reverse) private var expenses: [Expense]
    @Query(sort: \Income.tanggal, order: .reverse) private var incomes: [Income]
    @Query(sort: \TransferInternal.tanggal, order: .reverse) private var transfers: [TransferInternal]
    @Query private var pockets: [Pocket]
    @Query private var expenseCategories: [KategoriExpense]
    @Query private var incomeCategories: [KategoriIncome]

    @State private var selectedType: TipeTransaksi = .expense
    @State private var showAddSheet = false
    @State private var showTerjadwal = false
    @State private var showBudget = false
    @State private var showKategori = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    typeSelector
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                    transactionList
                }
                .background(Color(.systemGroupedBackground))

                fabButton
            }
            .navigationTitle("Tracker")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showTerjadwal = true
                        } label: {
                            Label("Terjadwal", systemImage: "calendar.badge.clock")
                        }
                        Button {
                            showBudget = true
                        } label: {
                            Label("Budget Bulanan", systemImage: "chart.bar.doc.horizontal")
                        }
                        Button {
                            showKategori = true
                        } label: {
                            Label("Kelola Kategori", systemImage: "tag.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddTransactionSheet(initialType: selectedType)
            }
            .sheet(isPresented: $showTerjadwal) {
                TerjadwalManagementView()
            }
            .sheet(isPresented: $showBudget) {
                BudgetBulananView()
            }
            .sheet(isPresented: $showKategori) {
                KategoriManagementView()
            }
        }
    }

    // MARK: - Type Selector Pills

    private var typeSelector: some View {
        HStack(spacing: 8) {
            ForEach(TipeTransaksi.allCases, id: \.self) { type in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedType = type
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: type.icon)
                            .font(.caption)
                        Text(type.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        selectedType == type
                            ? type.color.opacity(0.15)
                            : Color(.tertiarySystemBackground)
                    )
                    .foregroundStyle(selectedType == type ? type.color : .secondary)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                selectedType == type ? type.color.opacity(0.4) : Color.clear,
                                lineWidth: 1.5
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Transaction List

    private var transactionList: some View {
        Group {
            switch selectedType {
            case .expense:
                expenseList
            case .income:
                incomeList
            case .transfer:
                transferList
            }
        }
    }

    // MARK: - Expense List

    private var expenseList: some View {
        let grouped = Dictionary(grouping: expenses) { sectionDate($0.tanggal) }
        let sortedKeys = grouped.keys.sorted(by: >)

        return listContainer {
            if expenses.isEmpty {
                emptyState(type: .expense)
            } else {
                ForEach(sortedKeys, id: \.self) { date in
                    Section {
                        ForEach(grouped[date] ?? [], id: \.id) { expense in
                            expenseRow(expense)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        TransactionProcessor.deleteExpense(expense, context: modelContext)
                                    } label: {
                                        Label("Hapus", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        sectionHeader(date: date)
                    }
                }
            }
        }
    }

    // MARK: - Income List

    private var incomeList: some View {
        let grouped = Dictionary(grouping: incomes) { sectionDate($0.tanggal) }
        let sortedKeys = grouped.keys.sorted(by: >)

        return listContainer {
            if incomes.isEmpty {
                emptyState(type: .income)
            } else {
                ForEach(sortedKeys, id: \.self) { date in
                    Section {
                        ForEach(grouped[date] ?? [], id: \.id) { income in
                            incomeRow(income)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        TransactionProcessor.deleteIncome(income, context: modelContext)
                                    } label: {
                                        Label("Hapus", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        sectionHeader(date: date)
                    }
                }
            }
        }
    }

    // MARK: - Transfer List

    private var transferList: some View {
        let grouped = Dictionary(grouping: transfers) { sectionDate($0.tanggal) }
        let sortedKeys = grouped.keys.sorted(by: >)

        return listContainer {
            if transfers.isEmpty {
                emptyState(type: .transfer)
            } else {
                ForEach(sortedKeys, id: \.self) { date in
                    Section {
                        ForEach(grouped[date] ?? [], id: \.id) { transfer in
                            transferRow(transfer)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        TransactionProcessor.deleteTransfer(transfer, context: modelContext)
                                    } label: {
                                        Label("Hapus", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        sectionHeader(date: date)
                    }
                }
            }
        }
    }

    // MARK: - Row Views

    private func expenseRow(_ expense: Expense) -> some View {
        let categoryName = expenseCategories.first(where: { $0.id == expense.kategoriID })?.nama ?? "Tanpa Kategori"
        let pocketName = pockets.first(where: { $0.id == expense.pocketID })?.nama ?? "-"

        return TransactionRow(
            icon: "arrow.up.circle.fill",
            iconColor: .red,
            title: categoryName,
            subtitle: pocketName + (expense.catatan.map { $0.isEmpty ? "" : " • \($0)" } ?? ""),
            amount: expense.nominal,
            amountColor: .red,
            date: expense.tanggal
        )
    }

    private func incomeRow(_ income: Income) -> some View {
        let categoryName = incomeCategories.first(where: { $0.id == income.kategoriID })?.nama ?? "Tanpa Kategori"
        let pocketName = pockets.first(where: { $0.id == income.pocketID })?.nama ?? "-"

        return TransactionRow(
            icon: "arrow.down.circle.fill",
            iconColor: .green,
            title: categoryName,
            subtitle: pocketName + (income.catatan.map { $0.isEmpty ? "" : " • \($0)" } ?? ""),
            amount: income.nominal,
            amountColor: .green,
            date: income.tanggal
        )
    }

    private func transferRow(_ transfer: TransferInternal) -> some View {
        let asalName = pockets.first(where: { $0.id == transfer.pocketAsalID })?.nama ?? "?"
        let tujuanName = pockets.first(where: { $0.id == transfer.pocketTujuanID })?.nama ?? "?"

        return TransactionRow(
            icon: "arrow.left.arrow.right.circle.fill",
            iconColor: .blue,
            title: "Transfer",
            subtitle: "\(asalName) → \(tujuanName)" + (transfer.catatan.map { $0.isEmpty ? "" : " • \($0)" } ?? ""),
            amount: transfer.nominal,
            amountColor: .blue,
            date: transfer.tanggal
        )
    }

    // MARK: - Helpers

    private func listContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        List {
            content()
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func sectionHeader(date: Date) -> some View {
        HStack {
            Text(formatSectionDate(date))
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(nil)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func emptyState(type: TipeTransaksi) -> some View {
        VStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 40))
                .foregroundStyle(type.color.opacity(0.4))
            Text("Belum ada \(type.displayName.lowercased())")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Ketuk + untuk menambahkan")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func sectionDate(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Hari Ini"
        } else if calendar.isDateInYesterday(date) {
            return "Kemarin"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "id_ID")
            formatter.dateFormat = "EEEE, d MMMM yyyy"
            return formatter.string(from: date)
        }
    }

    // MARK: - FAB

    private var fabButton: some View {
        Button {
            showAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(selectedType.color.gradient)
                        .shadow(color: selectedType.color.opacity(0.4), radius: 8, y: 4)
                )
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
}

// MARK: - Transaction Row Component

private struct TransactionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let amount: Double
    let amountColor: Color
    let date: Date

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Amount & time
            VStack(alignment: .trailing, spacing: 3) {
                Text(amount.idrFormatted)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(amountColor)
                Text(formatTime(date))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
