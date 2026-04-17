import Foundation

// MARK: - Signal

enum SinyalAnalisa {
    case beli, hold, jual

    var label: String {
        switch self {
        case .beli: return "BUY"
        case .hold: return "HOLD"
        case .jual: return "SELL"
        }
    }

    var emoji: String {
        switch self {
        case .beli: return "↑"
        case .hold: return "→"
        case .jual: return "↓"
        }
    }

    var hexColor: String {
        switch self {
        case .beli: return "#22C55E"
        case .hold: return "#F59E0B"
        case .jual: return "#EF4444"
        }
    }
}

// MARK: - Result

struct HasilAnalisa {
    let kode: String
    let hargaSaatIni: Double
    let ema20: Double
    let rsi14: Double
    let volume: Double
    let avgVolume20: Double
    let lastClose: Double
    let lastOpen: Double

    var hargaDiAtasEMA20: Bool { hargaSaatIni > ema20 }
    var rsiDiAtas50:      Bool { rsi14 > 50 }
    var volumeDiAtasAvg:  Bool { volume > avgVolume20 && avgVolume20 > 0 }
    var candleBullish:    Bool { lastClose > lastOpen }

    var score: Int {
        [hargaDiAtasEMA20, rsiDiAtas50, volumeDiAtasAvg, candleBullish].filter { $0 }.count
    }

    var sinyal: SinyalAnalisa {
        switch score {
        case 3...4: return .beli
        case 2:     return .hold
        default:    return .jual
        }
    }
}

// MARK: - Error

enum AnalisisError: LocalizedError {
    case tickerTidakValid
    case dataTidakTersedia
    case tidakAdaKoneksi

    var errorDescription: String? {
        switch self {
        case .tickerTidakValid:   return "Kode saham tidak valid"
        case .dataTidakTersedia:  return "Data tidak tersedia"
        case .tidakAdaKoneksi:    return "Tidak ada koneksi internet"
        }
    }
}

// MARK: - Service

final class StockAnalysisService {
    static let shared = StockAnalysisService()
    private init() {}

    func analisa(kode: String) async throws -> HasilAnalisa {
        let ticker = kode.uppercased().hasSuffix(".JK")
            ? kode.uppercased()
            : "\(kode.uppercased()).JK"
        let urlStr = "https://query1.finance.yahoo.com/v8/finance/chart/\(ticker)?interval=1d&range=3mo"
        guard let url = URL(string: urlStr) else { throw AnalisisError.tickerTidakValid }

        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            return try parseResponse(data: data, kode: kode.uppercased())
        } catch is URLError {
            throw AnalisisError.tidakAdaKoneksi
        } catch let err as AnalisisError {
            throw err
        } catch {
            throw AnalisisError.tidakAdaKoneksi
        }
    }

    // MARK: - Parse

    private func parseResponse(data: Data, kode: String) throws -> HasilAnalisa {
        guard
            let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let chart   = json["chart"]  as? [String: Any],
            let results = chart["result"] as? [[String: Any]],
            let result  = results.first
        else { throw AnalisisError.dataTidakTersedia }

        guard
            let meta          = result["meta"] as? [String: Any],
            let hargaSaatIni  = meta["regularMarketPrice"] as? Double
        else { throw AnalisisError.dataTidakTersedia }

        guard
            let indicators = result["indicators"] as? [String: Any],
            let quoteArr   = indicators["quote"] as? [[String: Any]],
            let quote      = quoteArr.first
        else { throw AnalisisError.dataTidakTersedia }

        let closes  = doubles(from: quote["close"])
        let opens   = doubles(from: quote["open"])
        let volumes = doubles(from: quote["volume"])

        guard closes.count >= 20 else { throw AnalisisError.dataTidakTersedia }

        let ema20 = calculateEMA(prices: closes, period: 20)
        let rsi14 = calculateRSI(prices: closes, period: 14)

        // Last day volume vs avg of previous 20 sessions
        let lastVol   = volumes.last ?? 0
        let prevVols  = volumes.count > 1 ? Array(volumes.suffix(21).dropLast()) : []
        let avgVol20  = prevVols.isEmpty ? 0 : prevVols.reduce(0, +) / Double(prevVols.count)

        let lastClose = closes.last ?? hargaSaatIni
        let lastOpen  = opens.last  ?? hargaSaatIni

        return HasilAnalisa(
            kode:         kode,
            hargaSaatIni: hargaSaatIni,
            ema20:        ema20,
            rsi14:        rsi14,
            volume:       lastVol,
            avgVolume20:  avgVol20,
            lastClose:    lastClose,
            lastOpen:     lastOpen
        )
    }

    // Safely extract [Double] from an Any (handles Int, Double, null elements)
    private func doubles(from value: Any?) -> [Double] {
        guard let arr = value as? [Any?] else { return [] }
        return arr.compactMap { el -> Double? in
            guard let el else { return nil }
            if let d = el as? Double { return d }
            if let i = el as? Int    { return Double(i) }
            if let n = el as? NSNumber { return n.doubleValue }
            return nil
        }
    }

    // MARK: - EMA (Exponential Moving Average)

    private func calculateEMA(prices: [Double], period: Int) -> Double {
        guard prices.count >= period else { return prices.last ?? 0 }
        let k   = 2.0 / Double(period + 1)
        var ema = prices.prefix(period).reduce(0, +) / Double(period) // seed = SMA
        for price in prices.dropFirst(period) {
            ema = price * k + ema * (1 - k)
        }
        return ema
    }

    // MARK: - RSI (Relative Strength Index — Wilder's smoothing)

    private func calculateRSI(prices: [Double], period: Int) -> Double {
        guard prices.count > period else { return 50 }
        var gains  = [Double]()
        var losses = [Double]()
        for i in 1..<prices.count {
            let d = prices[i] - prices[i - 1]
            gains.append(max(d, 0))
            losses.append(max(-d, 0))
        }
        guard gains.count >= period else { return 50 }

        // Initial avg using SMA
        var avgGain = gains.prefix(period).reduce(0, +)  / Double(period)
        var avgLoss = losses.prefix(period).reduce(0, +) / Double(period)

        // Wilder's smoothing for remaining
        for i in period..<gains.count {
            avgGain = (avgGain * Double(period - 1) + gains[i])  / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)
        }
        guard avgLoss > 0 else { return 100 }
        return 100 - (100 / (1 + avgGain / avgLoss))
    }
}
