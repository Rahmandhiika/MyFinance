import SwiftUI
import SwiftData

struct BudgetBulananView: View {
    @Environment(\.modelContext) private var context

    @Query private var budgets: [BudgetBulanan]
    @Query private var expenses: [Expense]
    @Query private var expenseCategories: [KategoriExpense]

    @State private var selectedBulan: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedTahun: Int = Calendar.current.component(.year, from: Date())
    @State private var showAddBudget = false
    @State private var editingBudget: BudgetBulanan?

    private var bulanNames = ["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"]

    private var budgetBulanIni: [BudgetBulanan] {
        budgets.filter { $0.bulan == selectedBulan && $0.tahun == selectedTahun }
    }

    private var expenseBulanIni: [Expense] {
        let cal = Calendar.current
        return expenses.filter {
            cal.component(.month, from: $0.tanggal) == selectedBulan &&
            cal.component(.year, from: $0.tanggal) == selectedTahun
        }
    }

    private var totalBudget: Double {
        budgetBulanIni.reduce(0) { $0 + $1.nominalBudget }
    }

    private var totalActual: Double {
        expenseBulanIni
            .filter { exp in
                expenseCategories.first(where: { $0.id == exp.kategoriID })?.kelompok == .expense
            }
            .reduce(0) { $0 + $1.nominal }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month selector
                monthSelector
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                List {
                    // Summary card
                    Section {
                        budgetSummaryCard
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }

                    // Per category
                    Section("Per Kategori") {
                        if budgetBulanIni.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "chart.bar.doc.horizontal")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.secondary)
                                Text("Belum ada budget untuk bulan ini")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            ForEach(budgetBulanIni.sorted { $0.nominalBudget > $1.nominalBudget }) { budget in
                                budgetCategoryRow(budget)
                                    .onTapGesture { editingBudget = budget }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            context.delete(budget)
                                            try? context.save()
                                        } label: {
                                            Label("Hapus", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }

                    // Categories without budget
                    let categoriesWithBudget = Set(budgetBulanIni.compactMap { $0.kategoriID })
                    let uncoveredExpenses = expenseBulanIni.filter {
                        exp in
                        guard let katID = exp.kategoriID else { return false }
                        let isExpenseKelompok = expenseCategories.first(where: { $0.id == katID })?.kelompok == .expense
                        return isExpenseKelompok && !categoriesWithBudget.contains(katID)
                    }

                    if !uncoveredExpenses.isEmpty {
                        Section("Pengeluaran Tanpa Budget") {
                            let groupedByKat = Dictionary(grouping: uncoveredExpenses) { $0.kategoriID }
                            ForEach(groupedByKat.keys.compactMap({ $0 }), id: \.self) { katID in
                                let total = groupedByKat[katID]?.reduce(0) { $0 + $1.nominal } ?? 0
                                let katName = expenseCategories.first(where: { $0.id == katID })?.nama ?? "Tanpa Kategori"
                                HStack {
                                    Text(katName)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(total.idrFormatted)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Budget Bulanan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showAddBudget = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddBudget) {
                AddEditBudgetView(bulan: selectedBulan, tahun: selectedTahun)
            }
            .sheet(item: $editingBudget) { budget in
                AddEditBudgetView(existing: budget)
            }
        }
    }

    // MARK: - Month Selector

    private var monthSelector: some View {
        HStack {
            Button {
                if selectedBulan == 1 {
                    selectedBulan = 12
                    selectedTahun -= 1
                } else {
                    selectedBulan -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.blue)
            }

            Spacer()

            Text("\(bulanNames[selectedBulan - 1]) \(selectedTahun)")
                .font(.headline)

            Spacer()

            Button {
                if selectedBulan == 12 {
                    selectedBulan = 1
                    selectedTahun += 1
                } else {
                    selectedBulan += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.blue)
            }
        }
    }

    // MARK: - Summary Card

    private var budgetSummaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Budget")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(totalBudget.idrFormatted)
                        .font(.title3.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Terpakai")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(totalActual.idrFormatted)
                        .font(.title3.bold())
                        .foregroundStyle(totalActual > totalBudget ? .red : .primary)
                }
            }

            // Progress bar
            let ratio = totalBudget > 0 ? min(totalActual / totalBudget, 1.0) : 0
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemFill))
                            .frame(height: 10)
                        Capsule()
                            .fill(ratio >= 1.0 ? Color.red : (ratio >= 0.8 ? Color.orange : Color.green))
                            .frame(width: geo.size.width * ratio, height: 10)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text(String(format: "%.0f%% terpakai", ratio * 100))
                        .font(.caption)
                        .foregroundStyle(ratio >= 1.0 ? .red : .secondary)
                    Spacer()
                    let sisa = totalBudget - totalActual
                    Text(sisa >= 0 ? "Sisa \(sisa.shortFormatted)" : "Lewat \(abs(sisa).shortFormatted)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(sisa >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Category Row

    private func budgetCategoryRow(_ budget: BudgetBulanan) -> some View {
        let katName = expenseCategories.first(where: { $0.id == budget.kategoriID })?.nama ?? "Tanpa Kategori"
        let actual = expenseBulanIni
            .filter { $0.kategoriID == budget.kategoriID }
            .reduce(0) { $0 + $1.nominal }
        let ratio = budget.nominalBudget > 0 ? min(actual / budget.nominalBudget, 1.0) : 0
        let barColor: Color = ratio >= 1.0 ? .red : (ratio >= 0.8 ? .orange : .green)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(katName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(actual.shortFormatted)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(actual > budget.nominalBudget ? .red : .primary)
                    Text("/ \(budget.nominalBudget.shortFormatted)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemFill)).frame(height: 6)
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * ratio, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add/Edit Budget View

struct AddEditBudgetView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var existing: BudgetBulanan?
    var bulan: Int = Calendar.current.component(.month, from: Date())
    var tahun: Int = Calendar.current.component(.year, from: Date())

    @Query private var expenseCategories: [KategoriExpense]

    @State private var selectedKategoriID: UUID?
    @State private var nominalBudget: Double = 0

    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Kategori") {
                    Picker("Kategori Expense", selection: $selectedKategoriID) {
                        Text("Pilih Kategori").tag(Optional<UUID>.none)
                        ForEach(expenseCategories.filter { $0.kelompok == .expense }) { k in
                            Text(k.nama).tag(Optional(k.id))
                        }
                    }
                }

                Section("Budget") {
                    CurrencyInputField(label: "Nominal Budget", amount: $nominalBudget)
                }
            }
            .navigationTitle(isEditing ? "Edit Budget" : "Tambah Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                        .disabled(selectedKategoriID == nil || nominalBudget <= 0)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        guard let e = existing else { return }
        selectedKategoriID = e.kategoriID
        nominalBudget = e.nominalBudget
    }

    private func save() {
        if let e = existing {
            e.kategoriID = selectedKategoriID ?? e.kategoriID
            e.nominalBudget = nominalBudget
        } else {
            guard let katID = selectedKategoriID else { return }
            let b = BudgetBulanan(
                kategoriID: katID,
                nominalBudget: nominalBudget,
                bulan: bulan,
                tahun: tahun
            )
            context.insert(b)
        }
        try? context.save()
        dismiss()
    }
}
