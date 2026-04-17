import SwiftUI
import SwiftData

struct AddEditAnggaranView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Kategori.urutan) private var allKategoris: [Kategori]

    var anggaran: Anggaran? = nil
    var selectedMonth: Date = Date()

    @State private var nominal: Decimal = 0
    @State private var selectedKategori: Kategori? = nil
    @State private var berulang = false
    @State private var pindahan = false

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

                    // Toggles
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
        guard let a = anggaran else { return }
        nominal = a.nominal
        selectedKategori = a.kategori
        berulang = a.berulang
        pindahan = a.pindahan
    }

    private func save() {
        let cal = Calendar.current
        if let a = anggaran {
            a.nominal = nominal
            a.tipeAnggaran = .bulanan
            a.kategori = selectedKategori
            a.berulang = berulang
            a.pindahan = pindahan
        } else {
            let newA = Anggaran(
                nominal: nominal,
                tipeAnggaran: .bulanan,
                kategori: selectedKategori,
                berulang: berulang,
                pindahan: pindahan,
                bulan: cal.component(.month, from: selectedMonth),
                tahun: cal.component(.year, from: selectedMonth)
            )
            context.insert(newA)
        }
        try? context.save()
        dismiss()
    }
}
