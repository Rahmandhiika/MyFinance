import SwiftUI
import SwiftData
import PhotosUI

struct AddEditPocketView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingPocket: Pocket? = nil

    @Query private var allKategoriPocket: [KategoriPocket]

    // Form state
    @State private var nama: String = ""
    @State private var kelompok: KelompokPocket = .biasa
    @State private var selectedKategori: KategoriPocket? = nil
    @State private var saldoAwal: Decimal = 0
    @State private var limit: Decimal = 0
    @State private var catatan: String = ""
    @State private var logoData: Data? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    private var isEditing: Bool { existingPocket != nil }

    private var showLimitField: Bool {
        guard let k = selectedKategori else { return false }
        return k.nama.lowercased().contains("kartu kredit") || k.nama.lowercased().contains("paylater")
    }

    private var canSave: Bool {
        !nama.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // Logo picker
                        logoPicker

                        // Nama
                        formSection("Nama Pocket") {
                            TextField("Contoh: BCA Utama, GoPay", text: $nama)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Kelompok segmented
                        formSection("Kelompok") {
                            Picker("Kelompok", selection: $kelompok) {
                                ForEach(KelompokPocket.allCases) { k in
                                    Text(k.displayName).tag(k)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        // KategoriPocket picker
                        formSection("Kategori Pocket") {
                            if allKategoriPocket.isEmpty {
                                Text("Tidak ada kategori tersedia")
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                                    .padding(12)
                            } else {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(allKategoriPocket.sorted { $0.nama < $1.nama }) { k in
                                        KategoriPocketChip(
                                            nama: k.nama,
                                            isSelected: selectedKategori?.id == k.id
                                        )
                                        .onTapGesture {
                                            selectedKategori = selectedKategori?.id == k.id ? nil : k
                                        }
                                    }
                                }
                            }
                        }

                        // Saldo Awal (only for new pocket)
                        if !isEditing {
                            formSection("Saldo Awal") {
                                VStack(spacing: 4) {
                                    Text(saldoAwal > 0 ? saldoAwal.idrFormatted : "Rp 0")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    CurrencyInputField(value: $saldoAwal)
                                }
                            }
                        }

                        // Limit (Kartu Kredit/PayLater only)
                        if showLimitField {
                            formSection("Limit Kredit") {
                                VStack(spacing: 4) {
                                    Text(limit > 0 ? limit.idrFormatted : "Rp 0")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    CurrencyInputField(value: $limit)
                                }
                            }
                        }

                        // Catatan
                        formSection("Catatan (Opsional)") {
                            TextField("Tulis catatan...", text: $catatan, axis: .vertical)
                                .foregroundStyle(.white)
                                .lineLimit(3...)
                                .padding(12)
                                .background(Color.white.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle(isEditing ? "Edit Pocket" : "Tambah Pocket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { savePocket() }
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? Color(hex: "#22C55E") : .gray)
                        .disabled(!canSave)
                }
            }
            .onAppear { populateIfEditing() }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        logoData = data
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Logo Picker

    private var logoPicker: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack {
                    if let data = logoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "#22C55E"), lineWidth: 2)
                            )
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 80, height: 80)
                            .overlay(
                                VStack(spacing: 4) {
                                    Image(systemName: "camera.fill")
                                        .font(.title3)
                                        .foregroundStyle(.gray)
                                    Text("Foto")
                                        .font(.caption2)
                                        .foregroundStyle(.gray)
                                }
                            )
                    }

                    // Edit badge
                    Circle()
                        .fill(Color(hex: "#22C55E"))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.black)
                        )
                        .offset(x: 28, y: 28)
                }
            }

            if logoData != nil {
                Button("Hapus Foto") {
                    logoData = nil
                    selectedPhotoItem = nil
                }
                .font(.caption)
                .foregroundStyle(.red)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Form Section Helper

    @ViewBuilder
    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.gray)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
    }

    // MARK: - Logic

    private func populateIfEditing() {
        guard let p = existingPocket else { return }
        nama = p.nama
        kelompok = p.kelompokPocket
        selectedKategori = p.kategoriPocket
        catatan = p.catatan ?? ""
        logoData = p.logo
        if let l = p.limit { limit = l }
    }

    private func savePocket() {
        let trimmedNama = nama.trimmingCharacters(in: .whitespaces)
        guard !trimmedNama.isEmpty else { return }

        let limitValue: Decimal? = showLimitField && limit > 0 ? limit : nil

        if let existing = existingPocket {
            existing.nama = trimmedNama
            existing.kelompokPocket = kelompok
            existing.kategoriPocket = selectedKategori
            existing.catatan = catatan.isEmpty ? nil : catatan
            existing.logo = logoData
            existing.limit = limitValue
        } else {
            let newPocket = Pocket(
                nama: trimmedNama,
                kelompokPocket: kelompok,
                kategoriPocket: selectedKategori,
                saldo: saldoAwal,
                catatan: catatan.isEmpty ? nil : catatan,
                limit: limitValue
            )
            newPocket.logo = logoData
            modelContext.insert(newPocket)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - KategoriPocket Chip

private struct KategoriPocketChip: View {
    let nama: String
    let isSelected: Bool

    var body: some View {
        Text(nama)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? .black : .white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color(hex: "#22C55E") : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color(hex: "#22C55E") : Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}
