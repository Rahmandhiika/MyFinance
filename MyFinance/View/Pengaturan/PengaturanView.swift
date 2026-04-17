import SwiftUI
import SwiftData
import PhotosUI

struct PengaturanView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var showKategori = false
    @State private var showAnggaran = false
    @State private var showLangganan = false
    @State private var showBackupRestore = false
    @State private var showResetConfirm = false
    @State private var showFinalConfirm = false
    @State private var isResetting = false
    @State private var selectedPhoto: PhotosPickerItem?

    var profile: UserProfile? { profiles.first }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

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

                    Button { showLangganan = true } label: {
                        HStack {
                            Label("Langganan", systemImage: "creditcard.circle.fill")
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.gray)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))

                    Button { showBackupRestore = true } label: {
                        HStack {
                            Label("Backup & Restore", systemImage: "arrow.up.arrow.down.circle.fill")
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.gray)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }

                // INFO APLIKASI
                Section("INFO") {
                    HStack {
                        Label("Versi", systemImage: "info.circle.fill")
                            .foregroundStyle(.white)
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.gray)
                            .font(.subheadline)
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
            .overlay {
                if isResetting {
                    ZStack {
                        Color.black.opacity(0.6).ignoresSafeArea()
                        VStack(spacing: 14) {
                            ProgressView().tint(.white).scaleEffect(1.3)
                            Text("Menghapus data...")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                        }
                        .padding(28)
                        .background(Color(hex: "#1A1A1A"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
        .sheet(isPresented: $showKategori) { KategoriManagementView() }
        .sheet(isPresented: $showAnggaran) { AnggaranManagementView() }
        .sheet(isPresented: $showLangganan) { LanggananManagementView() }
        .sheet(isPresented: $showBackupRestore) { NavigationStack { BackupRestoreView() } }
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
        isResetting = true
        Task {
            // Putus relasi aset → target dulu supaya cascade tidak konflik
            if let asets = try? context.fetch(FetchDescriptor<Aset>()) {
                for a in asets { a.linkedTarget = nil }
            }
            await Task.yield()

            // Hapus child sebelum parent
            if let items = try? context.fetch(FetchDescriptor<Transaksi>()) { items.forEach { context.delete($0) } }
            await Task.yield()
            if let items = try? context.fetch(FetchDescriptor<TransferInternal>()) { items.forEach { context.delete($0) } }
            await Task.yield()
            if let items = try? context.fetch(FetchDescriptor<SimpanKeTarget>()) { items.forEach { context.delete($0) } }
            await Task.yield()
            if let items = try? context.fetch(FetchDescriptor<Anggaran>()) { items.forEach { context.delete($0) } }
            await Task.yield()
            if let items = try? context.fetch(FetchDescriptor<PembayaranLangganan>()) { items.forEach { context.delete($0) } }
            await Task.yield()
            if let items = try? context.fetch(FetchDescriptor<Langganan>()) { items.forEach { context.delete($0) } }
            await Task.yield()
            if let items = try? context.fetch(FetchDescriptor<Target>()) { items.forEach { context.delete($0) } }
            await Task.yield()
            if let items = try? context.fetch(FetchDescriptor<Aset>()) { items.forEach { context.delete($0) } }
            await Task.yield()
            if let items = try? context.fetch(FetchDescriptor<Pocket>()) { items.forEach { context.delete($0) } }
            await Task.yield()
            if let items = try? context.fetch(FetchDescriptor<KategoriPocket>()) { items.forEach { context.delete($0) } }
            await Task.yield()
            if let items = try? context.fetch(FetchDescriptor<Kategori>()) { items.forEach { context.delete($0) } }
            await Task.yield()
            if let items = try? context.fetch(FetchDescriptor<UserProfile>()) { items.forEach { context.delete($0) } }
            await Task.yield()

            try? context.save()
            ModelContainerService.shared.seedAll()
            isResetting = false
        }
    }
}
