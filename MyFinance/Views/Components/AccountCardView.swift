import SwiftUI

struct AccountCardView: View {
    let account: Account

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: account.icon)
                    .foregroundStyle(.white)
                    .font(.title3)
                Spacer()
                if account.isDueSoon {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.yellow)
                }
            }

            Spacer()

            Text(account.name)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))

            if account.type == .credit {
                Text(account.usedLimit.idrFormatted)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Text("Limit: \(account.availableLimit.idrFormatted)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text(account.balance.formatted(currency: account.currency))
                    .font(.headline.bold())
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .frame(width: 160, height: 100)
        .background(Color(hex: account.colorHex))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
