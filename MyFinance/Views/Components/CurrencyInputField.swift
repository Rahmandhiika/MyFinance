import SwiftUI

// MARK: - Decimal-based (used in new views)

struct CurrencyInputField: View {
    @Binding var value: Decimal

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("0", text: $text)
            .keyboardType(.numberPad)
            .focused($focused)
            .padding(12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(.white)
            .onChange(of: text) { _, newValue in
                let digits = newValue.filter { $0.isNumber }
                if digits != newValue { text = digits }
                value = Decimal(string: digits) ?? 0
            }
            .onChange(of: value) { _, newValue in
                if !focused {
                    let intVal = NSDecimalNumber(decimal: newValue).intValue
                    text = intVal > 0 ? formatWithSeparator(intVal) : ""
                }
            }
            .onAppear {
                let intVal = NSDecimalNumber(decimal: value).intValue
                text = intVal > 0 ? formatWithSeparator(intVal) : ""
            }
            .onChange(of: focused) { _, isFocused in
                let intVal = NSDecimalNumber(decimal: value).intValue
                if isFocused {
                    text = intVal > 0 ? String(intVal) : ""
                } else if intVal > 0 {
                    text = formatWithSeparator(intVal)
                }
            }
    }

    private func formatWithSeparator(_ val: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: val)) ?? "\(val)"
    }
}

// MARK: - Double-based (legacy, kept for backward compatibility)

struct CurrencyInputFieldDouble: View {
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
                        if digits != newValue { text = digits }
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
                            if amount > 0 { text = String(Int(amount)) }
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

    private func formatNumber(_ value: Double) -> String { String(Int(value)) }

    private func formatWithSeparator(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        f.maximumFractionDigits = 0
        return "Rp " + (f.string(from: NSNumber(value: value)) ?? "\(Int(value))")
    }
}
