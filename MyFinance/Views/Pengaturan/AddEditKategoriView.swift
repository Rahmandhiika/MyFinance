import SwiftUI
import SwiftData

struct AddEditKategoriView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Kategori.urutan) private var allKategoris: [Kategori]

    var kategori: Kategori? = nil
    var initialTipe: TipeTransaksi = .pengeluaran

    @State private var nama = ""
    @State private var tipe: TipeTransaksi = .pengeluaran
    @State private var klasifikasi: KlasifikasiExpense? = nil
    @State private var kelompokIncome: KelompokIncome? = nil
    @State private var ikon = "tag"
    @State private var ikonCustom = ""
    @State private var warna = "#22C55E"

    var isEditing: Bool { kategori != nil }
    var canSave: Bool { !nama.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Nama
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NAMA").font(.caption).foregroundStyle(.gray)
                        TextField("contoh: Makanan & Minuman", text: $nama)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }

                    // Tipe
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TIPE").font(.caption).foregroundStyle(.gray)
                        Picker("Tipe", selection: $tipe) {
                            Text("Pengeluaran").tag(TipeTransaksi.pengeluaran)
                            Text("Pemasukan").tag(TipeTransaksi.pemasukan)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Klasifikasi (pengeluaran only)
                    if tipe == .pengeluaran {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("KLASIFIKASI (opsional)").font(.caption).foregroundStyle(.gray)
                            HStack(spacing: 8) {
                                ForEach(KlasifikasiExpense.allCases) { k in
                                    Button {
                                        klasifikasi = klasifikasi == k ? nil : k
                                    } label: {
                                        Text(k.displayName)
                                            .font(.subheadline)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(klasifikasi == k ? Color(hex: warna) : Color.white.opacity(0.1))
                                            .foregroundStyle(klasifikasi == k ? .white : .gray)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                                Spacer()
                            }
                        }
                    }

                    // Kelompok Income (pemasukan only)
                    if tipe == .pemasukan {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("KELOMPOK").font(.caption).foregroundStyle(.gray)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                                ForEach(KelompokIncome.allCases) { k in
                                    Button {
                                        kelompokIncome = kelompokIncome == k ? nil : k
                                    } label: {
                                        Text(k.displayName)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity)
                                            .background(kelompokIncome == k ? Color(hex: warna) : Color.white.opacity(0.1))
                                            .foregroundStyle(kelompokIncome == k ? .white : .gray)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                    }

                    // Ikon + Warna picker
                    IkonColorPicker(selectedIkon: $ikon, selectedWarna: $warna, ikonCustom: $ikonCustom)
                }
                .padding()
            }
            .background(Color(hex: "#0D0D0D"))
            .navigationTitle(isEditing ? "Edit Kategori" : "Kategori Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Simpan") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? Color(hex: warna) : .gray)
                }
            }
        }
        .onAppear { loadExisting() }
        .preferredColorScheme(.dark)
    }

    private func loadExisting() {
        guard let k = kategori else {
            tipe = initialTipe
            return
        }
        nama = k.nama
        tipe = k.tipe
        klasifikasi = k.klasifikasi
        kelompokIncome = k.kelompokIncome
        ikon = k.ikon
        ikonCustom = k.ikonCustom ?? ""
        warna = k.warna
    }

    private func save() {
        if let k = kategori {
            k.nama = nama.trimmingCharacters(in: .whitespaces)
            k.tipe = tipe
            k.klasifikasi = tipe == .pengeluaran ? klasifikasi : nil
            k.kelompokIncome = tipe == .pemasukan ? kelompokIncome : nil
            k.ikon = ikon
            k.ikonCustom = ikonCustom.isEmpty ? nil : ikonCustom
            k.warna = warna
        } else {
            let urutan = allKategoris.filter { $0.tipe == tipe }.count
            let newK = Kategori(
                nama: nama.trimmingCharacters(in: .whitespaces),
                tipe: tipe,
                klasifikasi: tipe == .pengeluaran ? klasifikasi : nil,
                kelompokIncome: tipe == .pemasukan ? kelompokIncome : nil,
                ikon: ikon,
                warna: warna,
                urutan: urutan
            )
            newK.ikonCustom = ikonCustom.isEmpty ? nil : ikonCustom
            context.insert(newK)
        }
        try? context.save()
        dismiss()
    }
}
