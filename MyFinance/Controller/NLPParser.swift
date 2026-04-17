import Foundation

// MARK: - ParsedResult

struct ParsedResult {
    var tipe: TipeTransaksi = .pengeluaran
    var nominal: Decimal = 0
    var matchedKategori: Kategori? = nil
    var matchedPocket: Pocket? = nil
    var catatan: String = ""
}

// MARK: - NLPParser

class NLPParser {
    static let shared = NLPParser()
    private init() {}

    private let incomeKeywords = ["terima", "dapat", "gaji", "gajian", "masuk", "diterima", "penghasilan"]

    private let categoryMap: [String: String] = [
        "makan": "Makan & Minum", "nasi": "Makan & Minum", "kopi": "Makan & Minum",
        "minum": "Makan & Minum", "snack": "Makan & Minum", "jajan": "Makan & Minum",
        "grab": "Transport", "gojek": "Transport", "ojol": "Transport",
        "bensin": "Transport", "parkir": "Transport", "tol": "Transport",
        "listrik": "Tagihan", "air": "Tagihan", "internet": "Tagihan",
        "pulsa": "Tagihan", "wifi": "Tagihan",
        "belanja": "Belanja", "baju": "Belanja", "sepatu": "Belanja",
    ]

    // MARK: - v3 parse method (returns ParsedResult with model objects)

    func parse(text: String, kategoris: [Kategori], pockets: [Pocket]) -> ParsedResult {
        var result = ParsedResult()
        let lower = text.lowercased()

        // Tipe
        result.tipe = detectTipe(lower)

        // Nominal
        let amount = extractAmount(lower)
        result.nominal = Decimal(amount)

        // Match pocket by fuzzy name
        result.matchedPocket = matchPocketObject(lower, pockets: pockets)

        // Match kategori by fuzzy name, filtered by tipe
        result.matchedKategori = matchKategoriObject(lower, kategoris: kategoris, tipe: result.tipe)

        // Build catatan from remaining text
        var note = text
        if amount > 0 {
            let amountPatterns = ["\\d+[.,]?\\d*\\s*(ribu|rb|rbu|k|jt|juta|m)?", "\\d+"]
            for pattern in amountPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    note = regex.stringByReplacingMatches(
                        in: note,
                        range: NSRange(note.startIndex..., in: note),
                        withTemplate: ""
                    )
                }
            }
        }
        result.catatan = note.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    // MARK: - Private helpers

    private func detectTipe(_ text: String) -> TipeTransaksi {
        for kw in incomeKeywords {
            if text.contains(kw) { return .pemasukan }
        }
        return .pengeluaran
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
            ("(\\d+[.,]?\\d*)\\s*ratus", 100),
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

        if let regex = try? NSRegularExpression(pattern: "(\\d{4,})", options: []),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return Double(text[range]) ?? 0
        }

        return 0
    }

    private func matchPocketObject(_ text: String, pockets: [Pocket]) -> Pocket? {
        let keywords = ["pake", "pakai", "dari", "ke", "lewat", "via"]
        for keyword in keywords {
            if let idx = text.range(of: keyword) {
                let after = String(text[idx.upperBound...]).trimmingCharacters(in: .whitespaces)
                for pocket in pockets {
                    if after.lowercased().hasPrefix(pocket.nama.lowercased()) {
                        return pocket
                    }
                }
            }
        }
        for pocket in pockets {
            if text.contains(pocket.nama.lowercased()) {
                return pocket
            }
        }
        return nil
    }

    private func matchKategoriObject(_ text: String, kategoris: [Kategori], tipe: TipeTransaksi) -> Kategori? {
        let filtered = kategoris.filter { $0.tipe == tipe }

        // First try to match against categoryMap keywords
        for (keyword, categoryName) in categoryMap {
            if text.contains(keyword) {
                if let match = filtered.first(where: {
                    $0.nama.lowercased().contains(categoryName.lowercased()) ||
                    categoryName.lowercased().contains($0.nama.lowercased())
                }) {
                    return match
                }
            }
        }

        // Then try direct fuzzy match against kategori names
        for kategori in filtered {
            let namaLower = kategori.nama.lowercased()
            let words = namaLower.components(separatedBy: .whitespaces)
            for word in words where word.count > 3 {
                if text.contains(word) { return kategori }
            }
        }

        return nil
    }
}
