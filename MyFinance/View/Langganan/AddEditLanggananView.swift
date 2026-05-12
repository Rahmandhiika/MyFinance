import SwiftUI
import SwiftData
import PhotosUI

struct AddEditLanggananView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

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
                theme.bgApp.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Logo picker
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(theme.separator)
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
                                TextField("Nama bill", text: $nama)
                                    .foregroundStyle(theme.textPrimary)
                            }
                            Divider().background(theme.separator)
                            formRow {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Nominal per bulan")
                                            .foregroundStyle(theme.textSecondary)
                                            .font(.subheadline)
                                        Spacer()
                                        Text(nominalDecimal > 0 ? nominalDecimal.idrFormatted : "Rp 0")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(nominalDecimal > 0 ? theme.textPrimary : theme.textSecondary)
                                    }
                                    CalcInputField(value: $nominalDecimal)
                                    // Quick amount buttons — only in ADD mode
                                    if !isEditing {
                                        QuickAmountButtons(nominal: $nominalDecimal)
                                            .padding(.top, 4)
                                    }
                                }
                            }
                            Divider().background(theme.separator)
                            formRow {
                                Text("Tanggal tagih")
                                    .foregroundStyle(theme.textSecondary)
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
                        .background(theme.bgCard)
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
                                    .foregroundStyle(theme.textPrimary)
                            }
                        }
                        .background(theme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16)

                        Spacer(minLength: 32)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle(isEditing ? "Edit Bill" : "Tambah Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.bgApp, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(theme.textSecondary)
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
        .preferredColorScheme(theme.colorScheme)
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
