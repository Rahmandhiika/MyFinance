import Foundation
import SwiftData

class ExchangeRateService {
    static let shared = ExchangeRateService()
    private init() {}

    private let apiURL = "https://api.exchangerate-api.com/v4/latest/USD"

    func refresh(context: ModelContext) async {
        guard let url = URL(string: apiURL) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct Resp: Decodable { let rates: [String: Double] }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            let rate = resp.rates["IDR"] ?? 16000
            upsertRate(from: "USD", to: "IDR", rate: rate, context: context)
        } catch {
            // Insert fallback only if none exists
            let desc = FetchDescriptor<ExchangeRate>(predicate: #Predicate { $0.fromCurrency == "USD" })
            if (try? context.fetch(desc))?.isEmpty ?? true {
                upsertRate(from: "USD", to: "IDR", rate: 16000, context: context)
            }
        }
    }

    private func upsertRate(from: String, to: String, rate: Double, context: ModelContext) {
        let desc = FetchDescriptor<ExchangeRate>(predicate: #Predicate { $0.fromCurrency == "USD" && $0.toCurrency == "IDR" })
        if let existing = (try? context.fetch(desc))?.first {
            existing.rate = rate
            existing.lastUpdated = Date()
        } else {
            context.insert(ExchangeRate(fromCurrency: from, toCurrency: to, rate: rate))
        }
        try? context.save()
    }

    func currentRate(context: ModelContext) -> Double {
        let desc = FetchDescriptor<ExchangeRate>(predicate: #Predicate { $0.fromCurrency == "USD" && $0.toCurrency == "IDR" })
        return (try? context.fetch(desc))?.first?.rate ?? 16000
    }

    func lastUpdated(context: ModelContext) -> Date? {
        let desc = FetchDescriptor<ExchangeRate>(predicate: #Predicate { $0.fromCurrency == "USD" && $0.toCurrency == "IDR" })
        return (try? context.fetch(desc))?.first?.lastUpdated
    }
}
