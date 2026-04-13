import SwiftUI
import SwiftData
import PhotosUI

struct PengaturanView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var showKategori = false
    @State private var showAnggaran = false
    @State private var showTransaksiOtomatis = false
    @State private var showResetConfirm = false
    @State private var showFinalConfirm = false
    @State private var selectedPhoto: PhotosPickerItem?

    var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            List {
                // PROFIL
                Section("PROFIL") {
                    HStack(spacing: 12) {
                        profilePhoto
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Nama", text: Binding(
                                get: { profile?.nama ?? "" },
                                set: { newVal in
                                    profile?.nama = newVal
                                    try? context.save()
                                }
                            ))
                            .font(.headline)
                            .foregroundStyle(.white)
                            TextField("Greeting text", text: Binding(
                                get: { profile?.greetingText ?? "Halo" },
                                set: { newVal in
                                    profile?.greetingText = newVal
                                    try? context.save()
                                }
                            ))
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }

                // KONFIGURASI
                Section("KONFIGURASI") {
                    HStack {
                        Label("Tanggal Gajian", systemImage: "calendar.badge.checkmark")
                            .foregroundStyle(.white)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { profile?.tanggalGajian ?? 1 },
                            set: { newVal in
                                profile?.tanggalGajian = newVal
                                try? context.save()
                            }
                        )) {
                            ForEach(1...28, id: \.self) { day in
                                Text("Tanggal \(day)").tag(day)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.green)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }

                // MANAJEMEN
                Section("MANAJEMEN") {
                    Button { showKategori = true } label: {
                        HStack {
                            Label("Kategori", systemImage: "tag.fill")
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.gray)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))

                    Button { showAnggaran = true } label: {
                        HStack {
                            Label("Anggaran", systemImage: "chart.bar.fill")
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.gray)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))

                    Button { showTransaksiOtomatis = true } label: {
                        HStack {
                            Label("Transaksi Otomatis", systemImage: "arrow.clockwise.circle.fill")
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.gray)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }

                // DANGER ZONE
                Section {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Reset Semua Data")
                        }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Color.red.opacity(0.1))
                } header: {
                    Text("DANGER ZONE")
                        .foregroundStyle(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#0D0D0D"))
            .navigationTitle("Pengaturan")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showKategori) { KategoriManagementView() }
        .sheet(isPresented: $showAnggaran) { AnggaranManagementView() }
        .sheet(isPresented: $showTransaksiOtomatis) { TransaksiOtomatisView() }
        .alert("Reset Semua Data?", isPresented: $showResetConfirm) {
            Button("Batalkan", role: .cancel) {}
            Button("Lanjutkan", role: .destructive) { showFinalConfirm = true }
        } message: {
            Text("Ini akan menghapus SEMUA data termasuk transaksi, pocket, dan kategori. Tidak bisa dikembalikan.")
        }
        .alert("Yakin 100%?", isPresented: $showFinalConfirm) {
            Button("Batalkan", role: .cancel) {}
            Button("Hapus Semua", role: .destructive) { resetAllData() }
        } message: {
            Text("Tindakan ini permanen dan tidak bisa dibatalkan.")
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    profile?.fotoProfil = data
                    try? context.save()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    var profilePhoto: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            if let data = profile?.fotoProfil, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(String(profile?.nama.prefix(1) ?? "D"))
                            .font(.title2.bold())
                            .foregroundStyle(.green)
                    )
            }
        }
    }

    private func resetAllData() {
        do {
            try context.delete(model: Transaksi.self)
            try context.delete(model: TransferInternal.self)
            try context.delete(model: Pocket.self)
            try context.delete(model: KategoriPocket.self)
            try context.delete(model: Kategori.self)
            try context.delete(model: Target.self)
            try context.delete(model: SimpanKeTarget.self)
            try context.delete(model: Aset.self)
            try context.delete(model: Anggaran.self)
            try context.delete(model: TransaksiOtomatis.self)
            try context.delete(model: UserProfile.self)
            try context.save()
        } catch {
            print("Reset error: \(error)")
        }
        // Re-seed default data
        ModelContainerService.shared.ensureUserProfile()
    }
}
