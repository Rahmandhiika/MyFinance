import Foundation

// MARK: - Cached NumberFormatters
// NumberFormatter creation is expensive (~0.3ms each).
// Caching as static properties cuts per-cell render cost from O(n) allocations to zero.

private enum CachedFormatter {

    static let idr: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "IDR"
        f.currencySymbol = "Rp"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()

    static let idrDecimal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "IDR"
        f.currencySymbol = "Rp "
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    static let decimalDisplay: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    static let unitSmart: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 8
        f.decimalSeparator = ","
        f.groupingSeparator = "."
        return f
    }()

    // Parameterised unit formatters — keyed by fractionDigits
    // Thread-safe: all formatting happens on @MainActor (view layer)
    static var unitByFraction: [Int: NumberFormatter] = [:]

    static func unit(fractionDigits: Int) -> NumberFormatter {
        if let cached = unitByFraction[fractionDigits] { return cached }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = fractionDigits
        f.maximumFractionDigits = fractionDigits
        f.decimalSeparator = ","
        f.groupingSeparator = "."
        unitByFraction[fractionDigits] = f
        return f
    }
}

// MARK: - Double extensions

extension Double {
    var idrFormatted: String {
        CachedFormatter.idr.string(from: NSNumber(value: self)) ?? "Rp\(Int(self))"
    }

    var percentFormatted: String {
        let sign = self >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", self))%"
    }

    var shortFormatted: String {
        if abs(self) >= 1_000_000_000 { return String(format: "%.1fM",  self / 1_000_000_000) }
        if abs(self) >= 1_000_000     { return String(format: "%.1fjt", self / 1_000_000) }
        if abs(self) >= 1_000         { return String(format: "%.0frb", self / 1_000) }
        return String(format: "%.0f", self)
    }
}

// MARK: - Decimal extensions

extension Decimal {
    var idrFormatted: String {
        CachedFormatter.idr.string(from: self as NSDecimalNumber) ?? "Rp 0"
    }

    /// Format dengan 2 angka di belakang koma — dipakai untuk nilai Aset
    /// Contoh: Rp 2.333,14
    var idrDecimalFormatted: String {
        CachedFormatter.idrDecimal.string(from: self as NSDecimalNumber) ?? "Rp 0,00"
    }

    var shortFormatted: String {
        let d = Double(truncating: self as NSDecimalNumber)
        if abs(d) >= 1_000_000_000 { return String(format: "%.1fM",  d / 1_000_000_000) }
        if abs(d) >= 1_000_000     { return String(format: "%.1fjt", d / 1_000_000) }
        if abs(d) >= 1_000         { return String(format: "%.1frb", d / 1_000) }
        return String(format: "%.0f", d)
    }

    /// Format tanpa prefix "Rp" — ribuan pakai titik, desimal pakai koma, max 2 desimal.
    /// Dipakai untuk display kalkulator, expression string, dan input field.
    var decimalDisplayFormatted: String {
        CachedFormatter.decimalDisplay.string(from: self as NSDecimalNumber) ?? "\(self)"
    }

    /// Format kuantitas presisi — trailing zeros dihapus, max 8 desimal.
    /// Cocok untuk shares, gram, unit yang nilainya bisa panjang.
    var unitFormattedSmart: String {
        CachedFormatter.unitSmart.string(from: self as NSDecimalNumber) ?? "\(self)"
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
        return CachedFormatter.unit(fractionDigits: fractionDigits).string(from: rounded) ?? "0"
    }
}
