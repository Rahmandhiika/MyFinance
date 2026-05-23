import SwiftUI
import SwiftData
import Charts

struct AsetListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @Query(sort: [SortDescriptor(\Aset.urutan), SortDescriptor(\Aset.createdAt)]) var allAset: [Aset]

    @Query(sort: \PortofolioConfig.urutan) private var allPortofolioConfigs: [PortofolioConfig]

    private let priceService = AsetPriceService.shared
    @State private var selectedAset: Aset? = nil
    @State private var editingPortofolioConfig: PortofolioConfig? = nil
    @State private var showAdd = false
    @State private var showReorder = false
    @State private var showAnalisa = false
    @State private var flatItems: [FlatReorderItem] = []
    @State private var deleteBlockedAlert: (nama: String, count: Int)? = nil
    @State private var showAddGrup = false
    @State private var showPerformaAll = false
    @State private var showTargetAlokasi = false
    @AppStorage("targetAlokasiJSON") private var targetAlokasiJSON: String = "{}"

    private var targetAlokasi: [String: Double] {
        guard let data = targetAlokasiJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data) else { return [:] }
        return dict
    }

    // MARK: - Computed Totals (aset bebas saja, tidak termasuk linked target)

    private var freeAset: [Aset] { allAset.filter { $0.linkedTarget == nil } }
    private var linkedAset: [Aset] { allAset.filter { $0.linkedTarget != nil } }

    private var totalNilai: Decimal { freeAset.reduce(0) { $0 + $1.nilaiEfektif } }
    private var totalModal: Decimal { freeAset.reduce(0) { $0 + $1.modal } }
    private var keuntungan: Decimal { totalNilai - totalModal }
    private var returnPersen: Double {
        guard totalModal > 0 else { return 0 }
        return Double(truncating: (keuntungan / totalModal * 100) as NSDecimalNumber)
    }

    // MARK: - Grouped by Portfolio

    /// Aset bebas yang memiliki nama portofolio, dikelompokkan per nama
    private var portofolioGroups: [(nama: String, items: [Aset])] {
        let withPorto = freeAset.filter { $0.portofolio != nil && !($0.portofolio!.isEmpty) }
        var grouped: [String: [Aset]] = [:]
        for aset in withPorto {
            grouped[aset.portofolio!, default: []].append(aset)
        }
        let configMap = Dictionary(uniqueKeysWithValues: allPortofolioConfigs.map { ($0.nama, $0.urutan) })
        return grouped.map { (nama: $0.key, items: $0.value) }
            .sorted {
                let u0 = configMap[$0.nama] ?? Int.max
                let u1 = configMap[$1.nama] ?? Int.max
                return u0 != u1 ? u0 < u1 : $0.nama < $1.nama
            }
    }

    /// Aset bebas tanpa portofolio, digroup per tipe
    private var noPortofolioAset: [Aset] {
        freeAset.filter { $0.portofolio == nil || $0.portofolio!.isEmpty }
    }

    private func configFor(nama: String) -> PortofolioConfig? {
        allPortofolioConfigs.first { $0.nama == nama }
    }

    private func colorForPortofolio(_ nama: String) -> Color {
        Color(hex: configFor(nama: nama)?.warna ?? "#A78BFA")
    }

    private func ensurePortofolioConfigs() {
        let existingNames = Set(allPortofolioConfigs.map { $0.nama })
        let usedNames = Set(freeAset.compactMap { $0.portofolio }.filter { !$0.isEmpty })
        let missing = usedNames.subtracting(existingNames)
        guard !missing.isEmpty else { return }
        var next = (allPortofolioConfigs.map { $0.urutan }.max() ?? -1) + 1
        for name in missing.sorted() {
            modelContext.insert(PortofolioConfig(nama: name, urutan: next))
            next += 1
        }
        try? modelContext.save()
    }

    private func deletePortofolioConfigs(at indexSet: IndexSet) {
        for i in indexSet {
            let config = allPortofolioConfigs[i]
            let count = allAset.filter { $0.portofolio == config.nama }.count
            if count > 0 {
                deleteBlockedAlert = (config.nama, count)
                return
            }
            modelContext.delete(config)
        }
        try? modelContext.save()
    }

    // MARK: - Alokasi & Performa

    struct AlokasiItem: Identifiable {
        let id = UUID()
        let label: String
        let nilai: Double
        let nilaiDecimal: Decimal
        let color: Color
        var pct: String = ""
        var nilaiFormatted: String = ""
    }

    private var alokasiData: [AlokasiItem] {
        guard totalNilai > 0 else { return [] }
        let grouped: [(TipeAset, Decimal)] = TipeAset.allCases.compactMap { tipe in
            let total = freeAset.filter { $0.tipe == tipe }.reduce(Decimal(0)) { $0 + $1.nilaiEfektif }
            return total > 0 ? (tipe, total) : nil
        }
        let totalD = Double(truncating: totalNilai as NSDecimalNumber)
        return grouped.map { (tipe, nilai) in
            let d = Double(truncating: nilai as NSDecimalNumber)
            let pct = String(format: "%.1f%%", d / totalD * 100)
            return AlokasiItem(label: tipe.displayName, nilai: d, nilaiDecimal: nilai,
                               color: tipe.color, pct: pct, nilaiFormatted: nilai.shortFormatted)
        }.sorted { $0.nilai > $1.nilai }
    }

    private var asetByPerforma: [Aset] {
        freeAset.sorted { $0.returnPersen > $1.returnPersen }
    }

    private var asetBySaham:     [Aset] { noPortofolioAset.filter { $0.tipe == .saham } }
    private var anySaham:        [Aset] { freeAset.filter { $0.tipe == .saham } }  // termasuk yang di dalam portofolio
    private var asetBySahamAS:   [Aset] { noPortofolioAset.filter { $0.tipe == .sahamAS } }
    private var asetByReksadana: [Aset] { noPortofolioAset.filter { $0.tipe == .reksadana } }
    private var asetByValas:     [Aset] { noPortofolioAset.filter { $0.tipe == .valas } }
    private var asetByEmas:      [Aset] { noPortofolioAset.filter { $0.tipe == .emas } }
    private var asetByDeposito:  [Aset] { noPortofolioAset.filter { $0.tipe == .deposito } }

    // MARK: - Body

    var body: some View {
        ZStack {
            theme.bgApp.ignoresSafeArea()

            if allAset.isEmpty {
                emptyState
            } else if showReorder {
                reorderList
            } else {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        portfolioCard
                        MarketOverviewCard()
                        if !alokasiData.isEmpty { alokasiCard }
                        if !freeAset.isEmpty { performaCard }
                        asetSections
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .padding(.top, 8)
                }
                .refreshable {
                    await priceService.refreshAll(allAset)
                }
            }

            // Loading overlay
            if priceService.isLoading && !showReorder {
                loadingOverlay
            }
        }
        .navigationTitle("Aset")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if showReorder {
                    EmptyView()
                } else {
                    refreshButton
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if showReorder {
                    HStack(spacing: 12) {
                        Button { showAddGrup = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "folder.badge.plus").font(.caption.weight(.semibold))
                                Text("Grup").font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(Color(hex: "#A78BFA"))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color(hex: "#A78BFA").opacity(0.12))
                            .clipShape(Capsule())
                        }
                        Button("Selesai") {
                            withAnimation(.easeInOut(duration: 0.2)) { showReorder = false }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    }
                } else {
                    HStack(spacing: 8) {
                        if !anySaham.isEmpty {
                            Button {
                                showAnalisa = true
                            } label: {
                                Image(systemName: "chart.xyaxis.line")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        if allAset.count > 1 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { showReorder = true }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        Button {
                            showAdd = true
                        } label: {
                            Label("Tambah", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .task {
            if !allAset.isEmpty {
                await priceService.refreshAll(allAset)
            }
        }
        .onAppear { ensurePortofolioConfigs() }
        // onChange(of: allAset) dihapus — price updates tidak perlu trigger config sync
        // ensurePortofolioConfigs hanya perlu jalan saat view muncul
        .onChange(of: allAset.map(\.portofolio)) { _, _ in ensurePortofolioConfigs() }
        .sheet(item: $selectedAset) { aset in
            AsetDetailSheet(aset: aset)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingPortofolioConfig) { config in
            EditPortofolioSheet(config: config)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .alert(
            "Tidak Bisa Dihapus",
            isPresented: Binding(
                get: { deleteBlockedAlert != nil },
                set: { if !$0 { deleteBlockedAlert = nil } }
            )
        ) {
            Button("OK", role: .cancel) { deleteBlockedAlert = nil }
        } message: {
            if let info = deleteBlockedAlert {
                Text("\"\(info.nama)\" masih dipakai \(info.count) aset. Pindahkan semua aset dari grup ini terlebih dahulu.")
            }
        }
        .sheet(isPresented: $showAdd) {
            AddEditAsetView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddGrup) {
            AddGrupSheet { nama, warna in
                let urutan = (allPortofolioConfigs.map { $0.urutan }.max() ?? -1) + 1
                modelContext.insert(PortofolioConfig(nama: nama, warna: warna, urutan: urutan))
                try? modelContext.save()
            }
        }
        .sheet(isPresented: $showAnalisa) {
            AnalisaSahamView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPerformaAll) {
            PerformaAllSheet(aset: asetByPerforma)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Refresh Button

    private var refreshButton: some View {
        Button {
            Task { await priceService.refreshAll(allAset) }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(priceService.isLoading ? theme.textSecondary.opacity(0.5) : theme.textSecondary)
                .rotationEffect(.degrees(priceService.isLoading ? 360 : 0))
                .animation(
                    priceService.isLoading
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default,
                    value: priceService.isLoading
                )
        }
        .disabled(priceService.isLoading)
    }

    // MARK: - Portfolio Card

    private var portfolioCard: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("PORTOFOLIO")
                            .font(.caption)
                            .foregroundStyle(theme.textPrimary.opacity(0.5))
                            .tracking(1)
                        Text("\(freeAset.count) ASET")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(theme.textPrimary.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(theme.separator)
                            .clipShape(Capsule())
                    }

                    Text(totalNilai.idrDecimalFormatted)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(theme.textPrimary)
                }
                Spacer()

                // Return badge
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: keuntungan >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption.weight(.bold))
                        Text(returnPersen.percentFormatted)
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(keuntungan >= 0 ? theme.pemasukan : theme.pengeluaran)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((keuntungan >= 0 ? theme.pemasukan : theme.pengeluaran).opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()
                .background(theme.separator)

            // Stats row
            HStack {
                PortfolioStat(label: "TOTAL MODAL", value: totalModal.idrDecimalFormatted, labelColor: theme.textSecondary, valueColor: theme.textPrimary)
                Divider()
                    .background(theme.separator)
                    .frame(height: 36)
                PortfolioStat(
                    label: "KEUNTUNGAN",
                    value: "\(keuntungan >= 0 ? "+" : "")\(keuntungan.idrDecimalFormatted)",
                    labelColor: theme.textSecondary,
                    valueColor: keuntungan >= 0 ? theme.pemasukan : theme.pengeluaran
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Last updated
            if let lastUpdated = priceService.lastUpdated {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Update: \(lastUpdated.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                }
                .foregroundStyle(theme.textSecondary.opacity(0.5))
                .padding(.bottom, 12)
            }
        }
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Alokasi Card

    private var alokasiCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(theme.accent).font(.caption)
                Text("ALOKASI ASET")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button { showTargetAlokasi = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3").font(.system(size: 10, weight: .semibold))
                        Text("Set Target").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(theme.accent.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            HStack(alignment: .center, spacing: 20) {
                // Donut chart
                Chart(alokasiData) { item in
                    SectorMark(
                        angle: .value("Nilai", item.nilai),
                        innerRadius: .ratio(0.58),
                        angularInset: 1.5
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                }
                .frame(width: 90, height: 90)

                // Legend dengan target deviation
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(alokasiData) { item in
                        let currentPct = item.nilai / (Double(truncating: totalNilai as NSDecimalNumber)) * 100
                        let targetPct  = targetAlokasi[item.label]
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(item.color)
                                .frame(width: 10, height: 10)
                            Text(item.label)
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(1)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.pct)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(theme.textPrimary)
                                if let target = targetPct {
                                    let delta = currentPct - target
                                    let sign  = delta > 0 ? "+" : ""
                                    let color: Color = abs(delta) <= 5 ? Color(hex: "#22C55E")
                                                     : delta > 0     ? Color(hex: "#F59E0B")
                                                                      : Color(hex: "#60A5FA")
                                    Text("\(sign)\(String(format: "%.0f", delta))% vs target")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(color)
                                }
                            }
                        }
                    }
                }
            }

            // Rebalancing hints
            let hints = rebalancingHints
            if !hints.isEmpty {
                Divider().background(theme.separator)
                VStack(alignment: .leading, spacing: 4) {
                    Text("REBALANCING")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                        .tracking(0.5)
                    ForEach(hints, id: \.self) { hint in
                        HStack(alignment: .top, spacing: 6) {
                            Text("·").foregroundStyle(Color(hex: "#F59E0B"))
                            Text(hint).font(.caption).foregroundStyle(theme.textSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardBorder, lineWidth: 1))
        .sheet(isPresented: $showTargetAlokasi) {
            TargetAlokasiSheet(alokasiData: alokasiData, targetAlokasiJSON: $targetAlokasiJSON)
        }
    }

    private var rebalancingHints: [String] {
        guard !targetAlokasi.isEmpty, totalNilai > 0 else { return [] }
        let totalD = Double(truncating: totalNilai as NSDecimalNumber)
        return alokasiData.compactMap { item in
            guard let target = targetAlokasi[item.label] else { return nil }
            let current = item.nilai / totalD * 100
            let delta   = current - target
            guard abs(delta) > 5 else { return nil }
            if delta > 0 {
                return "\(item.label) \(String(format: "%.0f%%", current)) → over target \(String(format: "%.0f%%", target)), pertimbangkan kurangi."
            } else {
                return "\(item.label) \(String(format: "%.0f%%", current)) → under target \(String(format: "%.0f%%", target)), pertimbangkan tambah."
            }
        }
    }

    // MARK: - Performa Card

    private var performaCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(Color(hex: "#F59E0B")).font(.caption)
                    Text("PERFORMA TERBAIK")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                if freeAset.count > 4 {
                    Button("Lihat Semua") { showPerformaAll = true }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)

            Divider().background(theme.separator)

            ForEach(Array(asetByPerforma.prefix(4).enumerated()), id: \.element.id) { idx, aset in
                PerformaRow(rank: idx + 1, aset: aset, theme: theme)
                if idx < min(3, asetByPerforma.count - 1) {
                    Divider().background(theme.separator).padding(.leading, 56)
                }
            }
        }
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardBorder, lineWidth: 1))
    }

    // MARK: - Aset Sections

    private var asetSections: some View {
        LazyVStack(spacing: 16) {
            // Portfolio groups (aset dengan nama portofolio)
            ForEach(portofolioGroups, id: \.nama) { group in
                PortofolioSection(
                    nama: group.nama,
                    items: group.items,
                    color: colorForPortofolio(group.nama),
                    onTap: { selectedAset = $0 },
                    onEdit: { editingPortofolioConfig = configFor(nama: group.nama) }
                )
            }

            // Aset tanpa portofolio, digroup per tipe
            if !asetBySaham.isEmpty {
                AsetSection(tipe: .saham, items: asetBySaham, onTap: { selectedAset = $0 })
            }
            if !asetBySahamAS.isEmpty {
                AsetSection(tipe: .sahamAS, items: asetBySahamAS, onTap: { selectedAset = $0 })
            }
            if !asetByReksadana.isEmpty {
                AsetSection(tipe: .reksadana, items: asetByReksadana, onTap: { selectedAset = $0 })
            }
            if !asetByValas.isEmpty {
                AsetSection(tipe: .valas, items: asetByValas, onTap: { selectedAset = $0 })
            }
            if !asetByEmas.isEmpty {
                AsetSection(tipe: .emas, items: asetByEmas, onTap: { selectedAset = $0 })
            }
            if !asetByDeposito.isEmpty {
                AsetSection(tipe: .deposito, items: asetByDeposito, onTap: { selectedAset = $0 })
            }
            if !linkedAset.isEmpty {
                TargetAsetSection(items: linkedAset, onTap: { selectedAset = $0 })
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(theme.bgCard)
                    .frame(width: 80, height: 80)
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(theme.textSecondary)
            }

            VStack(spacing: 8) {
                Text("Belum Ada Aset")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.textPrimary)
                Text("Catat investasi kamu — saham, reksadana,\nvalas, emas, atau deposito.")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showAdd = true
            } label: {
                Label("Tambah Aset Pertama", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textOnColor)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(theme.accent)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        VStack(spacing: 8) {
            ProgressView()
                .tint(theme.textPrimary)
            Text("Memperbarui harga...")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(20)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.4), radius: 20)
    }
}

// MARK: - Flat Reorder Item

/// Item di flat reorder list — bisa header grup (non-movable) atau aset (movable).
enum FlatReorderItem: Identifiable {
    case portfolioHeader(String)       // nama portofolio
    case tipeHeader(TipeAset)          // tipe tanpa portofolio
    case linkedHeader                  // target investasi (non-movable group)
    case aset(UUID)                    // referensi ke Aset by ID

    var id: String {
        switch self {
        case .portfolioHeader(let n): return "ph_\(n)"
        case .tipeHeader(let t):      return "th_\(t.rawValue)"
        case .linkedHeader:           return "linked_header"
        case .aset(let id):           return id.uuidString
        }
    }

    var isHeader: Bool {
        switch self {
        case .aset: return false
        default:    return true
        }
    }
}

// MARK: - Reorder List (flat — supports cross-group drag)

extension AsetListView {

    var reorderList: some View {
        List {
            // Section 0: Urutan grup portofolio (tidak berubah)
            if !allPortofolioConfigs.isEmpty {
                Section {
                    ForEach(allPortofolioConfigs) { config in
                        let asetCount = allAset.filter { $0.portofolio == config.nama }.count
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color(hex: config.warna).opacity(0.15)).frame(width: 32, height: 32)
                                Image(systemName: "folder.fill").font(.system(size: 13)).foregroundStyle(Color(hex: config.warna))
                            }
                            Text(config.nama).foregroundStyle(theme.textPrimary).font(.subheadline)
                            Spacer()
                            if asetCount > 0 {
                                Text("\(asetCount) aset")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(theme.textSecondary)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(theme.separator)
                                    .clipShape(Capsule())
                            }
                        }
                        .listRowBackground(Color(hex: config.warna).opacity(0.05))
                    }
                    .onMove { from, to in
                        var mutable = allPortofolioConfigs
                        mutable.move(fromOffsets: from, toOffset: to)
                        for (i, c) in mutable.enumerated() { c.urutan = i }
                        try? modelContext.save()
                    }
                    .onDelete { indexSet in
                        deletePortofolioConfigs(at: indexSet)
                    }
                } header: {
                    Text("URUTAN GRUP PORTOFOLIO")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(hex: "#A78BFA").opacity(0.7))
                }
            }

            // Section 1: Flat — semua aset + header non-movable
            // Drag ke bawah header portofolio lain → aset pindah ke grup itu
            Section {
                ForEach(flatItems) { item in
                    flatRow(item: item)
                        .moveDisabled(item.isHeader)
                        .listRowBackground(flatRowBackground(item: item))
                }
                .onMove { from, to in
                    applyFlatMove(from: from, to: to)
                }
            } header: {
                Text("ASET — DRAG ANTAR GRUP")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.textSecondary.opacity(0.6))
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(theme.bgApp)
        .listStyle(.insetGrouped)
        .onAppear { buildFlatItems() }
    }

    // MARK: - Flat Row Views

    @ViewBuilder
    private func flatRow(item: FlatReorderItem) -> some View {
        switch item {
        case .portfolioHeader(let name):
            let color = colorForPortofolio(name)
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                Text(name.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                    .tracking(0.5)
                Spacer()
                Text("Grup Portofolio")
                    .font(.caption2)
                    .foregroundStyle(color.opacity(0.6))
            }
            .padding(.vertical, 4)

        case .tipeHeader(let tipe):
            HStack(spacing: 10) {
                Image(systemName: tipe.iconName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tipe.color)
                Text(tipe.displayName.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tipe.color)
                    .tracking(0.5)
                Spacer()
                Text("Tanpa Grup")
                    .font(.caption2)
                    .foregroundStyle(tipe.color.opacity(0.6))
            }
            .padding(.vertical, 4)

        case .linkedHeader:
            HStack(spacing: 10) {
                Image(systemName: "target")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.accent)
                Text("TARGET INVESTASI")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.accent)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.vertical, 4)

        case .aset(let id):
            if let aset = allAset.first(where: { $0.id == id }) {
                reorderRow(aset: aset, showTargetLabel: aset.linkedTarget != nil)
            }
        }
    }

    private func flatRowBackground(item: FlatReorderItem) -> Color {
        switch item {
        case .portfolioHeader(let name): return colorForPortofolio(name).opacity(0.08)
        case .tipeHeader(let tipe):      return tipe.color.opacity(0.04)
        case .linkedHeader:              return theme.accent.opacity(0.05)
        case .aset(let id):
            if let aset = allAset.first(where: { $0.id == id }) {
                if let porto = aset.portofolio, !porto.isEmpty {
                    return colorForPortofolio(porto).opacity(0.03)
                }
            }
            return theme.bgCard
        }
    }

    // MARK: - Build Flat Items

    func buildFlatItems() {
        var items: [FlatReorderItem] = []

        for group in portofolioGroups {
            items.append(.portfolioHeader(group.nama))
            for aset in group.items {
                items.append(.aset(aset.id))
            }
        }

        for tipe in TipeAset.allCases {
            let group = noPortofolioAset.filter { $0.tipe == tipe }
            if !group.isEmpty {
                items.append(.tipeHeader(tipe))
                for aset in group {
                    items.append(.aset(aset.id))
                }
            }
        }

        if !linkedAset.isEmpty {
            items.append(.linkedHeader)
            for aset in linkedAset {
                items.append(.aset(aset.id))
            }
        }

        flatItems = items
    }

    // MARK: - Apply Flat Move (cross-group reassignment)

    func applyFlatMove(from: IndexSet, to: Int) {
        guard let sourceIdx = from.first else { return }

        // Jangan izinkan memindahkan header
        guard !flatItems[sourceIdx].isHeader else { return }

        flatItems.move(fromOffsets: from, toOffset: to)

        // Scan ulang flat list — tentukan portofolio baru berdasarkan header di atasnya
        var currentPortfolio: String? = nil
        var isLinkedSection = false
        var urutan = 0

        for item in flatItems {
            switch item {
            case .portfolioHeader(let name):
                currentPortfolio = name
                isLinkedSection = false
                urutan = 0
            case .tipeHeader:
                currentPortfolio = nil
                isLinkedSection = false
                urutan = 0
            case .linkedHeader:
                isLinkedSection = true
                currentPortfolio = nil
                urutan = 0
            case .aset(let id):
                // Linked aset tidak boleh pindah portofolio via drag
                guard !isLinkedSection else { continue }
                if let aset = allAset.first(where: { $0.id == id }) {
                    aset.portofolio = currentPortfolio
                    aset.urutan = urutan
                    urutan += 1
                }
            }
        }

        ensurePortofolioConfigs()
        try? modelContext.save()
    }

    // MARK: - Reorder Row

    @ViewBuilder
    func reorderRow(aset: Aset, showTargetLabel: Bool = false) -> some View {
        HStack(spacing: 12) {
            asetIconView(aset: aset, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(aset.nama)
                    .foregroundStyle(theme.textPrimary)
                    .font(.subheadline)
                if showTargetLabel, let targetNama = aset.linkedTarget?.nama {
                    HStack(spacing: 3) {
                        Image(systemName: "target").font(.system(size: 9))
                        Text(targetNama).font(.caption2)
                    }
                    .foregroundStyle(theme.accent.opacity(0.7))
                } else if let porto = aset.portofolio, !porto.isEmpty {
                    Text(porto).font(.caption2).foregroundStyle(colorForPortofolio(porto).opacity(0.8))
                } else {
                    Text(aset.tipe.displayName).font(.caption2).foregroundStyle(theme.textSecondary)
                }
            }
            Spacer()
            if let kode = aset.kode, !kode.isEmpty {
                Text(kode.uppercased()).font(.caption2).foregroundStyle(theme.textSecondary)
            }
        }
    }
}

// MARK: - Portfolio Stat

private struct PortfolioStat: View {
    let label: String
    let value: String
    var labelColor: Color = .white.opacity(0.5)
    var valueColor: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(labelColor)
                .tracking(0.5)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Portofolio Section

private struct PortofolioSection: View {
    let nama: String
    let items: [Aset]
    let color: Color
    let onTap: (Aset) -> Void
    let onEdit: () -> Void
    @Environment(\.appTheme) private var theme

    private var totalNilai: Decimal { items.reduce(0) { $0 + $1.nilaiEfektif } }
    private var totalModal: Decimal { items.reduce(0) { $0 + $1.modal } }
    private var pnl: Decimal { totalNilai - totalModal }
    private var returnPct: Double {
        guard totalModal > 0 else { return 0 }
        return Double(truncating: (pnl / totalModal * 100) as NSDecimalNumber)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                    Text(nama.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.textPrimary.opacity(0.8))
                        .tracking(0.6)
                    Text("\(items.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(color.opacity(0.15))
                        .clipShape(Capsule())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(totalNilai.shortFormatted)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.textPrimary)
                    HStack(spacing: 3) {
                        Image(systemName: pnl >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 8, weight: .bold))
                        Text("\(pnl >= 0 ? "+" : "")\(pnl.shortFormatted)")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(pnl >= 0 ? theme.pemasukan : theme.pengeluaran)
                }
                Button { onEdit() } label: {
                    Image(systemName: "pencil")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color.opacity(0.7))
                        .padding(7)
                        .background(color.opacity(0.12))
                        .clipShape(Circle())
                }
                .padding(.leading, 8)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(color.opacity(0.05))

            // Rows (dengan tipe indicator)
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, aset in
                if idx > 0 {
                    Divider().background(theme.separator).padding(.leading, 56)
                }
                PortofolioAsetRow(aset: aset)
                    .onTapGesture { onTap(aset) }
            }
        }
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct PortofolioAsetRow: View {
    let aset: Aset
    @Environment(\.appTheme) private var theme
    var body: some View {
        HStack(spacing: 12) {
            asetIconView(aset: aset, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(aset.nama)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary).lineLimit(1)
                HStack(spacing: 4) {
                    Text(aset.tipe.displayName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(aset.tipe.color)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(aset.tipe.color.opacity(0.12))
                        .clipShape(Capsule())
                    if let jenis = aset.jenisReksadana, !jenis.isEmpty {
                        Text(jenis)
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                    } else if let kode = aset.kode, !kode.isEmpty {
                        Text(kode.uppercased())
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            Spacer()
            asetValueColumn(aset)
            Image(systemName: "chevron.right")
                .font(.caption).foregroundStyle(theme.textPrimary.opacity(0.2))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Shared value column (foreign currency aware)

private struct AsetValueColumn: View {
    let aset: Aset
    @Environment(\.appTheme) private var theme

    var body: some View {
        let pnlColor: Color = aset.pnl >= 0 ? theme.pemasukan : theme.pengeluaran
        let arrow = aset.pnl >= 0 ? "arrow.up.right" : "arrow.down.right"

        return VStack(alignment: .trailing, spacing: 3) {
            if let foreign = aset.nilaiAsingDisplay {
                // Primary: USD/SGD
                Text(foreign)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary).lineLimit(1)
                // Secondary: IDR
                Text(aset.nilaiEfektif.idrDecimalFormatted)
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary).lineLimit(1)
            } else {
                Text(aset.nilaiEfektif.idrDecimalFormatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary).lineLimit(1)
            }

            // P&L — sahamAS tampil dua baris: USD + IDR
            if aset.tipe == .sahamAS, let pnlUSD = aset.pnlAsingDisplay {
                // Baris 1: USD P&L
                HStack(spacing: 3) {
                    Image(systemName: arrow).font(.system(size: 9, weight: .bold))
                    Text(pnlUSD).font(.caption2.weight(.semibold))
                }
                .foregroundStyle(pnlColor)
                // Baris 2: IDR P&L
                Text("\(aset.pnl >= 0 ? "+" : "")\(aset.pnl.shortFormatted)")
                    .font(.caption2)
                    .foregroundStyle(pnlColor.opacity(0.7))
            } else {
                HStack(spacing: 3) {
                    Image(systemName: arrow).font(.system(size: 9, weight: .bold))
                    Text("\(aset.pnl >= 0 ? "+" : "")\(aset.pnl.shortFormatted)")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(pnlColor)
            }
        }
    }
}

private func asetValueColumn(_ aset: Aset) -> some View {
    AsetValueColumn(aset: aset)
}

// MARK: - Aset Section

private struct AsetSection: View {
    let tipe: TipeAset
    let items: [Aset]
    let onTap: (Aset) -> Void
    @Environment(\.appTheme) private var theme

    var sectionPnl: Decimal { items.reduce(0) { $0 + $1.pnl } }

    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: tipe.iconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tipe.color)
                    Text(tipe.displayName.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.textPrimary.opacity(0.7))
                        .tracking(0.8)
                    Text("\(items.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(tipe.color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(tipe.color.opacity(0.15))
                        .clipShape(Capsule())
                }
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: sectionPnl >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(sectionPnl >= 0 ? "+" : "")\(sectionPnl.shortFormatted)")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(sectionPnl >= 0 ? theme.pemasukan : theme.pengeluaran)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(theme.separator.opacity(0.5))

            // Rows
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, aset in
                if idx > 0 {
                    Divider().background(theme.separator).padding(.leading, 56)
                }
                AsetRow(aset: aset)
                    .onTapGesture { onTap(aset) }
            }
        }
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Target Aset Section

private struct TargetAsetSection: View {
    let items: [Aset]
    let onTap: (Aset) -> Void
    @Environment(\.appTheme) private var theme

    var totalNilai: Decimal { items.reduce(0) { $0 + $1.nilaiEfektif } }
    var totalPnl: Decimal { items.reduce(0) { $0 + $1.pnl } }

    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.accent)
                    Text("TARGET INVESTASI")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.textPrimary.opacity(0.7))
                        .tracking(0.8)
                    Text("\(items.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(theme.accent.opacity(0.15))
                        .clipShape(Capsule())
                }
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: totalPnl >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(totalPnl >= 0 ? "+" : "")\(totalPnl.shortFormatted)")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(totalPnl >= 0 ? theme.pemasukan : theme.pengeluaran)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(theme.accent.opacity(0.04))

            // Rows
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, aset in
                if idx > 0 {
                    Divider().background(theme.separator).padding(.leading, 56)
                }
                TargetAsetRow(aset: aset)
                    .onTapGesture { onTap(aset) }
            }
        }
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.accent.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Target Aset Row

private struct TargetAsetRow: View {
    let aset: Aset
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            asetIconView(aset: aset, size: 40)

            // Name + linked target
            VStack(alignment: .leading, spacing: 3) {
                Text(aset.nama)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                if let targetNama = aset.linkedTarget?.nama {
                    HStack(spacing: 3) {
                        Image(systemName: "target")
                            .font(.system(size: 9))
                        Text(targetNama)
                            .font(.caption2)
                    }
                    .foregroundStyle(theme.accent.opacity(0.8))
                } else {
                    Text(aset.tipe.displayName)
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                }
            }

            Spacer()
            asetValueColumn(aset)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(theme.textPrimary.opacity(0.2))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Shared icon helper

private func asetIconView(aset: Aset, size: CGFloat) -> some View {
    // Priority: logoData custom → pocket logo (deposito) → default icon
    let imageData: Data? = aset.logoData
        ?? (aset.tipe == .deposito ? aset.pocketSumber?.logo : nil)

    return Group {
        if let data = imageData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(aset.tipe.color.opacity(0.15))
                    .frame(width: size, height: size)
                Image(systemName: aset.tipe.iconName)
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(aset.tipe.color)
            }
        }
    }
}

// MARK: - Aset Row

private struct AsetRow: View {
    let aset: Aset
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            asetIconView(aset: aset, size: 40)

            // Name + code
            VStack(alignment: .leading, spacing: 3) {
                Text(aset.nama)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                if let kode = aset.kode, !kode.isEmpty {
                    Text(kode.uppercased())
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                } else {
                    Text(aset.tipe.displayName)
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                }
            }

            Spacer()
            asetValueColumn(aset)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(theme.textPrimary.opacity(0.2))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Add Grup Sheet

private struct AddGrupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    let onSave: (String, String) -> Void

    @State private var nama = ""
    @State private var warna = "#A78BFA"

    private let warnaOptions: [(String, String)] = [
        ("Ungu", "#A78BFA"), ("Biru", "#3B82F6"), ("Hijau", "#22C55E"),
        ("Kuning", "#EAB308"), ("Oranye", "#F97316"), ("Merah", "#EF4444"),
        ("Pink", "#EC4899"), ("Cyan", "#06B6D4"), ("Abu", "#6B7280"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bgApp.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Preview
                        HStack(spacing: 10) {
                            Circle().fill(Color(hex: warna)).frame(width: 12, height: 12)
                            Text(nama.isEmpty ? "Nama Grup" : nama)
                                .font(.headline)
                                .foregroundStyle(nama.isEmpty ? theme.textSecondary : theme.textPrimary)
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: warna).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: warna).opacity(0.3), lineWidth: 1))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("NAMA GRUP").font(.caption.weight(.semibold)).foregroundStyle(theme.textSecondary).tracking(0.5)
                            TextField("Contoh: Dana Pensiun, Growth...", text: $nama)
                                .foregroundStyle(theme.textPrimary).padding(12)
                                .background(theme.bgCard)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder, lineWidth: 1))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("WARNA").font(.caption.weight(.semibold)).foregroundStyle(theme.textSecondary).tracking(0.5)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                                ForEach(warnaOptions, id: \.0) { label, hex in
                                    Button { warna = hex } label: {
                                        HStack(spacing: 8) {
                                            Circle().fill(Color(hex: hex)).frame(width: 14, height: 14)
                                            Text(label).font(.caption.weight(.medium))
                                                .foregroundStyle(warna == hex ? theme.textOnColor : theme.textPrimary)
                                        }
                                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                                        .background(warna == hex ? Color(hex: hex) : theme.bgCard)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder, lineWidth: warna == hex ? 0 : 1))
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Buat Grup Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.bgApp, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }.foregroundStyle(theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") {
                        let trimmed = nama.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed, warna)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(!nama.trimmingCharacters(in: .whitespaces).isEmpty ? Color(hex: "#A78BFA") : theme.textSecondary)
                    .disabled(nama.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Performa Row

private struct PerformaRow: View {
    let rank: Int
    let aset: Aset
    let theme: AppTheme

    private var returnPct: Double { aset.returnPersen }
    private var pnl: Decimal { aset.pnl }
    private var isPositive: Bool { pnl >= 0 }

    private var rankColor: Color {
        switch rank {
        case 1: return Color(hex: "#F59E0B")
        case 2: return Color(hex: "#9CA3AF")
        case 3: return Color(hex: "#CD7C3B")
        default: return theme.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(rank <= 3 ? rankColor : theme.textSecondary)
                .frame(width: 24, alignment: .center)

            ZStack {
                Circle()
                    .fill(aset.tipe.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                if let data = aset.logoData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    Image(systemName: aset.tipe.iconName)
                        .font(.system(size: 13))
                        .foregroundStyle(aset.tipe.color)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(aset.kode ?? aset.nama)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Text(aset.tipe.displayName)
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(returnPct.percentFormatted)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isPositive ? theme.pemasukan : theme.pengeluaran)
                Text("\(isPositive ? "+" : "")\(pnl.shortFormatted)")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Performa All Sheet

private struct PerformaAllSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    let aset: [Aset]

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bgApp.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(aset.enumerated()), id: \.element.id) { idx, a in
                            PerformaRow(rank: idx + 1, aset: a, theme: theme)
                            if idx < aset.count - 1 {
                                Divider().background(theme.separator).padding(.leading, 56)
                            }
                        }
                    }
                    .background(theme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Semua Performa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.bgApp, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
    }
}
