import SwiftUI

// MARK: - Decimal-based (used in new views)

struct CurrencyInputField: View {
    @Environment(\.appTheme) private var theme
    @Binding var value: Decimal
    /// Nonaktifkan untuk field yang harus bulat (tidak diperlukan lagi karena default true)
    var allowsDecimal: Bool = true

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("0", text: $text)
            .keyboardType(allowsDecimal ? .decimalPad : .numberPad)
            .focused($focused)
            .padding(12)
            .background(theme.separator)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(theme.textPrimary)
            .onChange(of: text) { _, newValue in
                // Guard: hanya parse saat user aktif mengetik.
                // Kalau tidak focused, perubahan text berasal dari formatter (bukan user)
                // dan akan menyebabkan bug: titik ribuan terbaca sebagai desimal.
                guard focused else { return }
                let filtered = filterInput(newValue)
                if filtered != newValue { text = filtered }
                value = parseDecimal(filtered)
            }
            .onChange(of: value) { _, newValue in
                // Hanya reformat saat tidak sedang diketik
                if !focused {
                    text = formatForDisplay(newValue)
                }
            }
            .onAppear {
                text = formatForDisplay(value)
            }
            .onChange(of: focused) { _, isFocused in
                if isFocused {
                    // Saat mulai edit: tunjukkan angka mentah tanpa ribuan separator
                    text = value > 0 ? formatForEditing(value) : ""
                } else {
                    // Saat selesai: tunjukkan format lengkap
                    text = formatForDisplay(value)
                }
            }
    }

    // MARK: - Helpers

    /// Hanya boleh digit + satu pemisah desimal (koma atau titik)
    private func filterInput(_ input: String) -> String {
        if allowsDecimal {
            var hasDecimal = false
            var result = ""
            for ch in input {
                if ch.isNumber {
                    result.append(ch)
                } else if (ch == "," || ch == ".") && !hasDecimal {
                    result.append(",") // normalkan ke koma
                    hasDecimal = true
                }
            }
            return result
        } else {
            return input.filter { $0.isNumber }
        }
    }

    /// Parse string ke Decimal, handle koma atau titik sebagai desimal
    private func parseDecimal(_ input: String) -> Decimal {
        let normalized = input.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized) ?? 0
    }

    /// Format untuk mode edit (tidak pakai ribuan separator, desimal pakai koma)
    private func formatForEditing(_ val: Decimal) -> String {
        if allowsDecimal {
            let d = Double(truncating: val as NSDecimalNumber)
            // Gunakan value saja (bukan text) untuk cek apakah bilangan bulat.
            // text masih menyimpan string lama saat fungsi ini dipanggil.
            if d == d.rounded() && d >= 0 {
                return String(format: "%.0f", d)
            }
            return String(format: "%.2f", d).replacingOccurrences(of: ".", with: ",")
        } else {
            let intVal = NSDecimalNumber(decimal: val).intValue
            return intVal > 0 ? String(intVal) : ""
        }
    }

    /// Format untuk tampilan idle (ribuan separator titik, desimal koma)
    private func formatForDisplay(_ val: Decimal) -> String {
        guard val > 0 else { return "" }
        if allowsDecimal {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.groupingSeparator = "."
            f.decimalSeparator = ","
            f.minimumFractionDigits = 2
            f.maximumFractionDigits = 2
            return f.string(from: val as NSDecimalNumber) ?? "\(val)"
        } else {
            let intVal = NSDecimalNumber(decimal: val).intValue
            guard intVal > 0 else { return "" }
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.groupingSeparator = "."
            f.maximumFractionDigits = 0
            return f.string(from: NSNumber(value: intVal)) ?? "\(intVal)"
        }
    }
}

