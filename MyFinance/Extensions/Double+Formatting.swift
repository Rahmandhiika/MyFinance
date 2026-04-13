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

    var shortFormatted: String {
        let d = Double(truncating: self as NSDecimalNumber)
        if abs(d) >= 1_000_000_000 { return String(format: "%.1fM", d / 1_000_000_000) }
        if abs(d) >= 1_000_000 { return String(format: "%.1fjt", d / 1_000_000) }
        if abs(d) >= 1_000 { return String(format: "%.1frb", d / 1_000) }
        return String(format: "%.0f", d)
    }
}
