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
    @Environment(\.appTheme) private var theme
    @Query private var allTransaksi: [Transaksi]
    @Query private var allTransfer: [TransferInternal]

    @State private var selectedMonth: Date = Date()
    @State private var searchText: String = ""
    @State private var showAddTransaksi = false
    @State private var showAddTransfer = false
    @State private var selectedItem: AnyTransaksiItem? = nil
    @State private var showPemasukanSheet = false
    @State private var showPengeluaranSheet = false
    /// Hasil filter+sort yang di-cache — tidak dihitung ulang setiap SwiftUI render.
    @State private var cachedItems: [AnyTransaksiItem] = []
    /// Debounce task untuk search — keystroke cepat tidak trigger sort tiap huruf.
    @State private var searchDebounceTask: Task<Void, Never>? = nil

    // MARK: - Single-pass computed stats
    // Previously: 5 separate O(n) passes over filteredTransaksi.
    // Now: 1 pass builds everything — 5× less work on every render.

    private struct TxStats {
        var pemasukan:    Decimal = 0
        var pengeluaran:  Decimal = 0
        var pemasukanList:    [Transaksi] = []
        var pengeluaranList:  [Transaksi] = []
        var perKategori:  [(Kategori, Decimal)] = []
        var bersih: Decimal { pemasukan - pengeluaran }
    }

    private var txStats: TxStats {
        var s = TxStats()
        var katMap: [UUID: (Kategori, Decimal)] = [:]
        for t in allTransaksi where t.tanggal.isSameMonth(as: selectedMonth) {
            switch t.tipe {
            case .pemasukan:
                s.pemasukan += t.nominal
                s.pemasukanList.append(t)
            case .pengeluaran:
                s.pengeluaran += t.nominal
                s.pengeluaranList.append(t)
                if let kat = t.kategori {
                    if let e = katMap[kat.id] { katMap[kat.id] = (kat, e.1 + t.nominal) }
                    else { katMap[kat.id] = (kat, t.nominal) }
                }
            }
        }
        s.pemasukanList.sort   { $0.tanggal > $1.tanggal }
        s.pengeluaranList.sort { $0.tanggal > $1.tanggal }
        s.perKategori = katMap.values.sorted { $0.1 > $1.1 }
        return s
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    /// Hitung items sekali lalu simpan ke cachedItems.
    /// Dipanggil dari onChange / task — bukan dari body.
    private func rebuildItems() {
        let stats = txStats
        let text  = searchText
        let lower = text.lowercased()
        let month = selectedMonth

        let transaksiItems = (stats.pemasukanList + stats.pengeluaranList)
            .filter { t in
                guard !text.isEmpty else { return true }
                return (t.kategori?.nama.lowercased().contains(lower) ?? false)
                    || (t.catatan?.lowercased().contains(lower) ?? false)
            }.map { AnyTransaksiItem.transaksi($0) }

        let transferItems = allTransfer
            .filter { $0.tanggal.isSameMonth(as: month) }
            .filter { t in
                guard !text.isEmpty else { return true }
                return (t.pocketAsal?.nama.lowercased().contains(lower) ?? false)
                    || (t.pocketTujuan?.nama.lowercased().contains(lower) ?? false)
                    || (t.catatan?.lowercased().contains(lower) ?? false)
            }.map { AnyTransaksiItem.transfer($0) }

        cachedItems = (transaksiItems + transferItems).sorted { $0.date > $1.date }
    }

    private func rebuildDebounced() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            rebuildItems()
        }
    }

    private var groupedItems: [(Date, [AnyTransaksiItem])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: cachedItems) { item in
            cal.startOfDay(for: item.date)
        }
        return dict.keys.sorted(by: >).map { key in
            (key, dict[key]!.sorted { $0.date > $1.date })
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bgApp.ignoresSafeArea()

                VStack(spacing: 0) {
                    MonthNavigator(selectedMonth: $selectedMonth)
                        .padding(.top, 8)

                    // Search bar — hanya bulan ini
                    if isCurrentMonth {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(theme.textSecondary)
                            TextField("Cari transaksi...", text: $searchText)
                                .foregroundStyle(theme.textPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(theme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.cardBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }

                    // Summary card
                    summaryCard
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    if isCurrentMonth {
                        // List transaksi — hanya bulan ini
                        if groupedItems.isEmpty {
                            emptyTransaksiState
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
                                            DaySectionHeader(date: day, bgColor: theme.bgApp)
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .refreshable {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                ModelContainerService.shared.executeAutoTransaksi()
                            }
                        }
                    } else {
                        // Analytics bulan lalu — per kategori
                        ScrollView {
                            pastMonthAnalytics
                                .padding(.horizontal, 16)
                                .padding(.top, 14)
                                .padding(.bottom, 32)
                        }
                    }
                }
            }
            .navigationTitle("Transaksi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.bgApp, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme == .dark ? .dark : .light, for: .navigationBar)
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
                            .foregroundStyle(theme.accent)
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
                    transactions: txStats.pemasukanList,
                    total: txStats.pemasukan,
                    accent: .green
                )
            }
            .sheet(isPresented: $showPengeluaranSheet) {
                TransaksiGroupSheet(
                    title: "Pengeluaran",
                    transactions: txStats.pengeluaranList,
                    total: txStats.pengeluaran,
                    accent: .red
                )
            }
            // Memoization triggers:
            // searchText → debounce 150ms (tidak sort tiap keystroke)
            // bulan/data berubah → rebuild langsung
            .task { rebuildItems() }
            .onChange(of: searchText)        { _, _ in rebuildDebounced() }
            .onChange(of: selectedMonth)     { _, _ in rebuildItems() }
            .onChange(of: allTransaksi.count){ _, _ in rebuildItems() }
            .onChange(of: allTransfer.count) { _, _ in rebuildItems() }
        }
    }

    // MARK: - Past Month Analytics

    private var pastMonthAnalytics: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "chart.pie.fill")
                    .font(.caption)
                    .foregroundStyle(theme.accent)
                Text("PENGELUARAN PER KATEGORI")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                    .tracking(0.5)
            }

            if txStats.perKategori.isEmpty {
                Text("Tidak ada pengeluaran di bulan ini")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(txStats.perKategori.enumerated()), id: \.offset) { _, pair in
                        let (kat, amount) = pair
                        let pct = txStats.pengeluaran > 0
                            ? Double(truncating: (amount / txStats.pengeluaran) as NSDecimalNumber)
                            : 0
                        VStack(spacing: 4) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: kat.warna).opacity(0.2))
                                        .frame(width: 34, height: 34)
                                    if let emoji = kat.ikonCustom, !emoji.isEmpty {
                                        Text(emoji).font(.system(size: 14))
                                    } else {
                                        Image(systemName: kat.ikon)
                                            .foregroundStyle(Color(hex: kat.warna))
                                            .font(.system(size: 13))
                                    }
                                }
                                Text(kat.nama)
                                    .font(.subheadline)
                                    .foregroundStyle(theme.textPrimary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(amount.idrFormatted)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(theme.pengeluaran)
                                    Text(String(format: "%.0f%%", pct * 100))
                                        .font(.caption2)
                                        .foregroundStyle(theme.textSecondary)
                                }
                            }
                            ProgressBarView(progress: pct, color: Color(hex: kat.warna), height: 3)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Summary card

    private var emptyTransaksiState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(theme.textSecondary.opacity(0.4))
            Text("Belum ada transaksi")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
            Text("Tap + untuk catat pengeluaran atau pemasukan pertama di bulan ini.")
                .font(.caption)
                .foregroundStyle(theme.textSecondary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 12) {
            // Bersih
            VStack(spacing: 2) {
                Text("Bersih")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                Text(txStats.bersih.idrFormatted)
                    .font(.title2.bold())
                    .foregroundStyle(txStats.bersih >= 0 ? theme.pemasukan : theme.pengeluaran)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Saldo bersih bulan ini: \(txStats.bersih.idrFormatted)")

            Divider().background(theme.separator)

            // Pemasukan + Pengeluaran
            HStack(spacing: 0) {
                Button {
                    showPemasukanSheet = true
                } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(theme.pemasukan)
                                .font(.caption)
                                .accessibilityHidden(true)
                            Text("Pemasukan")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        Text(txStats.pemasukan.idrFormatted)
                            .font(.subheadline.bold())
                            .foregroundStyle(theme.pemasukan)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pemasukan \(txStats.pemasukan.idrFormatted). Ketuk untuk detail.")

                Divider()
                    .frame(height: 36)
                    .background(theme.separator)

                Button {
                    showPengeluaranSheet = true
                } label: {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(theme.pengeluaran)
                                .font(.caption)
                                .accessibilityHidden(true)
                            Text("Pengeluaran")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        Text(txStats.pengeluaran.idrFormatted)
                            .font(.subheadline.bold())
                            .foregroundStyle(theme.pengeluaran)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pengeluaran \(txStats.pengeluaran.idrFormatted). Ketuk untuk detail.")
            }
        }
        .padding(16)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Day section header

private struct DaySectionHeader: View {
    let date: Date
    var bgColor: Color = Color.black
    @Environment(\.appTheme) private var theme

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "EEEE, dd MMM yyyy"
        return f
    }()

    private var label: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Hari Ini" }
        if cal.isDateInYesterday(date) { return "Kemarin" }
        return Self.dayFormatter.string(from: date)
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(bgColor)
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
    @Environment(\.appTheme) private var theme
    @Query private var allTargets: [Target]

    /// Target yang di-link via goalID (untuk subTipe simpanKeTarget / pakaiDariTarget)
    private var linkedTarget: Target? {
        guard let gid = transaksi.goalID else { return nil }
        return allTargets.first { $0.id == gid }
    }

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

            VStack(alignment: .leading, spacing: 3) {
                Text(transaksi.kategori?.nama ?? "Tanpa Kategori")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.textPrimary)

                HStack(spacing: 6) {
                    // Wishlist/Target badge — muncul kalau ada goalID
                    if let target = linkedTarget {
                        HStack(spacing: 3) {
                            Image(systemName: subTipeBadgeIcon(transaksi.subTipe))
                                .font(.system(size: 8))
                            Text(target.nama)
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(Color(hex: target.warna))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: target.warna).opacity(0.15))
                        .clipShape(Capsule())
                    }

                    // Pocket badge — selalu tampil
                    if let pocket = transaksi.pocket {
                        HStack(spacing: 3) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 8))
                            Text(pocket.nama)
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(Color(hex: "#A78BFA"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#A78BFA").opacity(0.15))
                        .clipShape(Capsule())
                    }

                    // Catatan (jika ada)
                    if let catatan = transaksi.catatan, !catatan.isEmpty {
                        Text(catatan)
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Text((transaksi.tipe == .pengeluaran ? "-" : "+") + transaksi.nominal.idrFormatted)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(transaksi.tipe == .pengeluaran ? theme.pengeluaran : theme.pemasukan)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func subTipeBadgeIcon(_ subTipe: SubTipeTransaksi) -> String {
        switch subTipe {
        case .beliWishlist:   return "heart.fill"
        case .simpanKeTarget: return "arrow.right.circle.fill"
        default:              return "arrow.left.circle.fill"
        }
    }
}

private struct TransferRow: View {
    let transfer: TransferInternal
    @Environment(\.appTheme) private var theme

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
                    .foregroundStyle(theme.textPrimary)
                HStack(spacing: 4) {
                    Text(transfer.pocketAsal?.nama ?? "-")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                    Text(transfer.pocketTujuan?.nama ?? "-")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
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
