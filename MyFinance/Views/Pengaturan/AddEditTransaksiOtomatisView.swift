import SwiftUI
import SwiftData

struct AddEditTransaksiOtomatisView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Kategori.urutan) private var allKategoris: [Kategori]
    @Query private var pockets: [Pocket]

    var item: TransaksiOtomatis? = nil

    @State private var nominal: Decimal = 0
    @State private var tipe: TipeTransaksi = .pengeluaran
    @State private var selectedKategori: Kategori? = nil
    @State private var selectedPocket: Pocket? = nil
    @State private var setiapTanggal: Int = 1
    @State private var catatan = ""

    var isEditing: Bool { item != nil }
    var filteredKategoris: [Kategori] { allKategoris.filter { $0.tipe == tipe } }
    var activePockets: [Pocket] { pockets.filter { $0.isAktif } }
    var canSave: Bool { nominal > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Nominal
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOMINAL").font(.caption).foregroundStyle(.gray)
                        HStack {
                            Text("Rp")
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(nominal == 0 ? "0" : nominal.idrFormatted.replacingOccurrences(of: "Rp ", with: ""))
                                .font(.title2.bold())
                                .foregroundStyle(tipe == .pengeluaran ? .red : .green)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        CurrencyInputField(value: $nominal)
                    }

                    // Tipe
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TIPE").font(.caption).foregroundStyle(.gray)
                        Picker("Tipe", selection: $tipe) {
                            Text("Pengeluaran").tag(TipeTransaksi.pengeluaran)
                            Text("Pemasukan").tag(TipeTransaksi.pemasukan)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: tipe) { _, _ in selectedKategori = nil }
                    }

                    // Kategori
                    VStack(alignment: .leading, spacing: 8) {
                        Text("KATEGORI").font(.caption).foregroundStyle(.gray)
                        KategoriGridPicker(kategoris: filteredKategoris, selected: $selectedKategori)
                    }

                    // Pocket
                    if !activePockets.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("POCKET").font(.caption).foregroundStyle(.gray)
                            PocketChipPicker(pockets: activePockets, selected: $selectedPocket)
                        }
                    }

                    // Tanggal tiap bulan
                    VStack(alignment: .leading, spacing: 8) {
                        Label("TANGGAL TIAP BULAN", systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 8) {
                            ForEach(1...28, id: \.self) { day in
                                Button {
                                    setiapTanggal = day
                                } label: {
                                    Text("\(day)")
                                        .font(.subheadline)
                                        .frame(width: 40, height: 40)
                                        .background(setiapTanggal == day ? Color.purple : Color.white.opacity(0.08))
                                        .foregroundStyle(setiapTanggal == day ? .white : .gray)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }

                    // Catatan
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CATATAN").font(.caption).foregroundStyle(.gray)
                        TextField("Catatan...", text: $catatan, axis: .vertical)
                            .lineLimit(3)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }
                }
                .padding()
            }
            .background(Color(hex: "#0D0D0D"))
            .navigationTitle(isEditing ? "Edit Transaksi Otomatis" : "Tambah Transaksi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Simpan" : "+ Tambah Transaksi") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? .green : .gray)
                }
            }
        }
        .onAppear { loadExisting() }
        .preferredColorScheme(.dark)
    }

    private func loadExisting() {
        guard let i = item else { return }
        nominal = i.nominal
        tipe = i.tipe
        selectedKategori = i.kategori
        selectedPocket = i.pocket
        setiapTanggal = i.setiapTanggal
        catatan = i.catatan ?? ""
    }

    private func save() {
        if let i = item {
            i.nominal = nominal
            i.tipe = tipe
            i.kategori = selectedKategori
            i.pocket = selectedPocket
            i.setiapTanggal = setiapTanggal
            i.catatan = catatan.isEmpty ? nil : catatan
        } else {
            let newItem = TransaksiOtomatis(
                nominal: nominal,
                tipe: tipe,
                kategori: selectedKategori,
                pocket: selectedPocket,
                setiapTanggal: setiapTanggal,
                catatan: catatan.isEmpty ? nil : catatan
            )
            context.insert(newItem)
        }
        try? context.save()
        dismiss()
    }
}
