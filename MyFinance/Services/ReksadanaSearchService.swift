import Foundation

struct ReksadanaItem: Codable, Identifiable, Hashable {
    let nama: String
    let manajer: String
    let jenis: String  // "Pasar Uang", "Obligasi", "Saham"
    var featured: Bool = false

    var id: String { nama }
}

final class ReksadanaSearchService {
    static let shared = ReksadanaSearchService()

    private let allFunds: [ReksadanaItem]

    /// The 3 utama featured funds, shown as suggestions before user types.
    var featuredFunds: [ReksadanaItem] {
        allFunds.filter { $0.featured }
    }

    private init() {
        guard let url = Bundle.main.url(forResource: "reksadana", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let funds = try? JSONDecoder().decode([ReksadanaItem].self, from: data) else {
            allFunds = []
            return
        }
        allFunds = funds
    }

    /// Returns up to `limit` funds matching `query` in nama or manajer.
    /// Optionally filter by jenis (e.g. "Pasar Uang").
    func search(_ query: String, jenis: String? = nil, limit: Int = 10) -> [ReksadanaItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        var candidates = allFunds

        if let jenis, !jenis.isEmpty {
            candidates = candidates.filter { $0.jenis == jenis }
        }

        guard !trimmed.isEmpty else { return [] }

        let q = trimmed.lowercased()
        return candidates
            .filter { $0.nama.lowercased().contains(q) || $0.manajer.lowercased().contains(q) }
            .prefix(limit)
            .map { $0 }
    }
}
