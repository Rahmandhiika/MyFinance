import SwiftUI
import SwiftData

struct TransaksiOtomatisView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Query(sort: \TransaksiOtomatis.createdAt) private var items: [TransaksiOtomatis]
    @State private var showAdd = false
    @State private var editingItem: TransaksiOtomatis? = nil

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Belum Ada Transaksi Otomatis",
                        systemImage: "arrow.clockwise.circle",
                        description: Text("Tambah transaksi yang berulang tiap bulan")
                    )
                } else {
                    List {
                        ForEach(items) { item in
                            TransaksiOtomatisRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture { editingItem = item }
                                .listRowBackground(theme.bgCard)
                                .listRowSeparatorTint(theme.separator)
                        }
                        .onDelete { indexSet in
                            for i in indexSet { context.delete(items[i]) }
                            try? context.save()
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(theme.bgApp)
            .navigationTitle("Transaksi Otomatis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Tutup") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Label("Tambah", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddEditTransaksiOtomatisView() }
        .sheet(item: $editingItem) { item in AddEditTransaksiOtomatisView(item: item) }
        .preferredColorScheme(theme.colorScheme)
    }
}

struct TransaksiOtomatisRow: View {
    @Environment(\.modelContext) private var context
    @Environment(\.appTheme) private var theme
    let item: TransaksiOtomatis

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: item.kategori?.warna ?? "#6B7280"))
                        .frame(width: 36, height: 36)
                    if let emoji = item.kategori?.ikonCustom, !emoji.isEmpty {
                        Text(emoji)
                    } else {
                        Image(systemName: item.kategori?.ikon ?? "arrow.clockwise")
                            .foregroundStyle(.white)
                            .font(.system(size: 14))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.kategori?.nama ?? "Tanpa Kategori")
                        .foregroundStyle(theme.textPrimary)
                        .font(.subheadline)
                    HStack(spacing: 4) {
                        Text("Tanggal tiap bulan \(item.setiapTanggal)")
                        if let pocket = item.pocket {
                            Text("• \(pocket.nama)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.gray)
                }

                Spacer()

                Text(item.tipe == .pengeluaran ? "-\(item.nominal.idrFormatted)" : "+\(item.nominal.idrFormatted)")
                    .foregroundStyle(item.tipe == .pengeluaran ? .red : .green)
                    .font(.subheadline.bold())
            }

            HStack {
                Text("Aktif")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Spacer()
                Button {
                    context.delete(item)
                    try? context.save()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.gray)
                        .font(.caption)
                }
                Toggle("", isOn: Binding(
                    get: { item.isAktif },
                    set: { newVal in
                        item.isAktif = newVal
                        try? context.save()
                    }
                ))
                .tint(.purple)
                .labelsHidden()
            }
        }
        .padding(.vertical, 4)
    }
}
