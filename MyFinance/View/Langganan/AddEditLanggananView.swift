import SwiftUI
import SwiftData
import PhotosUI

struct AddEditLanggananView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var existing: Langganan? = nil

    @Query(sort: \Kategori.urutan) private var allKategori: [Kategori]

    @State private var nama = ""
    @State private var nominalDecimal: Decimal = 0
    @State private var tanggalTagih = 1
    @State private var selectedKategori: Kategori? = nil
    @State private var catatan = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var logoData: Data? = nil

    private var isEditing: Bool { existing != nil }
    private var canSave: Bool { !nama.trimmingCharacters(in: .whitespaces).isEmpty && nominalDecimal > 0 }

    private var pengeluaranKategori: [Kategori] {
        allKategori.filter { $0.tipe == .pengeluaran }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Logo picker
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.07))
                                    .frame(width: 80, height: 80)
                                if let data = logoData, let uiImg = UIImage(data: data) {
                                    Image(uiImage: uiImg)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                } else {
                                    VStack(spacing: 4) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 24))
                                            .foregroundStyle(Color(hex: "#22C55E"))
                                        Text("Logo")
                                            .font(.caption2)
                                            .foregroundStyle(.gray)
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)

                        // Form fields
                        VStack(spacing: 1) {
                            formRow {
                                TextField("Nama langganan", text: $nama)
                                    .foregroundStyle(.white)
                            }
                            Divider().background(Color.white.opacity(0.06))
                            formRow {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Nominal per bulan")
                                            .foregroundStyle(.gray)
                                            .font(.subheadline)
                                        Spacer()
                                        Text(nominalDecimal > 0 ? nominalDecimal.idrFormatted : "Rp 0")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(nominalDecimal > 0 ? .white : .gray)
                                    }
                                    CurrencyInputField(value: $nominalDecimal)
                                    // Quick amount buttons — only in ADD mode
                                    if !isEditing {
                                        QuickAmountButtons(nominal: $nominalDecimal)
                                            .padding(.top, 4)
                                    }
                                }
                            }
                            Divider().background(Color.white.opacity(0.06))
                            formRow {
                                Text("Tanggal tagih")
                                    .foregroundStyle(.gray)
                                    .font(.subheadline)
                                Spacer()
                                Picker("", selection: $tanggalTagih) {
                                    ForEach(1...28, id: \.self) { day in
                                        Text("Tanggal \(day)").tag(day)
                                    }
                                }
                                .tint(Color(hex: "#22C55E"))
                            }
                        }
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16)

                        // Kategori
                        if !pengeluaranKategori.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("KATEGORI")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.gray)
                                    .tracking(0.5)
                                    .padding(.horizontal, 16)

                                KategoriGridPicker(
                                    kategoris: pengeluaranKategori,
                                    selected: $selectedKategori
                                )
                                .padding(.horizontal, 16)
                            }
                        }

                        // Catatan
                        VStack(spacing: 1) {
                            formRow {
                                TextField("Catatan (opsional)", text: $catatan)
                                    .foregroundStyle(.white)
                            }
                        }
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16)

                        Spacer(minLength: 32)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle(isEditing ? "Edit Langganan" : "Tambah Langganan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Simpan") { save() }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(canSave ? Color(hex: "#22C55E") : .gray)
                        .disabled(!canSave)
                }
            }
            .onAppear { populate() }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        logoData = data
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sub Views

    @ViewBuilder
    private func formRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack { content() }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
    }

    // MARK: - Logic

    private func populate() {
        guard let l = existing else { return }
        nama = l.nama
        nominalDecimal = l.nominal
        tanggalTagih = l.tanggalTagih
        selectedKategori = l.kategori
        catatan = l.catatan ?? ""
        logoData = l.logo
    }

    private func save() {
        if let l = existing {
            l.nama = nama.trimmingCharacters(in: .whitespaces)
            l.nominal = nominalDecimal
            l.tanggalTagih = tanggalTagih
            l.kategori = selectedKategori
            l.catatan = catatan.isEmpty ? nil : catatan
            l.logo = logoData
        } else {
            let l = Langganan(
                nama: nama.trimmingCharacters(in: .whitespaces),
                nominal: nominalDecimal,
                tanggalTagih: tanggalTagih,
                kategori: selectedKategori,
                catatan: catatan.isEmpty ? nil : catatan
            )
            l.logo = logoData
            context.insert(l)
        }
        try? context.save()
        dismiss()
    }
}
