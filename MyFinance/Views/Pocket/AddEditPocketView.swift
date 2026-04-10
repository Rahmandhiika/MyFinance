import SwiftUI
import SwiftData
import PhotosUI

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

    // Photo
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var logoImage: Image?
    @State private var logoData: Data?

    private var isEditing: Bool { existingPocket != nil }
    private var isKreditType: Bool { kategori == .kartuKreditPayLater }

    var body: some View {
        NavigationStack {
            Form {
                // Logo picker section
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                if let logoImage {
                                    logoImage
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                } else {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(.tertiarySystemGroupedBackground))
                                        .frame(width: 80, height: 80)
                                        .overlay(
                                            VStack(spacing: 4) {
                                                if nama.isEmpty {
                                                    Image(systemName: "photo.badge.plus")
                                                        .font(.title2)
                                                        .foregroundStyle(.secondary)
                                                } else {
                                                    Text(String(nama.prefix(1)).uppercased())
                                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                                        .foregroundStyle(.blue)
                                                }
                                                Text("Foto")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        )
                                }

                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Image(systemName: "pencil")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                    )
                            }
                        }
                        .onChange(of: selectedPhoto) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    logoData = data
                                    if let uiImage = UIImage(data: data) {
                                        logoImage = Image(uiImage: uiImage)
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                    if logoData != nil {
                        Button(role: .destructive) {
                            logoData = nil
                            logoImage = nil
                            selectedPhoto = nil
                        } label: {
                            Label("Hapus Foto", systemImage: "trash")
                                .font(.subheadline)
                        }
                    }
                }

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
                    CurrencyInputField(label: isEditing ? "Saldo" : "Saldo Awal", amount: $saldoAwal)
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
        if let data = p.logo, let uiImage = UIImage(data: data) {
            logoData = data
            logoImage = Image(uiImage: uiImage)
        }
    }

    private func save() {
        if let p = existingPocket {
            p.nama = nama
            p.kelompokPocket = kelompok
            p.kategoriPocket = kategori
            p.saldo = saldoAwal
            p.limit = isKreditType ? limit : nil
            p.catatan = catatan.isEmpty ? nil : catatan
            p.logo = logoData
        } else {
            let pocket = Pocket(
                nama: nama, kelompokPocket: kelompok, kategoriPocket: kategori,
                saldo: saldoAwal, catatan: catatan.isEmpty ? nil : catatan,
                limit: isKreditType ? limit : nil
            )
            pocket.logo = logoData
            context.insert(pocket)
        }
        try? context.save()
        dismiss()
    }
}
