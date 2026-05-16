import SwiftUI
import SwiftData
import PhotosUI

struct PengaturanView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var themeManager: ThemeManager
    @Query private var profiles: [UserProfile]
    @State private var showKategori = false
    @State private var showKategoriPocket = false
    @State private var showAnggaran = false
    @State private var showLangganan = false
    @State private var showBackupRestore = false
    @State private var showRoadmap = false
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
                            .foregroundStyle(theme.textPrimary)
                            TextField("Greeting text", text: Binding(
                                get: { profile?.greetingText ?? "Halo" },
                                set: { newVal in
                                    profile?.greetingText = newVal
                                    try? context.save()
                                }
                            ))
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .listRowBackground(theme.bgListRow)
                }

                // KEUANGAN
                Section("KEUANGAN") {
                    HStack {
                        Label("Tanggal Gajian", systemImage: "calendar.badge.clock")
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { profile?.tanggalGajian ?? 25 },
                            set: { profile?.tanggalGajian = $0; try? context.save() }
                        )) {
                            ForEach(1...28, id: \.self) { day in
                                Text("Tgl \(day)").tag(day)
                            }
                        }
                        .pickerStyle(.menu)
                        .foregroundStyle(theme.accent)
                    }
                    .listRowBackground(theme.bgListRow)

                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary.opacity(0.6))
                        Text("Digunakan untuk mode Siklus Gajian di Analitik")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary.opacity(0.6))
                    }
                    .listRowBackground(theme.bgListRow)
                }

                // TAMPILAN
                Section("TAMPILAN") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tema Aplikasi")
                            .font(.subheadline).foregroundStyle(theme.textSecondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(AppTheme.all) { t in
                                    ThemeCard(theme: t, isSelected: themeManager.currentID == t.id) {
                                        themeManager.currentID = t.id
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(theme.bgListRow)
                }

                // MANAJEMEN
                Section("MANAJEMEN") {
                    Button { showKategori = true } label: {
                        HStack {
                            Label("Kategori Transaksi", systemImage: "tag.fill")
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(theme.textSecondary)
                        }
                    }
                    .listRowBackground(theme.bgListRow)

                    Button { showKategoriPocket = true } label: {
                        HStack {
                            Label("Kategori Pocket", systemImage: "folder.fill")
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(theme.textSecondary)
                        }
                    }
                    .listRowBackground(theme.bgListRow)

                    Button { showAnggaran = true } label: {
                        HStack {
                            Label("Anggaran", systemImage: "chart.bar.fill")
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(theme.textSecondary)
                        }
                    }
                    .listRowBackground(theme.bgListRow)

                    Button { showLangganan = true } label: {
                        HStack {
                            Label("Bills", systemImage: "creditcard.circle.fill")
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(theme.textSecondary)
                        }
                    }
                    .listRowBackground(theme.bgListRow)

                    Button { showBackupRestore = true } label: {
                        HStack {
                            Label("Backup & Restore", systemImage: "arrow.up.arrow.down.circle.fill")
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(theme.textSecondary)
                        }
                    }
                    .listRowBackground(theme.bgListRow)
                }

                // INFO APLIKASI
                Section("INFO") {
                    Button { showRoadmap = true } label: {
                        HStack {
                            Label("Roadmap & Coming Soon", systemImage: "sparkles")
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            Text("Level Up")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color(hex: "#22C55E"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: "#22C55E").opacity(0.12))
                                .clipShape(Capsule())
                            Image(systemName: "chevron.right").foregroundStyle(theme.textSecondary)
                        }
                    }
                    .listRowBackground(theme.bgListRow)

                    HStack {
                        Label("Versi", systemImage: "info.circle.fill")
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(theme.textSecondary)
                            .font(.subheadline)
                    }
                    .listRowBackground(theme.bgListRow)
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
                        .foregroundStyle(theme.danger)
                        .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(theme.danger.opacity(0.1))
                } header: {
                    Text("DANGER ZONE")
                        .foregroundStyle(theme.danger)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.bgApp)
            .navigationTitle("Pengaturan")
            .navigationBarTitleDisplayMode(.large)
            .overlay {
                if isResetting {
                    ZStack {
                        Color.black.opacity(0.6).ignoresSafeArea()
                        VStack(spacing: 14) {
                            ProgressView().tint(theme.textPrimary).scaleEffect(1.3)
                            Text("Menghapus data...")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(theme.textPrimary)
                        }
                        .padding(28)
                        .background(theme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
        .sheet(isPresented: $showKategori) { KategoriManagementView() }
        .sheet(isPresented: $showKategoriPocket) { KategoriPocketManagementView() }
        .sheet(isPresented: $showAnggaran) { AnggaranManagementView() }
        .sheet(isPresented: $showLangganan) { LanggananManagementView() }
        .sheet(isPresented: $showBackupRestore) { NavigationStack { BackupRestoreView() } }
        .sheet(isPresented: $showRoadmap) { NavigationStack { RoadmapView() } }
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
                    .fill(theme.accent.opacity(0.3))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(String(profile?.nama.prefix(1) ?? "D"))
                            .font(.title2.bold())
                            .foregroundStyle(theme.accent)
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

// MARK: - Theme Card

private struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Color preview: small squares
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.bgApp)
                        .frame(width: 28, height: 28)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 0.5))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.accent)
                        .frame(width: 28, height: 28)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.danger)
                        .frame(width: 28, height: 28)
                }
                Text("\(theme.emoji) \(theme.nama)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? theme.accent : .gray)
            }
            .padding(10)
            .background(theme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? theme.accent : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}
