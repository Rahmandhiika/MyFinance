import SwiftUI
import SwiftData

struct AsetListView: View {
    @Query(sort: [SortDescriptor(\Aset.urutan), SortDescriptor(\Aset.createdAt)]) var allAset: [Aset]

    private let priceService = AsetPriceService.shared
    @State private var selectedAset: Aset? = nil
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

    // MARK: - Grouped (hanya aset bebas)

    private var asetBySaham:     [Aset] { freeAset.filter { $0.tipe == .saham } }
    private var asetBySahamAS:   [Aset] { freeAset.filter { $0.tipe == .sahamAS } }
    private var asetByReksadana: [Aset] { freeAset.filter { $0.tipe == .reksadana } }
    private var asetByValas:     [Aset] { freeAset.filter { $0.tipe == .valas } }
    private var asetByEmas:      [Aset] { freeAset.filter { $0.tipe == .emas } }
    private var asetByDeposito:  [Aset] { freeAset.filter { $0.tipe == .deposito } }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "#0D0D0D").ignoresSafeArea()

            if allAset.isEmpty {
                emptyState
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
            if priceService.isLoading {
                loadingOverlay
            }
        }
        .navigationTitle("Aset")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                refreshButton
            }
            ToolbarItem(placement: .topBarTrailing) {
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
                            showReorder = true
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
        .task {
            if !allAset.isEmpty {
                await priceService.refreshAll(allAset)
            }
        }
        .sheet(item: $selectedAset) { aset in
            AsetDetailSheet(aset: aset)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAdd) {
            AddEditAsetView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showReorder) {
            AsetReorderSheet()
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
                    Text("\(aset.pnl >= 0 ? "+" : "")\(aset.pnl.shortFormatted) (\(aset.returnPersen.percentFormatted))")
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
                    Text("\(aset.pnl >= 0 ? "+" : "")\(aset.pnl.shortFormatted) (\(aset.returnPersen.percentFormatted))")
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
