import SwiftUI
import SwiftData

struct AddEditTransactionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var accounts: [Account]
    @Query private var categories: [Category]
    @Query private var recurringRules: [RecurringRule]

    var existingTransaction: Transaction?
    var preselectedAccountID: UUID? = nil
    var prefilled: ParsedTransaction? = nil

    @State private var type: TransactionType = .expense
    @State private var amount: Double = 0
    @State private var date = Date()
    @State private var note = ""
    @State private var selectedSourceAccountID: UUID? = nil
    @State private var selectedDestAccountID: UUID? = nil
    @State private var selectedCategoryID: UUID? = nil
    @State private var isRecurring = false
    @State private var recurringInterval: RecurringInterval = .monthly

    private var isEditing: Bool { existingTransaction != nil }

    private var filteredCategories: [Category] {
        let catType: CategoryTransactionType = type == .income ? .income : .expense
        return categories.filter { $0.transactionType == catType }
    }

    private var sourceAccounts: [Account] {
        switch type {
        case .expense: return accounts.filter { $0.type != .investment }
        case .income:  return accounts.filter { $0.type != .credit && $0.type != .investment }
        case .transfer: return accounts.filter { $0.type != .credit && $0.type != .investment }
        case .payCredit: return accounts.filter { $0.type != .credit && $0.type != .investment }
        }
    }

    private var destAccounts: [Account] {
        switch type {
        case .transfer: return accounts.filter { $0.type != .credit && $0.id != selectedSourceAccountID }
        case .payCredit: return accounts.filter { $0.type == .credit }
        default: return []
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Transaction type
                Section {
                    Picker("Tipe", selection: $type) {
                        ForEach(TransactionType.allCases, id: \.self) {
                            Label($0.displayName, systemImage: $0.icon).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Amount
                Section("Jumlah") {
                    CurrencyInputField(label: "Nominal", amount: $amount)
                }

                // Source account
                Section("Akun Sumber") {
                    if sourceAccounts.isEmpty {
                        Text("Tidak ada akun tersedia")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Dari", selection: $selectedSourceAccountID) {
                            Text("Pilih Akun").tag(Optional<UUID>.none)
                            ForEach(sourceAccounts) { acc in
                                Label(acc.name, systemImage: acc.icon).tag(Optional(acc.id))
                            }
                        }
                    }
                }

                // Destination account (transfer / payCredit)
                if type == .transfer || type == .payCredit {
                    Section(type == .payCredit ? "Akun Kredit yang Dibayar" : "Akun Tujuan") {
                        Picker("Ke", selection: $selectedDestAccountID) {
                            Text("Pilih Akun").tag(Optional<UUID>.none)
                            ForEach(destAccounts) { acc in
                                Label(acc.name, systemImage: acc.icon).tag(Optional(acc.id))
                            }
                        }
                    }
                }

                // Category
                if type == .expense || type == .income {
                    Section("Kategori") {
                        Picker("Kategori", selection: $selectedCategoryID) {
                            Text("Pilih Kategori").tag(Optional<UUID>.none)
                            ForEach(filteredCategories) { cat in
                                Label(cat.name, systemImage: cat.icon).tag(Optional(cat.id))
                            }
                        }
                    }
                }

                // Date & Note
                Section("Detail") {
                    DatePicker("Tanggal", selection: $date, displayedComponents: .date)
                    TextField("Catatan (opsional)", text: $note)
                }

                // Recurring
                if !isEditing {
                    Section {
                        Toggle("Transaksi Berulang", isOn: $isRecurring)
                        if isRecurring {
                            Picker("Interval", selection: $recurringInterval) {
                                ForEach(RecurringInterval.allCases, id: \.self) {
                                    Text($0.displayName).tag($0)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Transaksi" : "Tambah Transaksi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                        .disabled(amount == 0 || selectedSourceAccountID == nil)
                }
            }
            .onAppear { loadInitialValues() }
        }
    }

    private func loadInitialValues() {
        if let acc = preselectedAccountID { selectedSourceAccountID = acc }

        if let p = prefilled {
            type = p.type
            amount = p.amount
            note = p.note
            if let name = p.matchedAccountName {
                selectedSourceAccountID = accounts.first { $0.name == name }?.id
            }
            if let catName = p.matchedCategoryName {
                selectedCategoryID = categories.first { $0.name == catName }?.id
            }
            return
        }

        if let tx = existingTransaction {
            type = tx.type
            amount = tx.amount
            date = tx.date
            note = tx.note
            selectedSourceAccountID = tx.sourceAccountID
            selectedDestAccountID = tx.destinationAccountID
            selectedCategoryID = tx.categoryID
        } else {
            selectedSourceAccountID = selectedSourceAccountID ?? accounts.first?.id
        }
    }

    private func save() {
        guard let sourceID = selectedSourceAccountID else { return }

        if let existing = existingTransaction {
            // Revert old, apply new
            TransactionProcessor.revert(existing, context: context)
            existing.type = type
            existing.amount = amount
            existing.date = date
            existing.note = note
            existing.categoryID = selectedCategoryID
            existing.sourceAccountID = sourceID
            existing.destinationAccountID = selectedDestAccountID
            TransactionProcessor.apply(existing, context: context)
        } else {
            let tx = Transaction(
                type: type, amount: amount, date: date, note: note,
                categoryID: selectedCategoryID, sourceAccountID: sourceID,
                destinationAccountID: selectedDestAccountID
            )

            if isRecurring {
                let rule = RecurringRule(
                    interval: recurringInterval,
                    nextDueDate: Calendar.current.date(byAdding: recurringInterval.calendarComponent, value: 1, to: date) ?? date,
                    templateAmount: amount, templateType: type, templateNote: note,
                    templateCategoryID: selectedCategoryID, templateSourceAccountID: sourceID,
                    templateDestinationAccountID: selectedDestAccountID
                )
                context.insert(rule)
                tx.recurringRuleID = rule.id
            }

            context.insert(tx)
            TransactionProcessor.apply(tx, context: context)
        }

        try? context.save()
        dismiss()
    }
}

extension RecurringInterval {
    var calendarComponent: Calendar.Component {
        switch self {
        case .daily:   return .day
        case .weekly:  return .weekOfYear
        case .monthly: return .month
        case .yearly:  return .year
        }
    }
}
