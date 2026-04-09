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

    var usdFormatted: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: self)) ?? "$\(self)"
    }

    func formatted(currency: AppCurrency) -> String {
        currency == .IDR ? idrFormatted : usdFormatted
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
