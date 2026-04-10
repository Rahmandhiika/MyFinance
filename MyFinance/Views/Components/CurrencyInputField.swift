import SwiftUI

struct CurrencyInputField: View {
    let label: String
    @Binding var amount: Double

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Rp")
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                TextField("0", text: $text)
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .onChange(of: text) { _, newValue in
                        let digits = newValue.filter { $0.isNumber }
                        if digits != newValue {
                            text = digits
                        }
                        amount = Double(digits) ?? 0
                    }
                    .onChange(of: amount) { _, newValue in
                        if !focused {
                            text = newValue > 0 ? formatNumber(newValue) : ""
                        }
                    }
                    .onAppear {
                        text = amount > 0 ? formatNumber(amount) : ""
                    }
                    .onChange(of: focused) { _, isFocused in
                        if isFocused {
                            // Show raw number when editing
                            if amount > 0 {
                                text = String(Int(amount))
                            }
                        } else if amount > 0 {
                            text = formatNumber(amount)
                        }
                    }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if amount > 0 {
                Text(formatWithSeparator(amount))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formatNumber(_ value: Double) -> String {
        return String(Int(value))
    }

    private func formatWithSeparator(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.maximumFractionDigits = 0
        return "Rp " + (formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))")
    }
}
