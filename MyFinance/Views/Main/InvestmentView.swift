import SwiftUI
import SwiftData

struct InvestmentViewMain: View {
    @Environment(\.modelContext) private var context
    @Query private var holdings: [InvestmentHolding]
    @Query private var lots: [StockLot]
    @Query private var prices: [StockPrice]
    @Query private var allAccounts: [Account]

    private var investmentAccounts: [Account] {
        allAccounts.filter { $0.type == .investment && !$0.isArchived }
    }

    @State private var showAddHolding = false
    @State private var viewMode: InvestmentTab = .holdings

    enum InvestmentTab: String, CaseIterable {
        case holdings = "Holdings"
        case allocation = "Alokasi"
    }

    private var totalValue: Double {
        holdings.reduce(0.0) { total, holding in
            let holdingLots = lots.filter { $0.holdingID == holding.id }
            let shares = holdingLots.reduce(0.0) { $0 + $1.shares }
            let price = prices.first(where: { $0.ticker == holding.ticker })?.currentPrice ?? 0
            return total + shares * price
        }
    }

    private var totalCost: Double {
        lots.reduce(0.0) { $0 + $1.totalCost }
    }

    private var totalPL: Double { totalValue - totalCost }
    private var totalPLPercent: Double { totalCost > 0 ? (totalPL / totalCost) * 100 : 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    portfolioHeroCard
                    performerCards
                    tabSelector

                    if viewMode == .holdings {
                        holdingsSection
                    } else {
                        PortfolioAllocationView(holdings: holdings, lots: lots, prices: prices)
                    }

                    Spacer(minLength: 80)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Investasi")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddHolding = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .sheet(isPresented: $showAddHolding) {
                AddEditHoldingView()
            }
        }
    }

    // MARK: - Hero Card

    private var portfolioHeroCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "briefcase.fill")
                        .font(.caption)
                    Text("TOTAL PORTFOLIO")
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                }
                .foregroundStyle(.white.opacity(0.7))

                Text(totalValue.idrFormatted)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Image(systemName: totalPL >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.weight(.bold))
                    Text(totalPL.shortFormatted)
                    Text("(\(totalPLPercent.percentFormatted))")
                        .font(.caption.weight(.medium))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(totalPL >= 0 ? Color(hex: "#34D399") : Color(hex: "#F87171"))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(.white.opacity(0.15))
                .clipShape(Capsule())
            }
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: "#0f0c29"), Color(hex: "#302b63"), Color(hex: "#24243e")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Circle()
                        .fill(.white.opacity(0.05))
                        .frame(width: 200)
                        .offset(x: 120, y: -60)
                    Circle()
                        .fill(.white.opacity(0.03))
                        .frame(width: 160)
                        .offset(x: -100, y: 50)
                }
                .clipped()
            )

            HStack(spacing: 0) {
                portfolioStat(icon: "banknote", label: "Modal", value: totalCost.shortFormatted)

                Rectangle().fill(Color(.separator)).frame(width: 0.5, height: 32)

                portfolioStat(icon: "chart.bar.fill", label: "Holdings", value: "\(holdings.count)")

                Rectangle().fill(Color(.separator)).frame(width: 0.5, height: 32)

                portfolioStat(
                    icon: "arrow.triangle.2.circlepath",
                    label: "Return",
                    value: totalPLPercent.percentFormatted,
                    valueColor: totalPL >= 0 ? .green : .red
                )
            }
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        .padding(.horizontal)
    }

    private func portfolioStat(icon: String, label: String, value: String, valueColor: Color = .primary) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Performer Cards

    private var performerCards: some View {
        HStack(spacing: 12) {
            performerCard(
                title: "Top Performer",
                icon: "flame.fill",
                value: bestPerformerName,
                iconColor: .green
            )
            performerCard(
                title: "Underperform",
                icon: "arrow.down.right.circle.fill",
                value: worstPerformerName,
                iconColor: .red
            )
        }
        .padding(.horizontal)
    }

    private func performerCard(title: String, icon: String, value: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(iconColor)
                    .frame(width: 28, height: 28)
                    .background(iconColor.opacity(0.15))
                    .clipShape(Circle())
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var bestPerformerName: String {
        let sorted = holdings.compactMap { holding -> (String, Double)? in
            let holdingLots = lots.filter { $0.holdingID == holding.id }
            let cost = holdingLots.reduce(0.0) { $0 + $1.totalCost }
            guard cost > 0 else { return nil }
            let shares = holdingLots.reduce(0.0) { $0 + $1.shares }
            let price = prices.first(where: { $0.ticker == holding.ticker })?.currentPrice ?? 0
            let value = shares * price
            let pl = ((value - cost) / cost) * 100
            return (holding.ticker.replacingOccurrences(of: ".JK", with: ""), pl)
        }.sorted { $0.1 > $1.1 }

        guard let best = sorted.first, best.1 > 0 else { return "\u{2014}" }
        return "\(best.0) +\(String(format: "%.1f", best.1))%"
    }

    private var worstPerformerName: String {
        let sorted = holdings.compactMap { holding -> (String, Double)? in
            let holdingLots = lots.filter { $0.holdingID == holding.id }
            let cost = holdingLots.reduce(0.0) { $0 + $1.totalCost }
            guard cost > 0 else { return nil }
            let shares = holdingLots.reduce(0.0) { $0 + $1.shares }
            let price = prices.first(where: { $0.ticker == holding.ticker })?.currentPrice ?? 0
            let value = shares * price
            let pl = ((value - cost) / cost) * 100
            return (holding.ticker.replacingOccurrences(of: ".JK", with: ""), pl)
        }.sorted { $0.1 < $1.1 }

        guard let worst = sorted.first, worst.1 < 0 else { return "\u{2014}" }
        return "\(worst.0) \(String(format: "%.1f", worst.1))%"
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 4) {
            ForEach(InvestmentTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewMode = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(viewMode == tab ? .white : .secondary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(viewMode == tab ? Color.blue : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(Capsule())
    }

    // MARK: - Holdings Section

    @ViewBuilder
    private var holdingsSection: some View {
        if holdings.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 10) {
                ForEach(holdings) { holding in
                    NavigationLink(destination: HoldingDetailView(holding: holding)) {
                        ModernHoldingRow(
                            holding: holding,
                            lots: lots.filter { $0.holdingID == holding.id },
                            price: prices.first { $0.ticker == holding.ticker }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: 140, height: 140)
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue.gradient)
            }

            VStack(spacing: 8) {
                Text("Belum Ada Holding")
                    .font(.title3.weight(.bold))
                Text("Tambahkan saham atau aset investasi\npertama Anda untuk mulai tracking")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showAddHolding = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                    Text("Tambah Holding")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#667eea"), Color(hex: "#764ba2")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#667eea").opacity(0.4), radius: 8, y: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Holding Row

struct ModernHoldingRow: View {
    let holding: InvestmentHolding
    let lots: [StockLot]
    let price: StockPrice?

    private var totalShares: Double { lots.reduce(0) { $0 + $1.shares } }
    private var currentPrice: Double { price?.currentPrice ?? 0 }
    private var currentValue: Double { totalShares * currentPrice }
    private var totalCost: Double { lots.reduce(0) { $0 + $1.totalCost } }
    private var pl: Double { currentValue - totalCost }
    private var plPercent: Double { totalCost > 0 ? (pl / totalCost) * 100 : 0 }
    private var hasPrice: Bool { currentPrice > 0 }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(assetColor.gradient)
                .frame(width: 4)
                .padding(.vertical, 8)

            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(assetColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: assetIcon)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(assetColor)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(holding.ticker.replacingOccurrences(of: ".JK", with: ""))
                            .font(.headline.weight(.bold))
                        if !hasPrice {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }

                    Text(holding.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if !holding.subSector.isEmpty {
                        Text(holding.subSector)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(assetColor.opacity(0.08))
                            .foregroundStyle(assetColor)
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                // Value
                VStack(alignment: .trailing, spacing: 4) {
                    if hasPrice {
                        Text(currentValue.shortFormatted)
                            .font(.headline.weight(.bold))

                        HStack(spacing: 3) {
                            Image(systemName: pl >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 9, weight: .bold))
                            Text(plPercent.percentFormatted)
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(pl >= 0 ? .green : .red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((pl >= 0 ? Color.green : Color.red).opacity(0.1))
                        .clipShape(Capsule())
                    } else {
                        Text("Belum ada harga")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(totalCost.shortFormatted)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var assetColor: Color {
        switch holding.assetType {
        case .stock: return .blue
        case .etf: return .purple
        case .commodity: return .orange
        case .custom: return .gray
        }
    }

    private var assetIcon: String {
        switch holding.assetType {
        case .stock: return "chart.bar.fill"
        case .etf: return "chart.pie.fill"
        case .commodity: return "cube.fill"
        case .custom: return "star.fill"
        }
    }
}
