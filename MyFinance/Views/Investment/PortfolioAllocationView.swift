import SwiftUI
import Charts

struct PortfolioAllocationView: View {
    let holdings: [InvestmentHolding]
    let lots: [StockLot]
    let prices: [StockPrice]

    @State private var mode: PortfolioViewMode = .subSector
    @State private var expandedSectors: Set<String> = []

    private struct StockAllocation: Identifiable {
        let id = UUID()
        let ticker: String
        let name: String
        let value: Double
        let subSector: String
        let percentage: Double
    }

    private struct SectorAllocation: Identifiable {
        let id = UUID()
        let name: String
        let value: Double
        let percentage: Double
        let stocks: [StockAllocation]
    }

    private var allocations: [StockAllocation] {
        let total = totalValue
        guard total > 0 else { return [] }
        return holdings.compactMap { holding in
            let holdingLots = lots.filter { $0.holdingID == holding.id }
            let shares = holdingLots.reduce(0.0) { $0 + $1.shares }
            let price = prices.first { $0.ticker == holding.ticker }?.currentPrice ?? 0
            let value = shares * price
            guard value > 0 else { return nil }
            return StockAllocation(
                ticker: holding.ticker.replacingOccurrences(of: ".JK", with: ""),
                name: holding.name, value: value, subSector: holding.subSector,
                percentage: (value / total) * 100
            )
        }.sorted { $0.value > $1.value }
    }

    private var sectorAllocations: [SectorAllocation] {
        let total = totalValue
        guard total > 0 else { return [] }
        var dict: [String: [StockAllocation]] = [:]
        for alloc in allocations {
            let sector = alloc.subSector.isEmpty ? "Lainnya" : alloc.subSector
            dict[sector, default: []].append(alloc)
        }
        return dict.map { sector, stocks in
            let sectorValue = stocks.reduce(0.0) { $0 + $1.value }
            return SectorAllocation(name: sector, value: sectorValue,
                                   percentage: (sectorValue / total) * 100, stocks: stocks)
        }.sorted { $0.value > $1.value }
    }

    private var totalValue: Double {
        holdings.reduce(0.0) { total, holding in
            let holdingLots = lots.filter { $0.holdingID == holding.id }
            let shares = holdingLots.reduce(0.0) { $0 + $1.shares }
            let price = prices.first { $0.ticker == holding.ticker }?.currentPrice ?? 0
            return total + shares * price
        }
    }

    private let chartColors: [Color] = [
        .blue, .green, .orange, .purple, .red, .cyan, .yellow, .mint, .pink, .indigo
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Mode toggle
            Picker("Mode", selection: $mode) {
                ForEach(PortfolioViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if totalValue == 0 {
                Text("Belum ada data harga tersedia")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                // Donut chart
                let chartData = mode == .stocks
                    ? allocations.map { ($0.ticker, $0.value, $0.percentage) }
                    : sectorAllocations.map { ($0.name, $0.value, $0.percentage) }

                ZStack {
                    Chart {
                        ForEach(Array(chartData.enumerated()), id: \.offset) { idx, item in
                            SectorMark(
                                angle: .value("Value", item.1),
                                innerRadius: .ratio(0.55),
                                angularInset: 2
                            )
                            .foregroundStyle(chartColors[idx % chartColors.count])
                            .cornerRadius(4)
                        }
                    }
                    .frame(height: 220)

                    VStack(spacing: 2) {
                        Text(totalValue.idrFormatted)
                            .font(.headline.bold())
                        Text(mode == .stocks ? "\(allocations.count) Saham" : "\(sectorAllocations.count) Sub-Sektor")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                // List
                if mode == .stocks {
                    stockList
                } else {
                    sectorList
                }
            }
        }
    }

    @ViewBuilder
    private var stockList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(allocations.enumerated()), id: \.element.id) { idx, alloc in
                HStack(spacing: 12) {
                    Circle()
                        .fill(chartColors[idx % chartColors.count])
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(alloc.ticker)
                            .font(.subheadline.bold())
                        Text(alloc.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(alloc.value.idrFormatted)
                            .font(.subheadline.bold())
                        Text(String(format: "%.2f%%", alloc.percentage))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                if idx < allocations.count - 1 {
                    Divider().padding(.leading, 36)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    @ViewBuilder
    private var sectorList: some View {
        LazyVStack(spacing: 8) {
            ForEach(Array(sectorAllocations.enumerated()), id: \.element.id) { idx, sector in
                VStack(spacing: 0) {
                    // Sector header
                    Button {
                        if expandedSectors.contains(sector.name) {
                            expandedSectors.remove(sector.name)
                        } else {
                            expandedSectors.insert(sector.name)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(chartColors[idx % chartColors.count])
                                .frame(width: 12, height: 12)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(sector.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                ProgressView(value: sector.percentage / 100)
                                    .tint(chartColors[idx % chartColors.count])
                                    .frame(width: 100)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(sector.value.idrFormatted)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text(String(format: "%.2f%%", sector.percentage))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Image(systemName: expandedSectors.contains(sector.name) ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }

                    // Expanded stocks
                    if expandedSectors.contains(sector.name) {
                        Divider().padding(.leading)
                        ForEach(sector.stocks) { stock in
                            HStack {
                                Text(stock.ticker)
                                    .font(.subheadline)
                                    .padding(.leading, 24)
                                Spacer()
                                Text(stock.value.idrFormatted)
                                    .font(.subheadline)
                                Text(String(format: "%.2f%%", stock.percentage))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 50, alignment: .trailing)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            Divider().padding(.leading, 24)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal)
    }
}
