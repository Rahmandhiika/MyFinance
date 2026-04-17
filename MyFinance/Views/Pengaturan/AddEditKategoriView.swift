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
    @State private var isNabung = false
    @State private var isAdmin = false
    @State private var isHasilAset = false

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

                    // Tandai khusus (pengeluaran only)
                    if tipe == .pengeluaran {
                        VStack(spacing: 10) {
                            kategoriToggle(
                                isOn: $isNabung,
                                icon: "arrow.down.to.line.circle.fill",
                                color: "#06B6D4",
                                title: "Tandai sebagai Nabung",
                                subtitle: "Masuk ke \"Nabung Bulan Ini\" di beranda"
                            )
                            kategoriToggle(
                                isOn: $isAdmin,
                                icon: "building.columns.fill",
                                color: "#F59E0B",
                                title: "Tandai sebagai Biaya Admin",
                                subtitle: "Auto-assign ke biaya admin transfer & jual aset"
                            )
                        }
                    }

                    // Tandai khusus (pemasukan only)
                    if tipe == .pemasukan {
                        kategoriToggle(
                            isOn: $isHasilAset,
                            icon: "chart.bar.fill",
                            color: "#22C55E",
                            title: "Tandai sebagai Hasil Aset",
                            subtitle: "Auto-assign ke pemasukan saat jual aset"
                        )
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
        isNabung = k.isNabung
        isAdmin = k.isAdmin
        isHasilAset = k.isHasilAset
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
            k.isNabung = tipe == .pengeluaran ? isNabung : false
            k.isAdmin = tipe == .pengeluaran ? isAdmin : false
            k.isHasilAset = tipe == .pemasukan ? isHasilAset : false
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
            newK.isNabung = tipe == .pengeluaran ? isNabung : false
            newK.isAdmin = tipe == .pengeluaran ? isAdmin : false
            newK.isHasilAset = tipe == .pemasukan ? isHasilAset : false
            context.insert(newK)
        }
        try? context.save()
        dismiss()
    }

    @ViewBuilder
    private func kategoriToggle(isOn: Binding<Bool>, icon: String, color: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: color).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: color))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color(hex: color))
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
