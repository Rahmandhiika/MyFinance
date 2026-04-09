import Foundation

struct ParsedTransaction {
    var type: TransactionType = .expense
    var amount: Double = 0
    var matchedAccountName: String? = nil
    var matchedCategoryName: String? = nil
    var note: String = ""
}

class NLPParser {
    static let shared = NLPParser()
    private init() {}

    // Base number words
    private let baseNumbers: [String: Double] = [
        "nol": 0, "satu": 1, "dua": 2, "tiga": 3, "empat": 4, "lima": 5,
        "enam": 6, "tujuh": 7, "delapan": 8, "sembilan": 9, "sepuluh": 10,
        "sebelas": 11, "dua belas": 12, "tiga belas": 13, "empat belas": 14,
        "lima belas": 15, "enam belas": 16, "tujuh belas": 17, "delapan belas": 18,
        "sembilan belas": 19, "dua puluh": 20, "tiga puluh": 30, "empat puluh": 40,
        "lima puluh": 50, "enam puluh": 60, "tujuh puluh": 70, "delapan puluh": 80,
        "sembilan puluh": 90, "seratus": 100, "seribu": 1000, "sejuta": 1_000_000
    ]

    private let multiplierWords: [String: Double] = [
        "puluh": 10, "ratus": 100, "ribu": 1_000, "juta": 1_000_000,
        "miliar": 1_000_000_000, "rb": 1_000, "jt": 1_000_000,
        "k": 1_000, "m": 1_000_000
    ]

    private let transferKeywords   = ["transfer ke", "kirim ke", "pindah ke"]
    private let incomeKeywords     = ["terima", "dapat", "gaji", "gajian", "masuk", "pemasukan", "income", "dividen", "kiriman dari", "transfer dari"]

    private let categoryMap: [String: String] = [
        "makan": "Food & Drink", "minum": "Food & Drink", "kopi": "Food & Drink",
        "nasi": "Food & Drink", "bakso": "Food & Drink", "resto": "Food & Drink",
        "bensin": "Transport", "parkir": "Transport", "ojek": "Transport",
        "grab": "Transport", "gojek": "Transport", "taxi": "Transport",
        "busway": "Transport", "kereta": "Transport", "krl": "Transport",
        "listrik": "Bills & Utilities", "token": "Bills & Utilities",
        "internet": "Bills & Utilities", "pulsa": "Bills & Utilities",
        "tagihan": "Bills & Utilities", "iuran": "Bills & Utilities",
        "baju": "Shopping", "sepatu": "Shopping", "belanja": "Shopping",
        "netflix": "Entertainment", "spotify": "Entertainment",
        "game": "Entertainment", "bioskop": "Entertainment",
        "dokter": "Health", "obat": "Health", "apotek": "Health",
        "rs": "Health", "rumah sakit": "Health",
        "sekolah": "Education", "kursus": "Education", "buku": "Education",
        "saham": "Investment Buy", "crypto": "Investment Buy", "reksadana": "Investment Buy",
        "gaji": "Salary", "gajian": "Salary",
        "dividen": "Dividend",
    ]

    func parse(text: String, accounts: [Account]) -> ParsedTransaction {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        var result = ParsedTransaction()
        result.note = text
        result.type = detectType(lower)
        result.amount = extractAmount(lower)
        result.matchedAccountName = matchAccount(lower, accounts: accounts)
        result.matchedCategoryName = matchCategory(lower)
        return result
    }

    private func detectType(_ text: String) -> TransactionType {
        for kw in transferKeywords where text.contains(kw) { return .transfer }
        for kw in incomeKeywords    where text.contains(kw) { return .income }
        return .expense
    }

    private func extractAmount(_ text: String) -> Double {
        // 1. Try digit + multiplier: "300 ribu", "1.5 juta", "300rb"
        let digitPattern = #"(\d+(?:[.,]\d+)?)\s*(ribu|juta|miliar|rb|jt|k|m)?\b"#
        if let regex = try? NSRegularExpression(pattern: digitPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let numRange = Range(match.range(at: 1), in: text)
            let mulRange = Range(match.range(at: 2), in: text)

            if let numRange {
                let cleaned = String(text[numRange])
                    .replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: "")

                if let num = Double(cleaned) {
                    if let mulRange, let multiplier = multiplierWords[String(text[mulRange])] {
                        return num * multiplier
                    }
                    // bare number >= 1000 already full amount
                    return num
                }
            }
        }

        // 2. Word-based: "tiga ratus ribu", "dua juta lima ratus ribu"
        return parseWordAmount(text)
    }

    private func parseWordAmount(_ text: String) -> Double {
        var total = 0.0
        var current = 0.0
        let tokens = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        var i = 0
        while i < tokens.count {
            let w = tokens[i]

            // Try two-word combos
            if i + 1 < tokens.count {
                let two = "\(w) \(tokens[i+1])"
                if let v = baseNumbers[two] { current += v; i += 2; continue }
            }

            if let v = baseNumbers[w] { current += v; i += 1; continue }

            switch w {
            case "ratus":
                current = current == 0 ? 100 : current * 100
            case "ribu", "rb":
                current = current == 0 ? 1000 : current * 1000
                total += current; current = 0
            case "juta", "jt":
                current = current == 0 ? 1_000_000 : current * 1_000_000
                total += current; current = 0
            case "miliar":
                current = current == 0 ? 1_000_000_000 : current * 1_000_000_000
                total += current; current = 0
            default: break
            }
            i += 1
        }
        return total + current
    }

    private func matchAccount(_ text: String, accounts: [Account]) -> String? {
        // Look for "pakai X", "dari X", "ke X", "pake X"
        let patterns = [#"(?:pakai|pake|dari|ke)\s+(\w+)"#]
        var candidates: [String] = []
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                candidates.append(String(text[range]))
            }
        }

        // Score-based matching
        for candidate in candidates {
            for account in accounts {
                let accLower = account.name.lowercased()
                if accLower.contains(candidate) || candidate.contains(accLower) {
                    return account.name
                }
            }
        }

        // Direct mention
        for account in accounts {
            if text.contains(account.name.lowercased()) {
                return account.name
            }
        }
        return nil
    }

    private func matchCategory(_ text: String) -> String? {
        // Longer keywords first to avoid false matches
        let sorted = categoryMap.keys.sorted { $0.count > $1.count }
        for key in sorted where text.contains(key) {
            return categoryMap[key]
        }
        return nil
    }
}
