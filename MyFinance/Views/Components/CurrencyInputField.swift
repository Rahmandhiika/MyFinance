import SwiftUI

struct CurrencyInputField: View {
    let label: String
    @Binding var amount: Double
    var currency: AppCurrency = .IDR

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text(currency.symbol)
                    .foregroundStyle(.secondary)
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .onChange(of: text) { oldValue, newValue in
                        let digits = newValue.filter { $0.isNumber || $0 == "." }
                        if digits != newValue {
                            text = digits
                        }
                        amount = Double(digits) ?? 0
                    }
                    .onChange(of: amount) { oldValue, newValue in
                        if !focused {
                            text = newValue > 0 ? formatNumber(newValue) : ""
                        }
                    }
                    .onAppear {
                        text = amount > 0 ? formatNumber(amount) : ""
                    }
                    .onChange(of: focused) { _, isFocused in
                        if !isFocused && amount > 0 {
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
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(value)
    }
    
    private func formatWithSeparator(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? ""
    }
}


