import SwiftUI
import SwiftData

struct AddEditAnggaranView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Kategori.urutan) private var allKategoris: [Kategori]

    var anggaran: Anggaran? = nil
    var initialTipe: TipeAnggaran = .bulanan
    var selectedMonth: Date = Date()
    var selectedDay: Date = Date()

    @State private var nominal: Decimal = 0
    @State private var tipeAnggaran: TipeAnggaran = .bulanan
    @State private var selectedKategori: Kategori? = nil
    @State private var berulang = false
    @State private var pindahan = false
    @State private var harianBerulang = false

    var isEditing: Bool { anggaran != nil }
    var canSave: Bool { nominal > 0 }
    var pengeluaranKategoris: [Kategori] { allKategoris.filter { $0.tipe == .pengeluaran } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Nominal
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOMINAL ANGGARAN").font(.caption).foregroundStyle(.gray)
                        HStack {
                            Text("Rp").foregroundStyle(.gray)
                            Spacer()
                            Text(nominal == 0 ? "0" : nominal.idrFormatted.replacingOccurrences(of: "Rp ", with: ""))
                                .font(.title2.bold())
                                .foregroundStyle(Color(hex: "#FBBF24"))
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        CurrencyInputField(value: $nominal)
                    }

                    // Tipe Anggaran
                    Picker("Mode", selection: $tipeAnggaran) {
                        Label("Bulanan", systemImage: "calendar").tag(TipeAnggaran.bulanan)
                        Label("Harian", systemImage: "sun.max").tag(TipeAnggaran.harian)
                    }
                    .pickerStyle(.segmented)

                    // Bulanan toggles
                    if tipeAnggaran == .bulanan {
                        VStack(spacing: 12) {
                            Toggle(isOn: $berulang) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Berulang").foregroundStyle(.white)
                                    Text("Reset otomatis tiap bulan")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                            }
                            .tint(Color(hex: "#FBBF24"))
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            Toggle(isOn: $pindahan) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundStyle(Color(hex: "#FBBF24"))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Pindahan").foregroundStyle(.white)
                                        Text("Sisa anggaran otomatis dibawa ke bulan depan")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }
                                }
                            }
                            .tint(Color(hex: "#FBBF24"))
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Harian toggle
                    if tipeAnggaran == .harian {
                        Toggle(isOn: $harianBerulang) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Harian Berulang").foregroundStyle(.white)
                                Text("Tampil di semua hari")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                        }
                        .tint(Color(hex: "#FBBF24"))
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Kategori
                    VStack(alignment: .leading, spacing: 8) {
                        Text("KATEGORI (kosongkan untuk batas keseluruhan)")
                            .font(.caption)
                            .foregroundStyle(.gray)

                        Button {
                            selectedKategori = nil
                        } label: {
                            HStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedKategori == nil ? Color(hex: "#FBBF24") : Color.white.opacity(0.1))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: "chart.pie.fill")
                                        .foregroundStyle(selectedKategori == nil ? .black : .gray)
                                }
                                VStack(alignment: .leading) {
                                    Text("Keseluruhan")
                                        .foregroundStyle(.white)
                                    Text("Semua pengeluaran")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                Spacer()
                                if selectedKategori == nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color(hex: "#FBBF24"))
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        KategoriGridPicker(kategoris: pengeluaranKategoris, selected: $selectedKategori)
                    }
                }
                .padding()
            }
            .background(Color(hex: "#0D0D0D"))
            .navigationTitle(isEditing ? "Edit Anggaran" : "Buat Anggaran")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Simpan Anggaran") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? Color(hex: "#FBBF24") : .gray)
                }
            }
        }
        .onAppear { loadExisting() }
        .preferredColorScheme(.dark)
    }

    private func loadExisting() {
        guard let a = anggaran else {
            tipeAnggaran = initialTipe
            return
        }
        nominal = a.nominal
        tipeAnggaran = a.tipeAnggaran
        selectedKategori = a.kategori
        berulang = a.berulang
        pindahan = a.pindahan
        harianBerulang = a.harianBerulang
    }

    private func save() {
        let cal = Calendar.current
        if let a = anggaran {
            a.nominal = nominal
            a.tipeAnggaran = tipeAnggaran
            a.kategori = selectedKategori
            a.berulang = berulang
            a.pindahan = pindahan
            a.harianBerulang = harianBerulang
        } else {
            let newA = Anggaran(
                nominal: nominal,
                tipeAnggaran: tipeAnggaran,
                kategori: selectedKategori,
                berulang: berulang,
                pindahan: pindahan,
                harianBerulang: harianBerulang,
                bulan: tipeAnggaran == .bulanan ? cal.component(.month, from: selectedMonth) : nil,
                tahun: tipeAnggaran == .bulanan ? cal.component(.year, from: selectedMonth) : nil,
                tanggal: tipeAnggaran == .harian && !harianBerulang ? selectedDay : nil
            )
            context.insert(newA)
        }
        try? context.save()
        dismiss()
    }
}
