import SwiftUI
import SwiftData

struct AddEditAccountView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var existingAccount: Account?

    @State private var name = ""
    @State private var type: AccountType = .debit
    @State private var currency: AppCurrency = .IDR
    @State private var balance: Double = 0
    @State private var limit: Double = 0
    @State private var dueDate: Int = 0
    @State private var selectedIcon = "creditcard"
    @State private var selectedColor = "#4ECDC4"

    private var isEditing: Bool { existingAccount != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Info Akun") {
                    TextField("Nama (contoh: BCA, GoPay)", text: $name)

                    Picker("Tipe", selection: $type) {
                        ForEach(AccountType.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }

                    Picker("Mata Uang", selection: $currency) {
                        ForEach(AppCurrency.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                }

                if type != .credit {
                    Section("Saldo Awal") {
                        CurrencyInputField(label: "Saldo", amount: $balance, currency: currency)
                    }
                }

                if type == .credit {
                    Section("Detail Kredit / Paylater") {
                        CurrencyInputField(label: "Limit", amount: $limit)
                        Stepper("Tanggal Jatuh Tempo: \(dueDate > 0 ? "tgl \(dueDate)" : "Tidak di-set")",
                                value: $dueDate, in: 0...31)
                    }
                }

                Section("Tampilan") {
                    // Icon picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Account.availableIcons, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.title2)
                                    .padding(8)
                                    .background(selectedIcon == icon ? Color(hex: selectedColor) : Color(.secondarySystemBackground))
                                    .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .onTapGesture { selectedIcon = icon }
                            }
                        }
                    }

                    // Color picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Account.availableColors, id: \.self) { color in
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if selectedColor == color {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.white)
                                                .font(.caption.bold())
                                        }
                                    }
                                    .onTapGesture { selectedColor = color }
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Akun" : "Tambah Akun")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        guard let acc = existingAccount else { return }
        name = acc.name
        type = acc.type
        currency = acc.currency
        balance = acc.balance
        limit = acc.limit
        dueDate = acc.dueDate
        selectedIcon = acc.icon
        selectedColor = acc.colorHex
    }

    private func save() {
        if let acc = existingAccount {
            acc.name = name
            acc.type = type
            acc.currency = currency
            acc.balance = balance
            acc.limit = limit
            acc.dueDate = dueDate
            acc.icon = selectedIcon
            acc.colorHex = selectedColor
        } else {
            let acc = Account(name: name, type: type, currency: currency,
                             balance: balance, limit: limit, dueDate: dueDate,
                             icon: selectedIcon, colorHex: selectedColor)
            context.insert(acc)
        }
        try? context.save()

        // Schedule due date reminder if credit
        if type == .credit, let acc = existingAccount {
            NotificationService.shared.scheduleDueDateReminders(for: acc)
        }

        dismiss()
    }
}
