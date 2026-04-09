import SwiftUI
import SwiftData

struct NetWorthCardView: View {
    let accounts: [Account]
    let holdings: [InvestmentHolding]
    let lots: [StockLot]
    let prices: [StockPrice]
    let usdToIDR: Double

    private var totalNetWorth: Double {
        let bankCash = accounts
            .filter { !$0.isArchived && $0.type != .investment && $0.type != .credit }
            .reduce(0.0) { sum, acc in
                sum + (acc.currency == .IDR ? acc.balance : acc.balance * usdToIDR)
            }

        let creditDebt = accounts
            .filter { !$0.isArchived && $0.type == .credit }
            .reduce(0.0) { $0 - $1.usedLimit }

        let investmentValue = portfolioTotalIDR

        return bankCash + creditDebt + investmentValue
    }

    private var portfolioTotalIDR: Double {
        holdings.reduce(0.0) { total, holding in
            let holdingLots = lots.filter { $0.holdingID == holding.id }
            let totalShares = holdingLots.reduce(0.0) { $0 + $1.shares }
            guard let price = prices.first(where: { $0.ticker == holding.ticker }) else { return total }
            return total + totalShares * price.currentPrice
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Net Worth")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))

            Text(totalNetWorth.idrFormatted)
                .font(.title.bold())
                .foregroundStyle(.white)

            HStack {
                Text("Portfolio")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                Text(portfolioTotalIDR.idrFormatted)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            LinearGradient(colors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e")],
                          startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
