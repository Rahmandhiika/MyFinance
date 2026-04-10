import Foundation

struct ParsedVoiceResult {
    var type: TipeTransaksi = .expense
    var amount: Double = 0
    var matchedPocketName: String?
    var matchedCategoryName: String?
    var note: String = ""
}

class NLPParser {
    static let shared = NLPParser()
    private init() {}

    private let transferKeywords = ["transfer ke", "kirim ke", "pindah ke"]
    private let incomeKeywords = ["terima", "dapat", "gaji", "gajian", "masuk", "diterima", "penghasilan"]
    private let expenseKeywords = ["beli", "bayar", "keluar", "buat", "beli"]

    private let categoryMap: [String: String] = [
        "makan": "Makan & Minum", "nasi": "Makan & Minum", "kopi": "Makan & Minum",
        "minum": "Makan & Minum", "snack": "Makan & Minum", "jajan": "Makan & Minum",
        "grab": "Transport", "gojek": "Transport", "ojol": "Transport",
        "bensin": "Transport", "parkir": "Transport", "tol": "Transport",
        "listrik": "Tagihan", "air": "Tagihan", "internet": "Tagihan",
        "pulsa": "Tagihan", "wifi": "Tagihan",
        "belanja": "Belanja", "baju": "Belanja", "sepatu": "Belanja",
    ]

    func parse(text: String, pocketNames: [String]) -> ParsedVoiceResult {
        var result = ParsedVoiceResult()
        let lower = text.lowercased()

        result.type = detectType(lower)
        result.amount = extractAmount(lower)
        result.matchedPocketName = matchPocket(lower, pocketNames: pocketNames)
        result.matchedCategoryName = matchCategory(lower)

        var note = text
        if result.amount > 0 {
            // Remove amount-related text
            let amountPatterns = ["\\d+[.,]?\\d*\\s*(ribu|rb|rbu|k|jt|juta|m)?", "\\d+"]
            for pattern in amountPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    note = regex.stringByReplacingMatches(in: note, range: NSRange(note.startIndex..., in: note), withTemplate: "")
                }
            }
        }
        result.note = note.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    private func detectType(_ text: String) -> TipeTransaksi {
        for kw in transferKeywords {
            if text.contains(kw) { return .transfer }
        }
        for kw in incomeKeywords {
            if text.contains(kw) { return .income }
        }
        return .expense
    }

    func extractAmount(_ text: String) -> Double {
        let patterns: [(String, Double)] = [
            ("(\\d+[.,]?\\d*)\\s*juta", 1_000_000),
            ("(\\d+[.,]?\\d*)\\s*jt", 1_000_000),
            ("(\\d+[.,]?\\d*)\\s*m\\b", 1_000_000),
            ("(\\d+[.,]?\\d*)\\s*ribu", 1_000),
            ("(\\d+[.,]?\\d*)\\s*rb", 1_000),
            ("(\\d+[.,]?\\d*)\\s*rbu", 1_000),
            ("(\\d+[.,]?\\d*)\\s*k\\b", 1_000),
        ]

        for (pattern, multiplier) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let numStr = String(text[range]).replacingOccurrences(of: ",", with: ".")
                if let num = Double(numStr) {
                    return num * multiplier
                }
            }
        }

        // Plain number
        if let regex = try? NSRegularExpression(pattern: "(\\d{4,})", options: []),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return Double(text[range]) ?? 0
        }

        return 0
    }

    private func matchPocket(_ text: String, pocketNames: [String]) -> String? {
        let keywords = ["pake", "pakai", "dari", "ke", "lewat", "via"]
        for keyword in keywords {
            if let idx = text.range(of: keyword) {
                let after = String(text[idx.upperBound...]).trimmingCharacters(in: .whitespaces)
                for name in pocketNames {
                    if after.lowercased().hasPrefix(name.lowercased()) {
                        return name
                    }
                }
            }
        }
        // Fuzzy match
        for name in pocketNames {
            if text.contains(name.lowercased()) {
                return name
            }
        }
        return nil
    }

    private func matchCategory(_ text: String) -> String? {
        for (keyword, category) in categoryMap {
            if text.contains(keyword) { return category }
        }
        return nil
    }
}
