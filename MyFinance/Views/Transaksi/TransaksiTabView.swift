import SwiftUI
import SwiftData

// MARK: - Combined item wrapper

enum AnyTransaksiItem: Identifiable {
    case transaksi(Transaksi)
    case transfer(TransferInternal)

    var id: UUID {
        switch self {
        case .transaksi(let t): return t.id
        case .transfer(let t): return t.id
        }
    }

    var date: Date {
        switch self {
        case .transaksi(let t): return t.tanggal
        case .transfer(let t): return t.tanggal
        }
    }
}

// MARK: - Main View

struct TransaksiTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTransaksi: [Transaksi]
    @Query private var allTransfer: [TransferInternal]

    @State private var selectedMonth: Date = Date()
    @State private var searchText: String = ""
    @State private var showAddTransaksi = false
    @State private var showAddTransfer = false
    @State private var selectedItem: AnyTransaksiItem? = nil
    @State private var showPemasukanSheet = false
    @State private var showPengeluaranSheet = false

    // MARK: - Computed

    private var filteredTransaksi: [Transaksi] {
        allTransaksi.filter { $0.tanggal.isSameMonth(as: selectedMonth) }
    }

    private var filteredTransfer: [TransferInternal] {
        allTransfer.filter { $0.tanggal.isSameMonth(as: selectedMonth) }
    }

    private var searchedItems: [AnyTransaksiItem] {
        let transaksiItems = filteredTransaksi.filter { t in
            guard !searchText.isEmpty else { return true }
            let lower = searchText.lowercased()
            return (t.kategori?.nama.lowercased().contains(lower) ?? false)
                || (t.catatan?.lowercased().contains(lower) ?? false)
        }.map { AnyTransaksiItem.transaksi($0) }

        let transferItems = filteredTransfer.filter { t in
            guard !searchText.isEmpty else { return true }
            let lower = searchText.lowercased()
            return (t.pocketAsal?.nama.lowercased().contains(lower) ?? false)
                || (t.pocketTujuan?.nama.lowercased().contains(lower) ?? false)
                || (t.catatan?.lowercased().contains(lower) ?? false)
        }.map { AnyTransaksiItem.transfer($0) }

        return (transaksiItems + transferItems).sorted { $0.date > $1.date }
    }

    private var groupedItems: [(Date, [AnyTransaksiItem])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: searchedItems) { item in
            cal.startOfDay(for: item.date)
        }
        return dict.keys.sorted(by: >).map { key in
            (key, dict[key]!.sorted { $0.date > $1.date })
        }
    }

    private var totalPemasukan: Decimal {
        filteredTransaksi
            .filter { $0.tipe == .pemasukan }
            .reduce(Decimal(0)) { $0 + $1.nominal }
    }

    private var totalPengeluaran: Decimal {
        filteredTransaksi
            .filter { $0.tipe == .pengeluaran }
            .reduce(Decimal(0)) { $0 + $1.nominal }
    }

    private var bersih: Decimal { totalPemasukan - totalPengeluaran }

    private var pemasukanList: [Transaksi] {
        filteredTransaksi.filter { $0.tipe == .pemasukan }.sorted { $0.tanggal > $1.tanggal }
    }

    private var pengeluaranList: [Transaksi] {
        filteredTransaksi.filter { $0.tipe == .pengeluaran }.sorted { $0.tanggal > $1.tanggal }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()

                VStack(spacing: 0) {
                    MonthNavigator(selectedMonth: $selectedMonth)
                        .padding(.top, 8)

                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.gray)
                        TextField("Cari transaksi...", text: $searchText)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // Summary card
                    summaryCard
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    // List
                    if groupedItems.isEmpty {
                        Spacer()
                        Text("Belum ada transaksi")
                            .foregroundStyle(.gray)
                            .font(.subheadline)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                                ForEach(groupedItems, id: \.0) { day, items in
                                    Section {
                                        ForEach(items) { item in
                                            TransaksiRowView(item: item)
                                                .onTapGesture { selectedItem = item }
                                        }
                                    } header: {
                                        DaySectionHeader(date: day)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .navigationTitle("Transaksi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showAddTransaksi = true
                        } label: {
                            Label("Transaksi", systemImage: "plus.circle")
                        }
                        Button {
                            showAddTransfer = true
                        } label: {
                            Label("Transfer", systemImage: "arrow.left.arrow.right")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color(hex: "#22C55E"))
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showAddTransaksi) {
                AddEditTransaksiSheet()
            }
            .sheet(isPresented: $showAddTransfer) {
                TransferInternalSheet()
            }
            .sheet(item: $selectedItem) { item in
                switch item {
                case .transaksi(let t):
                    TransaksiDetailSheet(transaksi: t)
                case .transfer(let t):
                    TransferDetailSheet(transfer: t)
                }
            }
            .sheet(isPresented: $showPemasukanSheet) {
                TransaksiGroupSheet(
                    title: "Pemasukan",
                    transactions: pemasukanList,
                    total: totalPemasukan,
                    accent: .green
                )
            }
            .sheet(isPresented: $showPengeluaranSheet) {
                TransaksiGroupSheet(
                    title: "Pengeluaran",
                    transactions: pengeluaranList,
                    total: totalPengeluaran,
                    accent: .red
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(spacing: 12) {
            // Bersih
            VStack(spacing: 2) {
                Text("Bersih")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(bersih.idrFormatted)
                    .font(.title2.bold())
                    .foregroundStyle(bersih >= 0 ? .green : .red)
            }
            .frame(maxWidth: .infinity)

            Divider().background(Color.white.opacity(0.1))

            // Pemasukan + Pengeluaran
            HStack(spacing: 0) {
                Button {
                    showPemasukanSheet = true
                } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("Pemasukan")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        Text(totalPemasukan.idrFormatted)
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 36)
                    .background(Color.white.opacity(0.1))

                Button {
                    showPengeluaranSheet = true
                } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                            Text("Pengeluaran")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                        Text(totalPengeluaran.idrFormatted)
                            .font(.subheadline.bold())
                            .foregroundStyle(.red)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Day section header

private struct DaySectionHeader: View {
    let date: Date

    private var label: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Hari Ini" }
        if cal.isDateInYesterday(date) { return "Kemarin" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "EEEE, dd MMM yyyy"
        return f.string(from: date)
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.gray)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(hex: "#0D0D0D"))
    }
}

// MARK: - Transaction row

struct TransaksiRowView: View {
    let item: AnyTransaksiItem

    var body: some View {
        switch item {
        case .transaksi(let t):
            TransaksiRow(transaksi: t)
        case .transfer(let t):
            TransferRow(transfer: t)
        }
    }
}

private struct TransaksiRow: View {
    let transaksi: Transaksi

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: transaksi.kategori?.warna ?? "#6B7280").opacity(0.2))
                    .frame(width: 44, height: 44)
                if let emoji = transaksi.kategori?.ikonCustom, !emoji.isEmpty {
                    Text(emoji).font(.title3)
                } else {
                    Image(systemName: transaksi.kategori?.ikon ?? "tag")
                        .foregroundStyle(Color(hex: transaksi.kategori?.warna ?? "#6B7280"))
                        .font(.system(size: 18))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaksi.kategori?.nama ?? "Tanpa Kategori")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                if let catatan = transaksi.catatan, !catatan.isEmpty {
                    Text(catatan)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                } else if let pocket = transaksi.pocket {
                    Text(pocket.nama)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }

            Spacer()

            Text((transaksi.tipe == .pengeluaran ? "-" : "+") + transaksi.nominal.idrFormatted)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(transaksi.tipe == .pengeluaran ? .red : .green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct TransferRow: View {
    let transfer: TransferInternal

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(.blue)
                    .font(.system(size: 17))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Transfer")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                HStack(spacing: 4) {
                    Text(transfer.pocketAsal?.nama ?? "-")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    Text(transfer.pocketTujuan?.nama ?? "-")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }

            Spacer()

            Text(transfer.nominal.idrFormatted)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
