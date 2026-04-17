import Foundation

extension Double {
    var idrFormatted: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "IDR"
        f.currencySymbol = "Rp"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: self)) ?? "Rp\(Int(self))"
    }

    var percentFormatted: String {
        let sign = self >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", self))%"
    }

    var shortFormatted: String {
        if abs(self) >= 1_000_000_000 { return String(format: "%.1fM", self / 1_000_000_000) }
        if abs(self) >= 1_000_000     { return String(format: "%.1fjt", self / 1_000_000) }
        if abs(self) >= 1_000         { return String(format: "%.0frb", self / 1_000) }
        return String(format: "%.0f", self)
    }
}

extension Decimal {
    var idrFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "IDR"
        formatter.currencySymbol = "Rp "
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: self as NSDecimalNumber) ?? "Rp 0"
    }

    /// Format dengan 2 angka di belakang koma — dipakai untuk nilai Aset
    /// Contoh: Rp 2.333,14
    var idrDecimalFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "IDR"
        formatter.currencySymbol = "Rp "
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: self as NSDecimalNumber) ?? "Rp 0,00"
    }

    var shortFormatted: String {
        let d = Double(truncating: self as NSDecimalNumber)
        if abs(d) >= 1_000_000_000 { return String(format: "%.1fM", d / 1_000_000_000) }
        if abs(d) >= 1_000_000 { return String(format: "%.1fjt", d / 1_000_000) }
        if abs(d) >= 1_000 { return String(format: "%.1frb", d / 1_000) }
        return String(format: "%.0f", d)
    }

    /// Format unit/kuantitas ke N desimal dengan rounding yang tepat — tanpa konversi via Double.
    /// Menggunakan NSDecimalNumberHandler (.plain = round half away from zero).
    func unitFormatted(_ fractionDigits: Int = 4) -> String {
        let handler = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: Int16(fractionDigits),
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        let rounded = (self as NSDecimalNumber).rounding(accordingToBehavior: handler)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        formatter.decimalSeparator = ","
        formatter.groupingSeparator = "."
        return formatter.string(from: rounded) ?? "0"
    }
}
