import SwiftUI
import SwiftData

struct KategoriManagementView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Query(sort: \Kategori.urutan) private var allKategoris: [Kategori]
    @Query private var allTransaksi: [Transaksi]
    @State private var selectedTipe: TipeTransaksi = .pengeluaran
    @State private var showAdd = false
    @State private var editingKategori: Kategori? = nil
    @State private var blockedAlert: (nama: String, count: Int)? = nil

    var filteredKategoris: [Kategori] {
        allKategoris.filter { $0.tipe == selectedTipe }
    }

    /// Berapa transaksi yang memakai kategori ini
    private func usageCount(_ kategori: Kategori) -> Int {
        allTransaksi.filter { $0.kategori?.id == kategori.id }.count
    }

    private func deleteKategoris(at indexSet: IndexSet) {
        for i in indexSet {
            let k = filteredKategoris[i]
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
            VStack(spacing: 0) {
                Picker("Tipe", selection: $selectedTipe) {
                    Text("Pengeluaran").tag(TipeTransaksi.pengeluaran)
                    Text("Pemasukan").tag(TipeTransaksi.pemasukan)
                }
                .pickerStyle(.segmented)
                .padding()

                List {
                    ForEach(filteredKategoris) { kategori in
                        let count = usageCount(kategori)
                        KategoriRow(kategori: kategori, usageCount: count)
                            .contentShape(Rectangle())
                            .onTapGesture { editingKategori = kategori }
                            .listRowBackground(theme.bgCard)
                            .listRowSeparatorTint(theme.separator)
                    }
                    .onDelete(perform: deleteKategoris)
                    .onMove { from, to in
                        var items = filteredKategoris
                        items.move(fromOffsets: from, toOffset: to)
                        for (index, item) in items.enumerated() { item.urutan = index }
                        try? context.save()
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .background(theme.bgApp)
            .navigationTitle("Kategori")
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
                    Text("\"\(info.nama)\" dipakai oleh \(info.count) transaksi. Hapus atau ganti kategori transaksi tersebut terlebih dahulu.")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddEditKategoriView(initialTipe: selectedTipe)
        }
        .sheet(item: $editingKategori) { k in
            AddEditKategoriView(kategori: k)
        }
        .preferredColorScheme(theme.colorScheme)
    }
}

struct KategoriRow: View {
    @Environment(\.appTheme) private var theme
    let kategori: Kategori
    let usageCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.gray)
                .font(.caption)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: kategori.warna))
                    .frame(width: 36, height: 36)
                if let emoji = kategori.ikonCustom, !emoji.isEmpty {
                    Text(emoji).font(.body)
                } else {
                    Image(systemName: kategori.ikon)
                        .foregroundStyle(.white)
                        .font(.system(size: 14))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(kategori.nama)
                        .foregroundStyle(theme.textPrimary)
                        .font(.subheadline)
                    if kategori.isNabung {
                        Image(systemName: "arrow.down.to.line.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "#06B6D4"))
                    }
                    if kategori.isAdmin {
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "#F59E0B"))
                    }
                    if kategori.isHasilAset {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "#22C55E"))
                    }
                    if kategori.isWishlist {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "#EC4899"))
                    }
                }
                if let k = kategori.klasifikasi {
                    Text(k.displayName)
                        .font(.caption)
                        .foregroundStyle(.gray)
                } else if let k = kategori.kelompokIncome {
                    Text(k.displayName)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }

            Spacer()

            if usageCount > 0 {
                // Badge: shows usage count, signals category is locked from deletion
                Text("\(usageCount)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(theme.cardBorder)
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(.gray)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
