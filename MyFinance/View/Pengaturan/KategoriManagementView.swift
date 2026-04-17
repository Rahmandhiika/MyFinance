import SwiftUI
import SwiftData

struct KategoriManagementView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Kategori.urutan) private var allKategoris: [Kategori]
    @State private var selectedTipe: TipeTransaksi = .pengeluaran
    @State private var showAdd = false
    @State private var editingKategori: Kategori? = nil

    var filteredKategoris: [Kategori] {
        allKategoris.filter { $0.tipe == selectedTipe }
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
                        KategoriRow(kategori: kategori)
                            .contentShape(Rectangle())
                            .onTapGesture { editingKategori = kategori }
                            .listRowBackground(Color.white.opacity(0.05))
                            .listRowSeparatorTint(.white.opacity(0.1))
                    }
                    .onDelete { indexSet in
                        for i in indexSet { context.delete(filteredKategoris[i]) }
                        try? context.save()
                    }
                    .onMove { from, to in
                        var items = filteredKategoris
                        items.move(fromOffsets: from, toOffset: to)
                        for (index, item) in items.enumerated() { item.urutan = index }
                        try? context.save()
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .background(Color(hex: "#0D0D0D"))
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
        }
        .sheet(isPresented: $showAdd) {
            AddEditKategoriView(initialTipe: selectedTipe)
        }
        .sheet(item: $editingKategori) { k in
            AddEditKategoriView(kategori: k)
        }
        .preferredColorScheme(.dark)
    }
}

struct KategoriRow: View {
    let kategori: Kategori

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
                        .foregroundStyle(.white)
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

            Image(systemName: "chevron.right")
                .foregroundStyle(.gray)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
