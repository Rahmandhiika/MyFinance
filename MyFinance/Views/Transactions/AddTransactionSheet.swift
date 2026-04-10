import SwiftUI
import SwiftData

struct AddTransactionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Pocket> { $0.isAktif }) private var activePockets: [Pocket]
    @Query(sort: \KategoriExpense.nama) private var expenseCategories: [KategoriExpense]
    @Query(sort: \KategoriIncome.nama) private var incomeCategories: [KategoriIncome]
    @Query(sort: \Debitur.nama) private var debiturs: [Debitur]
    @Query(sort: \Kreditur.nama) private var krediturs: [Kreditur]

    // Type
    @State private var selectedType: TipeTransaksi
    let initialType: TipeTransaksi

    // Common fields
    @State private var tanggal: Date = Date()
    @State private var nominal: Double = 0
    @State private var catatan: String = ""

    // Expense / Income fields
    @State private var selectedExpenseCategoryID: UUID?
    @State private var selectedIncomeCategoryID: UUID?
    @State private var selectedPocketID: UUID?
    @State private var selectedDebiturID: UUID?
    @State private var selectedKrediturID: UUID?

    // Transfer fields
    @State private var pocketAsalID: UUID?
    @State private var pocketTujuanID: UUID?

    @State private var isSaving = false

    init(initialType: TipeTransaksi = .expense) {
        self.initialType = initialType
        _selectedType = State(initialValue: initialType)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    typeSelector
                    formContent
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Transaksi Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") {
                        saveTransaction()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid || isSaving)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSaving)
    }

    // MARK: - Type Selector

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
                    .padding(.horizontal, 14)
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

    // MARK: - Form Content

    @ViewBuilder
    private var formContent: some View {
        VStack(spacing: 16) {
            switch selectedType {
            case .expense:
                expenseForm
            case .income:
                incomeForm
            case .transfer:
                transferForm
            }
        }
    }

    // MARK: - Expense Form

    private var expenseForm: some View {
        formCard {
            dateField

            CurrencyInputField(label: "Nominal", amount: $nominal)

            pickerField(
                label: "Kategori",
                icon: "tag.fill",
                selection: $selectedExpenseCategoryID,
                options: expenseCategories.map { ($0.id, $0.nama) },
                placeholder: "Pilih Kategori"
            )

            pickerField(
                label: "Pocket",
                icon: "wallet.pass.fill",
                selection: $selectedPocketID,
                options: activePockets.map { ($0.id, $0.nama) },
                placeholder: "Pilih Pocket"
            )

            textField(label: "Catatan", icon: "note.text", text: $catatan, placeholder: "Catatan (opsional)")

            pickerField(
                label: "Debitur",
                icon: "person.fill",
                selection: $selectedDebiturID,
                options: debiturs.map { ($0.id, $0.nama) },
                placeholder: "Tidak ada",
                isOptional: true
            )

            pickerField(
                label: "Kreditur",
                icon: "person.2.fill",
                selection: $selectedKrediturID,
                options: krediturs.map { ($0.id, $0.nama) },
                placeholder: "Tidak ada",
                isOptional: true
            )
        }
    }

    // MARK: - Income Form

    private var incomeForm: some View {
        formCard {
            dateField

            CurrencyInputField(label: "Nominal", amount: $nominal)

            pickerField(
                label: "Kategori",
                icon: "tag.fill",
                selection: $selectedIncomeCategoryID,
                options: incomeCategories.map { ($0.id, $0.nama) },
                placeholder: "Pilih Kategori"
            )

            pickerField(
                label: "Pocket",
                icon: "wallet.pass.fill",
                selection: $selectedPocketID,
                options: activePockets.map { ($0.id, $0.nama) },
                placeholder: "Pilih Pocket"
            )

            textField(label: "Catatan", icon: "note.text", text: $catatan, placeholder: "Catatan (opsional)")

            pickerField(
                label: "Debitur",
                icon: "person.fill",
                selection: $selectedDebiturID,
                options: debiturs.map { ($0.id, $0.nama) },
                placeholder: "Tidak ada",
                isOptional: true
            )

            pickerField(
                label: "Kreditur",
                icon: "person.2.fill",
                selection: $selectedKrediturID,
                options: krediturs.map { ($0.id, $0.nama) },
                placeholder: "Tidak ada",
                isOptional: true
            )
        }
    }

    // MARK: - Transfer Form

    private var transferForm: some View {
        formCard {
            dateField

            CurrencyInputField(label: "Nominal", amount: $nominal)

            pickerField(
                label: "Pocket Asal",
                icon: "arrow.up.right.square.fill",
                selection: $pocketAsalID,
                options: activePockets.map { ($0.id, $0.nama) },
                placeholder: "Pilih Pocket Asal"
            )

            pickerField(
                label: "Pocket Tujuan",
                icon: "arrow.down.left.square.fill",
                selection: $pocketTujuanID,
                options: activePockets.map { ($0.id, $0.nama) },
                placeholder: "Pilih Pocket Tujuan"
            )

            textField(label: "Catatan", icon: "note.text", text: $catatan, placeholder: "Catatan (opsional)")
        }
    }

    // MARK: - Reusable Form Components

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Tanggal", systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
            DatePicker("", selection: $tanggal, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
        }
    }

    private func pickerField(
        label: String,
        icon: String,
        selection: Binding<UUID?>,
        options: [(UUID, String)],
        placeholder: String,
        isOptional: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Menu {
                if isOptional {
                    Button {
                        selection.wrappedValue = nil
                    } label: {
                        HStack {
                            Text(placeholder)
                            if selection.wrappedValue == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Divider()
                }
                ForEach(options, id: \.0) { id, name in
                    Button {
                        selection.wrappedValue = id
                    } label: {
                        HStack {
                            Text(name)
                            if selection.wrappedValue == id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedName(for: selection.wrappedValue, in: options, placeholder: placeholder))
                        .foregroundStyle(selection.wrappedValue != nil ? .primary : .tertiary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func textField(label: String, icon: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            content()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func selectedName(for id: UUID?, in options: [(UUID, String)], placeholder: String) -> String {
        guard let id else { return placeholder }
        return options.first(where: { $0.0 == id })?.1 ?? placeholder
    }

    private var isFormValid: Bool {
        guard nominal > 0 else { return false }
        switch selectedType {
        case .expense:
            return selectedExpenseCategoryID != nil && selectedPocketID != nil
        case .income:
            return selectedIncomeCategoryID != nil && selectedPocketID != nil
        case .transfer:
            return pocketAsalID != nil && pocketTujuanID != nil && pocketAsalID != pocketTujuanID
        }
    }

    // MARK: - Save

    private func saveTransaction() {
        guard isFormValid else { return }
        isSaving = true

        switch selectedType {
        case .expense:
            let expense = Expense(
                tanggal: tanggal,
                nominal: nominal,
                kategoriID: selectedExpenseCategoryID,
                pocketID: selectedPocketID,
                catatan: catatan.isEmpty ? nil : catatan,
                debiturID: selectedDebiturID,
                krediturID: selectedKrediturID
            )
            modelContext.insert(expense)
            TransactionProcessor.applyExpense(expense, context: modelContext)

        case .income:
            let income = Income(
                tanggal: tanggal,
                nominal: nominal,
                kategoriID: selectedIncomeCategoryID,
                pocketID: selectedPocketID,
                catatan: catatan.isEmpty ? nil : catatan,
                debiturID: selectedDebiturID,
                krediturID: selectedKrediturID
            )
            modelContext.insert(income)
            TransactionProcessor.applyIncome(income, context: modelContext)

        case .transfer:
            guard let asalID = pocketAsalID, let tujuanID = pocketTujuanID else { return }
            let transfer = TransferInternal(
                tanggal: tanggal,
                nominal: nominal,
                pocketAsalID: asalID,
                pocketTujuanID: tujuanID,
                catatan: catatan.isEmpty ? nil : catatan
            )
            modelContext.insert(transfer)
            TransactionProcessor.applyTransfer(transfer, context: modelContext)
        }

        dismiss()
    }
}
