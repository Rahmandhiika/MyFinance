import SwiftUI
import SwiftData

struct KategoriPocketManagementView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Query(sort: \KategoriPocket.urutan) private var allKategori: [KategoriPocket]
    @Query private var allPockets: [Pocket]

    @State private var showAdd = false
    @State private var editingNama: String = ""
    @State private var editingKategori: KategoriPocket? = nil
    @State private var blockedAlert: (nama: String, count: Int)? = nil

    /// Berapa pocket yang memakai kategori ini
    private func usageCount(_ kategori: KategoriPocket) -> Int {
        allPockets.filter { $0.kategoriPocket?.id == kategori.id }.count
    }

    private func deleteKategoris(at indexSet: IndexSet) {
        for i in indexSet {
            let k = allKategori[i]
            let count = usageCount(k)
            if count > 0 {
                blockedAlert = (k.nama, count)
                return
            }
            context.delete(k)
        }
        try? context.save()
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(allKategori) { kategori in
                    let count = usageCount(kategori)
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.gray).font(.caption)

                        Text(kategori.nama)
                            .foregroundStyle(theme.textPrimary)
                            .font(.subheadline)

                        Spacer()

                        if count > 0 {
                            Text("\(count)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(theme.textSecondary)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(theme.cardBorder)
                                .clipShape(Capsule())
                        }

                        Image(systemName: "chevron.right")
                            .foregroundStyle(.gray).font(.caption)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingNama = kategori.nama
                        editingKategori = kategori
                    }
                    .listRowBackground(theme.bgCard)
                    .listRowSeparatorTint(theme.separator)
                }
                .onDelete(perform: deleteKategoris)
                .onMove { from, to in
                    var items = allKategori
                    items.move(fromOffsets: from, toOffset: to)
                    for (i, item) in items.enumerated() { item.urutan = i }
                    try? context.save()
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.bgApp)
            .navigationTitle("Kategori Pocket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Tutup") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        EditButton()
                        Button { showAdd = true } label: {
                            Label("Tambah", systemImage: "plus")
                        }
                    }
                }
            }
            .alert(
                "Tidak Bisa Dihapus",
                isPresented: Binding(
                    get: { blockedAlert != nil },
                    set: { if !$0 { blockedAlert = nil } }
                )
            ) {
                Button("OK", role: .cancel) { blockedAlert = nil }
            } message: {
                if let info = blockedAlert {
                    Text("\"\(info.nama)\" dipakai oleh \(info.count) pocket. Ganti kategori pocket tersebut terlebih dahulu.")
                }
            }
        }
        // Add new
        .sheet(isPresented: $showAdd) {
            KategoriPocketFormSheet(nama: "", onSave: { nama in
                let newUrutan = (allKategori.last?.urutan ?? -1) + 1
                let baru = KategoriPocket(nama: nama, urutan: newUrutan)
                context.insert(baru)
                try? context.save()
            })
        }
        // Edit existing
        .sheet(item: $editingKategori) { k in
            KategoriPocketFormSheet(nama: k.nama, onSave: { nama in
                k.nama = nama
                try? context.save()
            })
        }
        .preferredColorScheme(theme.colorScheme)
    }
}

// MARK: - Add/Edit Sheet

private struct KategoriPocketFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var nama: String
    let onSave: (String) -> Void

    init(nama: String, onSave: @escaping (String) -> Void) {
        _nama = State(initialValue: nama)
        self.onSave = onSave
    }

    private var isEditing: Bool { !nama.isEmpty }
    private var canSave: Bool { !nama.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bgApp.ignoresSafeArea()
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NAMA KATEGORI")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.gray)
                            .tracking(0.5)
                        TextField("Contoh: E-Wallet, Investasi...", text: $nama)
                            .foregroundStyle(theme.textPrimary)
                            .padding(12)
                            .background(theme.separator)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                    Spacer()
                }
            }
            .navigationTitle(isEditing ? "Edit Kategori" : "Tambah Kategori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.bgApp, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }.foregroundStyle(theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") {
                        onSave(nama.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(canSave ? Color(hex: "#22C55E") : .gray)
                    .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
    }
}
