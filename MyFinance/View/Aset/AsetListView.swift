import SwiftUI
import SwiftData

struct AsetListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Aset.urutan), SortDescriptor(\Aset.createdAt)]) var allAset: [Aset]

    @Query(sort: \PortofolioConfig.urutan) private var allPortofolioConfigs: [PortofolioConfig]

    private let priceService = AsetPriceService.shared
    @State private var selectedAset: Aset? = nil
    @State private var editingPortofolioConfig: PortofolioConfig? = nil
    @State private var showAdd = false
    @State private var showReorder = false
    @State private var showAnalisa = false

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

    private var asetBySaham:     [Aset] { noPortofolioAset.filter { $0.tipe == .saham } }
    private var asetBySahamAS:   [Aset] { noPortofolioAset.filter { $0.tipe == .sahamAS } }
    private var asetByReksadana: [Aset] { noPortofolioAset.filter { $0.tipe == .reksadana } }
    private var asetByValas:     [Aset] { noPortofolioAset.filter { $0.tipe == .valas } }
    private var asetByEmas:      [Aset] { noPortofolioAset.filter { $0.tipe == .emas } }
    private var asetByDeposito:  [Aset] { noPortofolioAset.filter { $0.tipe == .deposito } }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "#0D0D0D").ignoresSafeArea()

            if allAset.isEmpty {
                emptyState
            } else if showReorder {
                reorderList
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        portfolioCard
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
                    Button("Selesai") {
                        withAnimation(.easeInOut(duration: 0.2)) { showReorder = false }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                } else {
                    HStack(spacing: 8) {
                        if !asetBySaham.isEmpty {
                            Button {
                                showAnalisa = true
                            } label: {
                                Image(systemName: "chart.xyaxis.line")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        if allAset.count > 1 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { showReorder = true }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.7))
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
        .onChange(of: allAset) { ensurePortofolioConfigs() }
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
        .sheet(isPresented: $showAdd) {
            AddEditAsetView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAnalisa) {
            AnalisaSahamView()
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
                .foregroundStyle(priceService.isLoading ? .white.opacity(0.3) : .white.opacity(0.7))
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
                            .foregroundStyle(.white.opacity(0.5))
                            .tracking(1)
                        Text("\(freeAset.count) ASET")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    Text(totalNilai.idrDecimalFormatted)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
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
                    .foregroundStyle(keuntungan >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((keuntungan >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444")).opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()
                .background(Color.white.opacity(0.08))

            // Stats row
            HStack {
                PortfolioStat(label: "TOTAL MODAL", value: totalModal.idrDecimalFormatted)
                Divider()
                    .background(Color.white.opacity(0.1))
                    .frame(height: 36)
                PortfolioStat(
                    label: "KEUNTUNGAN",
                    value: "\(keuntungan >= 0 ? "+" : "")\(keuntungan.idrDecimalFormatted)",
                    valueColor: keuntungan >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444")
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
                .foregroundStyle(.white.opacity(0.3))
                .padding(.bottom, 12)
            }
        }
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Aset Sections

    private var asetSections: some View {
        VStack(spacing: 16) {
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
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 80, height: 80)
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.3))
            }

            VStack(spacing: 8) {
                Text("Belum Ada Aset")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text("Catat investasi kamu — saham, reksadana,\nvalas, emas, atau deposito.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            Button {
                showAdd = true
            } label: {
                Label("Tambah Aset Pertama", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.white)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        VStack(spacing: 8) {
            ProgressView()
                .tint(.white)
            Text("Memperbarui harga...")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(20)
        .background(Color(hex: "#1A1A1A"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.4), radius: 20)
    }
}

// MARK: - Reorder List (inline)

extension AsetListView {
    var reorderList: some View {
        List {
            // Section 0: Reorder the groups themselves
            if !allPortofolioConfigs.isEmpty {
                Section {
                    ForEach(allPortofolioConfigs) { config in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color(hex: config.warna).opacity(0.15)).frame(width: 32, height: 32)
                                Image(systemName: "folder.fill").font(.system(size: 13)).foregroundStyle(Color(hex: config.warna))
                            }
                            Text(config.nama).foregroundStyle(.white).font(.subheadline)
                            Spacer()
                        }
                        .listRowBackground(Color(hex: config.warna).opacity(0.05))
                    }
                    .onMove { from, to in
                        var mutable = allPortofolioConfigs
                        mutable.move(fromOffsets: from, toOffset: to)
                        for (i, c) in mutable.enumerated() { c.urutan = i }
                        try? modelContext.save()
                    }
                } header: {
                    Text("URUTAN GRUP PORTOFOLIO")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(hex: "#A78BFA").opacity(0.7))
                }
            }

            // Portfolio groups
            ForEach(portofolioGroups, id: \.nama) { group in
                let groupItems = group.items
                let groupColor = colorForPortofolio(group.nama)
                Section {
                    ForEach(groupItems) { aset in
                        reorderRow(aset: aset)
                            .listRowBackground(groupColor.opacity(0.05))
                    }
                    .onMove { from, to in
                        var mutable = groupItems
                        mutable.move(fromOffsets: from, toOffset: to)
                        for (i, a) in mutable.enumerated() { a.urutan = i }
                        try? modelContext.save()
                    }
                } header: {
                    Label(group.nama.uppercased(), systemImage: "folder.fill")
                        .foregroundStyle(groupColor)
                        .font(.caption.weight(.bold))
                }
            }

            // Per-type sections (no portfolio)
            ForEach(TipeAset.allCases) { tipe in
                let group = noPortofolioAset.filter { $0.tipe == tipe }
                if !group.isEmpty {
                    Section {
                        ForEach(group) { aset in
                            reorderRow(aset: aset)
                                .listRowBackground(Color.white.opacity(0.05))
                        }
                        .onMove { from, to in
                            var mutable = group
                            mutable.move(fromOffsets: from, toOffset: to)
                            for (i, a) in mutable.enumerated() { a.urutan = i }
                            try? modelContext.save()
                        }
                    } header: {
                        Label(tipe.displayName.uppercased(), systemImage: tipe.iconName)
                            .foregroundStyle(tipe.color)
                            .font(.caption.weight(.bold))
                    }
                }
            }

            // Target investasi
            if !linkedAset.isEmpty {
                Section {
                    ForEach(linkedAset) { aset in
                        reorderRow(aset: aset, showTargetLabel: true)
                            .listRowBackground(Color(hex: "#22C55E").opacity(0.05))
                    }
                    .onMove { from, to in
                        var mutable = linkedAset
                        mutable.move(fromOffsets: from, toOffset: to)
                        for (i, a) in mutable.enumerated() { a.urutan = i }
                        try? modelContext.save()
                    }
                } header: {
                    Label("TARGET INVESTASI", systemImage: "target")
                        .foregroundStyle(Color(hex: "#22C55E"))
                        .font(.caption.weight(.bold))
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(Color(hex: "#0D0D0D"))
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    func reorderRow(aset: Aset, showTargetLabel: Bool = false) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(aset.tipe.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: aset.tipe.iconName)
                    .font(.system(size: 13))
                    .foregroundStyle(aset.tipe.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(aset.nama)
                    .foregroundStyle(.white)
                    .font(.subheadline)
                if showTargetLabel, let targetNama = aset.linkedTarget?.nama {
                    HStack(spacing: 3) {
                        Image(systemName: "target").font(.system(size: 9))
                        Text(targetNama).font(.caption2)
                    }
                    .foregroundStyle(Color(hex: "#22C55E").opacity(0.7))
                } else if let porto = aset.portofolio, !porto.isEmpty {
                    Text(porto).font(.caption2).foregroundStyle(colorForPortofolio(porto).opacity(0.8))
                }
            }
            Spacer()
            if let kode = aset.kode, !kode.isEmpty {
                Text(kode.uppercased()).font(.caption2).foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - Portfolio Stat

private struct PortfolioStat: View {
    let label: String
    let value: String
    var valueColor: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
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
                        .foregroundStyle(.white.opacity(0.8))
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
                        .foregroundStyle(.white)
                    HStack(spacing: 3) {
                        Image(systemName: pnl >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 8, weight: .bold))
                        Text("\(pnl >= 0 ? "+" : "")\(pnl.shortFormatted)")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(pnl >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444"))
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
                    Divider().background(Color.white.opacity(0.06)).padding(.leading, 56)
                }
                PortofolioAsetRow(aset: aset)
                    .onTapGesture { onTap(aset) }
            }
        }
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct PortofolioAsetRow: View {
    let aset: Aset
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(aset.tipe.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: aset.tipe.iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(aset.tipe.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(aset.nama)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white).lineLimit(1)
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
                            .foregroundStyle(.white.opacity(0.4))
                    } else if let kode = aset.kode, !kode.isEmpty {
                        Text(kode.uppercased())
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(aset.nilaiEfektif.idrDecimalFormatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white).lineLimit(1)
                HStack(spacing: 3) {
                    Image(systemName: aset.pnl >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(aset.pnl >= 0 ? "+" : "")\(aset.pnl.shortFormatted)")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(aset.pnl >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444"))
            }
            Image(systemName: "chevron.right")
                .font(.caption).foregroundStyle(.white.opacity(0.2))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Aset Section

private struct AsetSection: View {
    let tipe: TipeAset
    let items: [Aset]
    let onTap: (Aset) -> Void

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
                        .foregroundStyle(.white.opacity(0.7))
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
                .foregroundStyle(sectionPnl >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.03))

            // Rows
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, aset in
                if idx > 0 {
                    Divider().background(Color.white.opacity(0.06)).padding(.leading, 56)
                }
                AsetRow(aset: aset)
                    .onTapGesture { onTap(aset) }
            }
        }
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Target Aset Section

private struct TargetAsetSection: View {
    let items: [Aset]
    let onTap: (Aset) -> Void

    var totalNilai: Decimal { items.reduce(0) { $0 + $1.nilaiEfektif } }
    var totalPnl: Decimal { items.reduce(0) { $0 + $1.pnl } }

    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: "#22C55E"))
                    Text("TARGET INVESTASI")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(0.8)
                    Text("\(items.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color(hex: "#22C55E"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#22C55E").opacity(0.15))
                        .clipShape(Capsule())
                }
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: totalPnl >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(totalPnl >= 0 ? "+" : "")\(totalPnl.shortFormatted)")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(totalPnl >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "#22C55E").opacity(0.04))

            // Rows
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, aset in
                if idx > 0 {
                    Divider().background(Color.white.opacity(0.06)).padding(.leading, 56)
                }
                TargetAsetRow(aset: aset)
                    .onTapGesture { onTap(aset) }
            }
        }
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#22C55E").opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Target Aset Row

private struct TargetAsetRow: View {
    let aset: Aset

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(aset.tipe.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: aset.tipe.iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(aset.tipe.color)
            }

            // Name + linked target
            VStack(alignment: .leading, spacing: 3) {
                Text(aset.nama)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let targetNama = aset.linkedTarget?.nama {
                    HStack(spacing: 3) {
                        Image(systemName: "target")
                            .font(.system(size: 9))
                        Text(targetNama)
                            .font(.caption2)
                    }
                    .foregroundStyle(Color(hex: "#22C55E").opacity(0.8))
                } else {
                    Text(aset.tipe.displayName)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()

            // Value + P&L
            VStack(alignment: .trailing, spacing: 3) {
                Text(aset.nilaiEfektif.idrDecimalFormatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 3) {
                    Image(systemName: aset.pnl >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(aset.pnl >= 0 ? "+" : "")\(aset.pnl.shortFormatted)")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(aset.pnl >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444"))
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Aset Row

private struct AsetRow: View {
    let aset: Aset

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(aset.tipe.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: aset.tipe.iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(aset.tipe.color)
            }

            // Name + code
            VStack(alignment: .leading, spacing: 3) {
                Text(aset.nama)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let kode = aset.kode, !kode.isEmpty {
                    Text(kode.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                } else {
                    Text(aset.tipe.displayName)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()

            // Value + P&L
            VStack(alignment: .trailing, spacing: 3) {
                Text(aset.nilaiEfektif.idrDecimalFormatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 3) {
                    Image(systemName: aset.pnl >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(aset.pnl >= 0 ? "+" : "")\(aset.pnl.shortFormatted)")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(aset.pnl >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444"))
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
