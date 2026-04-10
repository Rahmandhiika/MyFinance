import SwiftUI
import SwiftData

struct KategoriManagementView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \KategoriExpense.createdAt) private var expenseCategories: [KategoriExpense]
    @Query(sort: \KategoriIncome.createdAt) private var incomeCategories: [KategoriIncome]

    @State private var selectedTab: CategoryTab = .expense
    @State private var showAddExpense = false
    @State private var showAddIncome = false
    @State private var editingExpense: KategoriExpense?
    @State private var editingIncome: KategoriIncome?

    enum CategoryTab: String, CaseIterable {
        case expense = "Pengeluaran"
        case income = "Pemasukan"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(CategoryTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 12)

                List {
                    switch selectedTab {
                    case .expense: expenseSection
                    case .income: incomeSection
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Kategori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        switch selectedTab {
                        case .expense: showAddExpense = true
                        case .income: showAddIncome = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddExpense) {
                AddEditExpenseCategoryView()
            }
            .sheet(isPresented: $showAddIncome) {
                AddEditIncomeCategoryView()
            }
            .sheet(item: $editingExpense) { k in
                AddEditExpenseCategoryView(existing: k)
            }
            .sheet(item: $editingIncome) { k in
                AddEditIncomeCategoryView(existing: k)
            }
        }
    }

    private var expenseSection: some View {
        Group {
            if expenseCategories.isEmpty {
                emptyState("Belum ada kategori pengeluaran")
            } else {
                ForEach(expenseCategories) { k in
                    expenseCategoryRow(k)
                        .onTapGesture { editingExpense = k }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                context.delete(k)
                                try? context.save()
                            } label: {
                                Label("Hapus", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private func expenseCategoryRow(_ k: KategoriExpense) -> some View {
        HStack {
            Circle()
                .fill(k.prioritas.color.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(k.prioritas.displayName)
                        .font(.caption2.bold())
                        .foregroundStyle(k.prioritas.color)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(k.nama)
                    .font(.subheadline.weight(.semibold))
                Text(k.kelompok.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var incomeSection: some View {
        Group {
            if incomeCategories.isEmpty {
                emptyState("Belum ada kategori pemasukan")
            } else {
                ForEach(incomeCategories) { k in
                    incomeCategoryRow(k)
                        .onTapGesture { editingIncome = k }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                context.delete(k)
                                try? context.save()
                            } label: {
                                Label("Hapus", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private func incomeCategoryRow(_ k: KategoriIncome) -> some View {
        HStack {
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(k.nama)
                    .font(.subheadline.weight(.semibold))
                Text(k.kelompokIncome.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

// MARK: - Add/Edit Expense Category

struct AddEditExpenseCategoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var existing: KategoriExpense?

    @State private var nama = ""
    @State private var prioritas: Prioritas = .blank
    @State private var kelompok: KelompokExpense = .expense

    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nama") {
                    TextField("Nama Kategori", text: $nama)
                }

                Section("Kelompok") {
                    Picker("Kelompok", selection: $kelompok) {
                        ForEach(KelompokExpense.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Prioritas") {
                    Picker("Prioritas", selection: $prioritas) {
                        ForEach(Prioritas.allCases, id: \.self) { p in
                            HStack {
                                Circle()
                                    .fill(p.color)
                                    .frame(width: 10, height: 10)
                                Text(p.displayName)
                            }
                            .tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle(isEditing ? "Edit Kategori" : "Tambah Kategori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                        .disabled(nama.isEmpty)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        guard let k = existing else { return }
        nama = k.nama
        prioritas = k.prioritas
        kelompok = k.kelompok
    }

    private func save() {
        if let k = existing {
            k.nama = nama
            k.prioritas = prioritas
            k.kelompok = kelompok
        } else {
            context.insert(KategoriExpense(nama: nama, prioritas: prioritas, kelompok: kelompok))
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Add/Edit Income Category

struct AddEditIncomeCategoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var existing: KategoriIncome?

    @State private var nama = ""
    @State private var kelompokIncome: KelompokIncome = .gaji

    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Nama") {
                    TextField("Nama Kategori", text: $nama)
                }

                Section("Kelompok") {
                    Picker("Kelompok", selection: $kelompokIncome) {
                        ForEach(KelompokIncome.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Kategori" : "Tambah Kategori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                        .disabled(nama.isEmpty)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        guard let k = existing else { return }
        nama = k.nama
        kelompokIncome = k.kelompokIncome
    }

    private func save() {
        if let k = existing {
            k.nama = nama
            k.kelompokIncome = kelompokIncome
        } else {
            context.insert(KategoriIncome(nama: nama, kelompokIncome: kelompokIncome))
        }
        try? context.save()
        dismiss()
    }
}
