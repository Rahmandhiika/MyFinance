import SwiftUI
import SwiftData

struct HoldingDetailView: View {
    @Environment(\.modelContext) private var context
    @Query private var lots: [StockLot]
    @Query private var prices: [StockPrice]

    let holding: InvestmentHolding

    @State private var showAddLot = false
    @State private var showUpdatePrice = false
    @State private var newPriceText = ""

    private var holdingLots: [StockLot] { lots.filter { $0.holdingID == holding.id } }
    private var price: StockPrice? { prices.first { $0.ticker == holding.ticker } }

    private var totalShares: Double { holdingLots.reduce(0) { $0 + $1.shares } }
    private var avgBuyPrice: Double {
        let cost = holdingLots.reduce(0.0) { $0 + $1.shares * $1.buyPrice }
        return totalShares > 0 ? cost / totalShares : 0
    }
    private var currentValue: Double { totalShares * (price?.currentPrice ?? 0) }
    private var totalCost: Double { holdingLots.reduce(0) { $0 + $1.totalCost } }
    private var pl: Double { currentValue - totalCost }
    private var plPercent: Double { totalCost > 0 ? (pl / totalCost) * 100 : 0 }

    var body: some View {
        List {
            // Current Price Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Harga per Unit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(price?.currentPrice.idrFormatted ?? "Belum diatur")
                            .font(.title2.bold())
                        if let p = price {
                            Text("Update: \(p.lastUpdated.formatted(.dateTime.day().month().year().hour().minute()))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    Button {
                        newPriceText = price != nil ? String(format: "%.0f", price!.currentPrice) : ""
                        showUpdatePrice = true
                    } label: {
                        Label("Perbarui", systemImage: "pencil.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
            } header: {
                Text("Harga Saat Ini")
            } footer: {
                Text("Perbarui harga secara manual untuk menghitung nilai portfolio")
                    .font(.caption2)
            }

            Section {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(holding.ticker.replacingOccurrences(of: ".JK", with: ""))
                                .font(.title.bold())
                            Text(holding.name)
                                .foregroundStyle(.secondary)
                            if !holding.subSector.isEmpty {
                                Text(holding.subSector)
                                    .font(.caption)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                        Spacer()
                        if let p = price {
                            VStack(alignment: .trailing) {
                                Text(p.changePercent.percentFormatted)
                                    .font(.caption.bold())
                                    .foregroundStyle(p.changePercent >= 0 ? .green : .red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background((p.changePercent >= 0 ? Color.green : Color.red).opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Divider()

                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                        statCell("Nilai Saat Ini", currentValue.idrFormatted)
                        statCell("Total Modal", totalCost.idrFormatted)
                        statCell("Floating P&L", pl.idrFormatted, color: pl >= 0 ? .green : .red)
                        statCell("Return", plPercent.percentFormatted, color: pl >= 0 ? .green : .red)
                        statCell("Total Lot", holding.assetType == .stock ? "\(Int(totalShares/100)) lot" : "\(totalShares) unit")
                        statCell("Avg. Beli", avgBuyPrice.idrFormatted)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Riwayat Pembelian (Lot)") {
                ForEach(holdingLots.sorted { $0.buyDate > $1.buyDate }) { lot in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lot.buyDate.formatted(.dateTime.day().month().year()))
                                .font(.subheadline)
                            Text(holding.assetType == .stock ? "\(Int(lot.shares/100)) lot @ \(lot.buyPrice.idrFormatted)" : "\(lot.shares) unit @ \(lot.buyPrice.idrFormatted)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(lot.totalCost.idrFormatted)
                                .font(.subheadline.bold())
                            if lot.fee > 0 {
                                Text("fee: \(lot.fee.idrFormatted)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { idx in
                    let sorted = holdingLots.sorted { $0.buyDate > $1.buyDate }
                    for i in idx { context.delete(sorted[i]) }
                    try? context.save()
                }

                Button("+ Tambah Lot") { showAddLot = true }
                    .foregroundStyle(.blue)
            }
        }
        .navigationTitle(holding.ticker.replacingOccurrences(of: ".JK", with: ""))
        .sheet(isPresented: $showAddLot) {
            AddLotView(holdingID: holding.id)
        }
        .alert("Perbarui Harga", isPresented: $showUpdatePrice) {
            TextField("Harga per unit", text: $newPriceText)
                .keyboardType(.numberPad)
            Button("Simpan") { updatePrice() }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Masukkan harga terkini untuk \(holding.ticker.replacingOccurrences(of: ".JK", with: ""))")
        }
    }

    private func updatePrice() {
        guard let newPrice = Double(newPriceText), newPrice > 0 else { return }
        let prev = price?.currentPrice ?? newPrice
        let change = prev > 0 ? ((newPrice - prev) / prev) * 100 : 0

        if let existing = price {
            existing.currentPrice = newPrice
            existing.previousClose = prev
            existing.changePercent = change
            existing.lastUpdated = Date()
        } else {
            let sp = StockPrice(
                ticker: holding.ticker,
                currentPrice: newPrice,
                previousClose: prev,
                changePercent: change
            )
            context.insert(sp)
        }
        try? context.save()
    }

    private func statCell(_ label: String, _ value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold()).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
