import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \KategoriExpense.nama) private var kategoriExpense: [KategoriExpense]
    @Query(sort: \KategoriIncome.nama) private var kategoriIncome: [KategoriIncome]

    @State private var selectedTab = 0
    @State private var showAddExpenseKategori = false
    @State private var showAddIncomeKategori = false

    // Add expense kategori
    @State private var newExpenseName = ""
    @State private var newExpensePrioritas: Prioritas = .blank
    @State private var newExpenseKelompok: KelompokExpense = .expense

    // Add income kategori
    @State private var newIncomeName = ""
    @State private var newIncomeKelompok: KelompokIncome = .gaji

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Tab", selection: $selectedTab) {
                    Text("Expense").tag(0)
                    Text("Income").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == 0 {
                    expenseList
                } else {
                    incomeList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Kelola Kategori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if selectedTab == 0 { showAddExpenseKategori = true }
                        else { showAddIncomeKategori = true }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .sheet(isPresented: $showAddExpenseKategori) {
                addExpenseSheet
            }
            .sheet(isPresented: $showAddIncomeKategori) {
                addIncomeSheet
            }
        }
    }

    // MARK: - Expense List

    private var expenseList: some View {
        List {
            if kategoriExpense.isEmpty {
                Text("Belum ada kategori expense")
                    .foregroundStyle(.secondary)
            }
            ForEach(kategoriExpense) { kat in
                HStack(spacing: 12) {
                    Circle()
                        .fill(kat.prioritas.color)
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(kat.nama)
                            .font(.subheadline.weight(.medium))
                        HStack(spacing: 6) {
                            Text(kat.prioritas.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(kat.prioritas.color.opacity(0.15))
                                .foregroundStyle(kat.prioritas.color)
                                .clipShape(Capsule())
                            Text(kat.kelompok.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { indexSet in
                for idx in indexSet {
                    context.delete(kategoriExpense[idx])
                }
                try? context.save()
            }
        }
    }

    // MARK: - Income List

    private var incomeList: some View {
        List {
            if kategoriIncome.isEmpty {
                Text("Belum ada kategori income")
                    .foregroundStyle(.secondary)
            }
            ForEach(kategoriIncome) { kat in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(kat.nama)
                            .font(.subheadline.weight(.medium))
                        Text(kat.kelompokIncome.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { indexSet in
                for idx in indexSet {
                    context.delete(kategoriIncome[idx])
                }
                try? context.save()
            }
        }
    }

    // MARK: - Add Expense Sheet

    private var addExpenseSheet: some View {
        NavigationStack {
            Form {
                Section("Nama Kategori") {
                    TextField("Nama", text: $newExpenseName)
                }

                Section("Prioritas") {
                    Picker("Prioritas", selection: $newExpensePrioritas) {
                        ForEach(Prioritas.allCases, id: \.self) { p in
                            HStack {
                                Circle().fill(p.color).frame(width: 10, height: 10)
                                Text(p.displayName)
                            }
                            .tag(p)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Kelompok") {
                    Picker("Kelompok", selection: $newExpenseKelompok) {
                        ForEach(KelompokExpense.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Tambah Kategori Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { showAddExpenseKategori = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") {
                        guard !newExpenseName.isEmpty else { return }
                        let kat = KategoriExpense(nama: newExpenseName, prioritas: newExpensePrioritas, kelompok: newExpenseKelompok)
                        context.insert(kat)
                        try? context.save()
                        newExpenseName = ""
                        newExpensePrioritas = .blank
                        newExpenseKelompok = .expense
                        showAddExpenseKategori = false
                    }
                    .disabled(newExpenseName.isEmpty)
                }
            }
        }
    }

    // MARK: - Add Income Sheet

    private var addIncomeSheet: some View {
        NavigationStack {
            Form {
                Section("Nama Kategori") {
                    TextField("Nama", text: $newIncomeName)
                }

                Section("Kelompok Income") {
                    Picker("Kelompok", selection: $newIncomeKelompok) {
                        ForEach(KelompokIncome.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("Tambah Kategori Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { showAddIncomeKategori = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") {
                        guard !newIncomeName.isEmpty else { return }
                        let kat = KategoriIncome(nama: newIncomeName, kelompokIncome: newIncomeKelompok)
                        context.insert(kat)
                        try? context.save()
                        newIncomeName = ""
                        newIncomeKelompok = .gaji
                        showAddIncomeKategori = false
                    }
                    .disabled(newIncomeName.isEmpty)
                }
            }
        }
    }
}
