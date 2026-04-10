import SwiftUI
import SwiftData

struct PocketDetailView: View {
    @Environment(\.modelContext) private var context
    let pocket: Pocket

    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]
    @Query private var transfers: [TransferInternal]
    @Query private var kategoriExpense: [KategoriExpense]
    @Query private var kategoriIncome: [KategoriIncome]

    @State private var showEdit = false
    @State private var showUpdateSaldo = false
    @State private var newSaldoText = ""
    @State private var waktuUpdate: WaktuUpdate = .malam

    private var pocketExpenses: [Expense] {
        expenses.filter { $0.pocketID == pocket.id }.sorted { $0.tanggal > $1.tanggal }
    }

    private var pocketIncomes: [Income] {
        incomes.filter { $0.pocketID == pocket.id }.sorted { $0.tanggal > $1.tanggal }
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pocket.nama)
                                .font(.title2.bold())
                            HStack(spacing: 8) {
                                Text(pocket.kelompokPocket.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                                Text(pocket.kategoriPocket.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Saldo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(pocket.saldo.idrFormatted)
                                .font(.title.bold())
                                .foregroundStyle(pocket.saldo >= 0 ? Color.primary : Color.red)
                        }
                        Spacer()
                        if let limit = pocket.limit {
                            VStack(alignment: .trailing) {
                                Text("Limit")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(limit.idrFormatted)
                                    .font(.headline)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Button {
                    newSaldoText = String(format: "%.0f", pocket.saldo)
                    showUpdateSaldo = true
                } label: {
                    Label("Update Saldo Manual", systemImage: "pencil.circle")
                }
                Button { showEdit = true } label: {
                    Label("Edit Pocket", systemImage: "gear")
                }
            }

            if !pocketExpenses.isEmpty {
                Section("Pengeluaran Terakhir") {
                    ForEach(pocketExpenses.prefix(10)) { exp in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(catName(expID: exp.kategoriID))
                                    .font(.subheadline)
                                if let note = exp.catatan, !note.isEmpty {
                                    Text(note).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("-\(exp.nominal.idrFormatted)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.red)
                                Text(exp.tanggal.formatted(.dateTime.day().month()))
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            if !pocketIncomes.isEmpty {
                Section("Pemasukan Terakhir") {
                    ForEach(pocketIncomes.prefix(10)) { inc in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(catName(incID: inc.kategoriID))
                                    .font(.subheadline)
                                if let note = inc.catatan, !note.isEmpty {
                                    Text(note).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("+\(inc.nominal.idrFormatted)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.green)
                                Text(inc.tanggal.formatted(.dateTime.day().month()))
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(pocket.nama)
        .sheet(isPresented: $showEdit) {
            AddEditPocketView(existingPocket: pocket)
        }
        .alert("Update Saldo", isPresented: $showUpdateSaldo) {
            TextField("Saldo baru", text: $newSaldoText)
                .keyboardType(.numberPad)
            Button("Simpan") { updateSaldo() }
            Button("Batal", role: .cancel) {}
        }
    }

    private func updateSaldo() {
        guard let val = Double(newSaldoText) else { return }
        let record = UpdateSaldo(pocketID: pocket.id, tanggal: Date(), saldo: val, waktuUpdate: waktuUpdate)
        context.insert(record)
        pocket.saldo = val
        try? context.save()
    }

    private func catName(expID: UUID?) -> String {
        guard let id = expID else { return "Tanpa Kategori" }
        return kategoriExpense.first { $0.id == id }?.nama ?? "Tanpa Kategori"
    }

    private func catName(incID: UUID?) -> String {
        guard let id = incID else { return "Tanpa Kategori" }
        return kategoriIncome.first { $0.id == id }?.nama ?? "Tanpa Kategori"
    }
}
