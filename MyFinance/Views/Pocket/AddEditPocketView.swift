import SwiftUI
import SwiftData

struct AddEditPocketView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var existingPocket: Pocket?

    @State private var nama = ""
    @State private var kelompok: KelompokPocket = .biasa
    @State private var kategori: NamaKategoriPocket = .rekeningBank
    @State private var saldoAwal: Double = 0
    @State private var limit: Double = 0
    @State private var catatan = ""

    private var isEditing: Bool { existingPocket != nil }
    private var isKreditType: Bool { kategori == .kartuKreditPayLater }

    var body: some View {
        NavigationStack {
            Form {
                Section("Info Pocket") {
                    TextField("Nama Pocket", text: $nama)

                    Picker("Kelompok", selection: $kelompok) {
                        ForEach(KelompokPocket.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }

                    Picker("Kategori", selection: $kategori) {
                        ForEach(NamaKategoriPocket.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                }

                if isKreditType {
                    Section("Kartu Kredit / PayLater") {
                        CurrencyInputField(label: "Limit", amount: $limit)
                    }
                }

                Section("Saldo") {
                    CurrencyInputField(label: "Saldo Awal", amount: $saldoAwal)
                }

                Section {
                    TextField("Catatan (opsional)", text: $catatan, axis: .vertical)
                        .lineLimit(3)
                }
            }
            .navigationTitle(isEditing ? "Edit Pocket" : "Tambah Pocket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                        .disabled(nama.isEmpty)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        guard let p = existingPocket else { return }
        nama = p.nama
        kelompok = p.kelompokPocket
        kategori = p.kategoriPocket
        saldoAwal = p.saldo
        limit = p.limit ?? 0
        catatan = p.catatan ?? ""
    }

    private func save() {
        if let p = existingPocket {
            p.nama = nama
            p.kelompokPocket = kelompok
            p.kategoriPocket = kategori
            p.saldo = saldoAwal
            p.limit = isKreditType ? limit : nil
            p.catatan = catatan.isEmpty ? nil : catatan
        } else {
            let pocket = Pocket(
                nama: nama, kelompokPocket: kelompok, kategoriPocket: kategori,
                saldo: saldoAwal, catatan: catatan.isEmpty ? nil : catatan,
                limit: isKreditType ? limit : nil
            )
            context.insert(pocket)
        }
        try? context.save()
        dismiss()
    }
}
