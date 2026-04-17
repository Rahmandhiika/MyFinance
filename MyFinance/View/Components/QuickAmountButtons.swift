import SwiftUI

/// Tombol cepat untuk menambah nominal — hanya tampil di form ADD (bukan edit)
struct QuickAmountButtons: View {
    @Binding var nominal: Decimal

    private let accentColor = Color(hex: "#22C55E")

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                quickButton("10rb",  10_000)
                quickButton("50rb",  50_000)
            }
            HStack(spacing: 8) {
                quickButton("100rb", 100_000)
                quickButton("500rb", 500_000)
            }
            quickButton("1 juta", 1_000_000)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func quickButton(_ label: String, _ amount: Decimal) -> some View {
        Button {
            nominal += amount
        } label: {
            Text("+\(label)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(accentColor.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
