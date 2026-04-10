import SwiftUI
import SwiftData

struct VoiceReviewSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Pocket> { $0.isAktif }) private var pockets: [Pocket]
    @Query private var kategoriExpense: [KategoriExpense]
    @Query private var kategoriIncome: [KategoriIncome]

    let transcribedText: String
    let onDone: () -> Void

    @State private var tipe: TipeTransaksi = .expense
    @State private var nominal: Double = 0
    @State private var selectedPocketID: UUID?
    @State private var selectedKategoriExpenseID: UUID?
    @State private var selectedKategoriIncomeID: UUID?
    @State private var selectedPocketTujuanID: UUID?
    @State private var catatan: String = ""
    @State private var tanggal = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Hasil Parse") {
                    Text(transcribedText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Tipe Transaksi") {
                    Picker("Tipe", selection: $tipe) {
                        ForEach(TipeTransaksi.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Detail") {
                    CurrencyInputField(label: "Nominal", amount: $nominal)
                    DatePicker("Tanggal", selection: $tanggal, displayedComponents: .date)

                    if tipe == .expense {
                        Picker("Kategori", selection: $selectedKategoriExpenseID) {
                            Text("Pilih Kategori").tag(Optional<UUID>.none)
                            ForEach(kategoriExpense) { k in
                                Text(k.nama).tag(Optional(k.id))
                            }
                        }
                    } else if tipe == .income {
                        Picker("Kategori", selection: $selectedKategoriIncomeID) {
                            Text("Pilih Kategori").tag(Optional<UUID>.none)
                            ForEach(kategoriIncome) { k in
                                Text(k.nama).tag(Optional(k.id))
                            }
                        }
                    }

                    if tipe == .transfer {
                        Picker("Pocket Asal", selection: $selectedPocketID) {
                            Text("Pilih").tag(Optional<UUID>.none)
                            ForEach(pockets) { p in Text(p.nama).tag(Optional(p.id)) }
                        }
                        Picker("Pocket Tujuan", selection: $selectedPocketTujuanID) {
                            Text("Pilih").tag(Optional<UUID>.none)
                            ForEach(pockets) { p in Text(p.nama).tag(Optional(p.id)) }
                        }
                    } else {
                        Picker("Pocket", selection: $selectedPocketID) {
                            Text("Pilih Pocket").tag(Optional<UUID>.none)
                            ForEach(pockets) { p in Text(p.nama).tag(Optional(p.id)) }
                        }
                    }

                    TextField("Catatan", text: $catatan)
                }
            }
            .navigationTitle("Review Transaksi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                        .disabled(nominal <= 0)
                }
            }
            .onAppear { parseText() }
        }
    }

    private func parseText() {
        let parser = NLPParser.shared
        let parsed = parser.parse(text: transcribedText, pocketNames: pockets.map { $0.nama })

        nominal = parsed.amount
        catatan = parsed.note

        switch parsed.type {
        case .expense: tipe = .expense
        case .income: tipe = .income
        case .transfer: tipe = .transfer
        }

        if let matchedPocket = parsed.matchedPocketName {
            selectedPocketID = pockets.first { $0.nama.lowercased() == matchedPocket.lowercased() }?.id
        }
    }

    private func save() {
        switch tipe {
        case .expense:
            let exp = Expense(tanggal: tanggal, nominal: nominal,
                             kategoriID: selectedKategoriExpenseID,
                             pocketID: selectedPocketID,
                             catatan: catatan.isEmpty ? nil : catatan)
            context.insert(exp)
            TransactionProcessor.applyExpense(exp, context: context)

        case .income:
            let inc = Income(tanggal: tanggal, nominal: nominal,
                            kategoriID: selectedKategoriIncomeID,
                            pocketID: selectedPocketID,
                            catatan: catatan.isEmpty ? nil : catatan)
            context.insert(inc)
            TransactionProcessor.applyIncome(inc, context: context)

        case .transfer:
            guard let asalID = selectedPocketID, let tujuanID = selectedPocketTujuanID else { return }
            let transfer = TransferInternal(tanggal: tanggal, nominal: nominal,
                                           pocketAsalID: asalID, pocketTujuanID: tujuanID,
                                           catatan: catatan.isEmpty ? nil : catatan)
            context.insert(transfer)
            TransactionProcessor.applyTransfer(transfer, context: context)
        }

        try? context.save()
        onDone()
        dismiss()
    }
}
