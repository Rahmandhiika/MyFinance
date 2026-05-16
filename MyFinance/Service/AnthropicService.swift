import Foundation
import SwiftData
import Combine

// MARK: - Chat Message Model

struct AIChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date = Date()

    enum Role { case user, assistant }
}

// MARK: - Anthropic Service

@MainActor
final class AnthropicService: ObservableObject {
    static let shared = AnthropicService()
    private init() {}

    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model    = "claude-haiku-4-5"

    // MARK: - Send Message

    /// Kirim pesan ke Claude dengan context keuangan user
    func sendMessage(
        userMessage: String,
        history: [AIChatMessage],
        financialContext: String,
        apiKey: String
    ) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AnthropicError.missingAPIKey
        }

        isLoading = true
        defer { isLoading = false }

        // Build messages array dari history
        var messages: [[String: String]] = history.map { msg in
            ["role": msg.role == .user ? "user" : "assistant", "content": msg.content]
        }
        messages.append(["role": "user", "content": userMessage])

        let systemPrompt = buildSystemPrompt(context: financialContext)
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": messages
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AnthropicError.networkError
        }

        if http.statusCode == 401 { throw AnthropicError.invalidAPIKey }
        if http.statusCode == 429 { throw AnthropicError.rateLimited }
        guard http.statusCode == 200 else {
            throw AnthropicError.httpError(http.statusCode)
        }

        let result = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        return result.content.first?.text ?? ""
    }

    // MARK: - Generate Insight Card

    /// Generate satu insight card — prompt spesifik per tipe
    func generateInsight(
        type: AIInsightType,
        financialContext: String,
        apiKey: String
    ) async throws -> String {
        let prompt = type.prompt
        return try await sendMessage(
            userMessage: prompt,
            history: [],
            financialContext: financialContext,
            apiKey: apiKey
        )
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(context: String) -> String {
        """
        Kamu adalah MyFinance AI — asisten keuangan personal yang cerdas dan ramah.
        Kamu berbicara dalam Bahasa Indonesia yang santai tapi profesional.

        DATA KEUANGAN USER:
        \(context)

        PANDUAN RESPONS:
        - Jawab berdasarkan data keuangan user di atas, bukan asumsi umum
        - Kasih saran yang spesifik dan actionable, bukan saran generik
        - Kalau ada pola menarik atau anomali, sebutkan dengan jelas
        - Untuk aset/investasi: berikan observasi dan edukasi, BUKAN rekomendasi beli/jual spesifik
        - Gunakan emoji secukupnya biar lebih hidup tapi jangan berlebihan
        - Respons singkat dan padat — max 3-4 paragraf kecuali diminta detail
        - Tone: seperti teman yang paham keuangan, bukan robot atau konsultan formal
        - Kalau user tanya di luar topik keuangan, arahkan kembali ke topik keuangan mereka
        """
    }
}

// MARK: - Financial Context Builder

struct FinancialContextBuilder {
    static func build(
        transaksi: [Transaksi],
        pockets: [Pocket],
        targets: [Target],
        anggaran: [Anggaran],
        aset: [Aset],
        langganan: [Langganan],
        profile: UserProfile?
    ) -> String {
        let cal = Calendar.current
        let now = Date()

        // --- Bulan ini ---
        let thisMonthTx = transaksi.filter { cal.isDate($0.tanggal, equalTo: now, toGranularity: .month) }
        let totalOut = thisMonthTx.filter { $0.tipe == .pengeluaran }.reduce(Decimal(0)) { $0 + $1.nominal }
        let totalIn  = thisMonthTx.filter { $0.tipe == .pemasukan  }.reduce(Decimal(0)) { $0 + $1.nominal }
        let savingRate = totalIn > 0 ? Double(truncating: ((totalIn - totalOut) / totalIn * 100) as NSDecimalNumber) : 0

        // --- 3 bulan terakhir ---
        var monthlyContext = ""
        for offset in 1...3 {
            guard let monthDate = cal.date(byAdding: .month, value: -offset, to: now) else { continue }
            var comps = cal.dateComponents([.year, .month], from: monthDate)
            comps.day = 1
            guard let start = cal.date(from: comps),
                  let end = cal.date(byAdding: .month, value: 1, to: start) else { continue }
            let txs = transaksi.filter { $0.tanggal >= start && $0.tanggal < end }
            let out = txs.filter { $0.tipe == .pengeluaran }.reduce(Decimal(0)) { $0 + $1.nominal }
            let inc = txs.filter { $0.tipe == .pemasukan  }.reduce(Decimal(0)) { $0 + $1.nominal }
            let df = DateFormatter(); df.locale = Locale(identifier: "id_ID"); df.dateFormat = "MMM yyyy"
            monthlyContext += "  \(df.string(from: monthDate)): Keluar \(out.shortFormatted), Masuk \(inc.shortFormatted)\n"
        }

        // --- Kategori terbesar bulan ini ---
        var katMap: [String: Decimal] = [:]
        for t in thisMonthTx.filter({ $0.tipe == .pengeluaran }) {
            let key = t.kategori?.nama ?? "Lainnya"
            katMap[key, default: 0] += t.nominal
        }
        let topKat = katMap.sorted { $0.value > $1.value }.prefix(5)
            .map { "  \($0.key): \($0.value.shortFormatted)" }.joined(separator: "\n")

        // --- Budget status ---
        let budgetStatus = anggaran.map { a -> String in
            let used = thisMonthTx.filter { t in
                t.tipe == .pengeluaran &&
                (a.kategori == nil || t.kategori?.id == a.kategori?.id)
            }.reduce(Decimal(0)) { $0 + $1.nominal }
            let pct = a.nominal > 0 ? Int(Double(truncating: (used / a.nominal * 100) as NSDecimalNumber)) : 0
            let katNama = a.kategori?.nama ?? "Semua"
            return "  \(katNama): \(used.shortFormatted)/\(a.nominal.shortFormatted) (\(pct)%)"
        }.joined(separator: "\n")

        // --- Pocket ---
        let totalSaldo = pockets.reduce(Decimal(0)) { $0 + $1.saldo }
        let pocketList = pockets.prefix(5).map { "  \($0.nama): \($0.saldo.shortFormatted)" }.joined(separator: "\n")

        // --- Aset ---
        var asetContext = ""
        for a in aset {
            let plPct: Double = {
                let modal = Double(truncating: a.modal as NSDecimalNumber)
                let nilai = Double(truncating: a.nilaiSaatIni as NSDecimalNumber)
                return modal > 0 ? (nilai - modal) / modal * 100 : 0
            }()
            switch a.tipe {
            case .saham:
                let lot = a.lot ?? 0
                asetContext += "  Saham \(a.nama): \(lot) lot, nilai \(a.nilaiSaatIni.shortFormatted), PL: \(String(format: "%+.1f%%", plPct))\n"
            case .reksadana:
                let nav = a.navSaatIni ?? 0
                asetContext += "  Reksa Dana \(a.nama): NAV \(nav.idrFormatted), nilai \(a.nilaiSaatIni.shortFormatted), PL: \(String(format: "%+.1f%%", plPct))\n"
            default:
                asetContext += "  \(a.tipe.rawValue) \(a.nama): \(a.nilaiSaatIni.shortFormatted)\n"
            }
        }

        // --- Wishlist aktif ---
        let activeTargets = targets.filter { !$0.isSelesai }
        let wishlistContext = activeTargets.prefix(5).map { t -> String in
            let progress = t.targetNominal > 0
                ? Int(Double(truncating: (t.tersimpan / t.targetNominal * 100) as NSDecimalNumber))
                : 0
            return "  \(t.nama): target \(t.targetNominal.shortFormatted), terkumpul \(t.tersimpan.shortFormatted) (\(progress)%)"
        }.joined(separator: "\n")

        // --- Langganan aktif ---
        let langgananContext = langganan.filter { $0.isAktif }.prefix(5)
            .map { "  \($0.nama): \($0.nominal.shortFormatted)/bulan (tagih tgl \($0.tanggalTagih))" }
            .joined(separator: "\n")

        // --- Histori rata-rata nabung ---
        let nabungBulanIni = thisMonthTx.filter { $0.kategori?.isNabung == true && $0.tipe == .pengeluaran }
            .reduce(Decimal(0)) { $0 + $1.nominal }

        let df = DateFormatter(); df.locale = Locale(identifier: "id_ID"); df.dateFormat = "MMMM yyyy"

        return """
        === DATA KEUANGAN \((profile?.nama ?? "User").uppercased()) ===
        Periode: \(df.string(from: now))

        RINGKASAN BULAN INI:
          Total Pengeluaran : \(totalOut.idrFormatted)
          Total Pemasukan   : \(totalIn.idrFormatted)
          Saving Rate       : \(String(format: "%.1f%%", savingRate))
          Nabung bulan ini  : \(nabungBulanIni.idrFormatted)
          Jumlah transaksi  : \(thisMonthTx.count)

        3 BULAN TERAKHIR:
        \(monthlyContext.isEmpty ? "  Belum ada data" : monthlyContext)
        KATEGORI PENGELUARAN TERBESAR:
        \(topKat.isEmpty ? "  Belum ada data" : topKat)

        STATUS BUDGET:
        \(budgetStatus.isEmpty ? "  Tidak ada budget diset" : budgetStatus)

        POCKET & SALDO:
          Total saldo semua pocket: \(totalSaldo.idrFormatted)
        \(pocketList.isEmpty ? "  Belum ada pocket" : pocketList)

        ASET & INVESTASI:
        \(asetContext.isEmpty ? "  Belum ada aset" : asetContext)

        WISHLIST AKTIF:
        \(wishlistContext.isEmpty ? "  Tidak ada wishlist aktif" : wishlistContext)

        LANGGANAN AKTIF:
        \(langgananContext.isEmpty ? "  Tidak ada langganan" : langgananContext)
        """
    }
}

// MARK: - Insight Types

enum AIInsightType: String, CaseIterable {
    case kesehatanKeuangan = "kesehatan"
    case analisaPengeluaran = "pengeluaran"
    case analisaAset = "aset"
    case wishlistForecast = "wishlist"
    case peringatan = "peringatan"

    var title: String {
        switch self {
        case .kesehatanKeuangan:  return "Kesehatan Keuangan"
        case .analisaPengeluaran: return "Analisa Pengeluaran"
        case .analisaAset:        return "Analisa Aset"
        case .wishlistForecast:   return "Wishlist Forecast"
        case .peringatan:         return "Perlu Perhatian"
        }
    }

    var icon: String {
        switch self {
        case .kesehatanKeuangan:  return "heart.fill"
        case .analisaPengeluaran: return "creditcard.fill"
        case .analisaAset:        return "chart.line.uptrend.xyaxis"
        case .wishlistForecast:   return "star.fill"
        case .peringatan:         return "exclamationmark.triangle.fill"
        }
    }

    var color: String {
        switch self {
        case .kesehatanKeuangan:  return "#22C55E"
        case .analisaPengeluaran: return "#FF6B6B"
        case .analisaAset:        return "#F59E0B"
        case .wishlistForecast:   return "#A78BFA"
        case .peringatan:         return "#EF4444"
        }
    }

    var prompt: String {
        switch self {
        case .kesehatanKeuangan:
            return "Berikan analisa singkat kesehatan keuangan aku bulan ini. Sertakan: kondisi saving rate, apakah pengeluaran normal atau ada yang aneh, dan 1 saran utama. Format: 2-3 kalimat singkat."
        case .analisaPengeluaran:
            return "Analisa pola pengeluaran aku bulan ini dibanding bulan-bulan sebelumnya. Ada kategori yang naik signifikan? Ada yang bisa dihemat? Kasih 1-2 saran konkret dan spesifik (bukan saran generik)."
        case .analisaAset:
            return "Review performa aset dan investasi aku. Mana yang perform bagus, mana yang perlu diperhatikan? Kalau belum punya aset, sarankan mulai dari mana. Ingat: observasi saja, bukan rekomendasi beli/jual."
        case .wishlistForecast:
            return "Berdasarkan saving rate dan pola keuangan aku, kapan kira-kira bisa mencapai wishlist? Kalau bisa nabung lebih, berapa yang harus ditambah per bulan agar lebih cepat?"
        case .peringatan:
            return "Cek apakah ada hal yang perlu aku perhatikan: budget yang hampir habis, pengeluaran tidak normal, langganan yang mungkin tidak dipakai, atau tren negatif. Kalau semua oke, bilang begitu."
        }
    }
}

// MARK: - Errors

enum AnthropicError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case networkError
    case rateLimited
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:     return "API key belum diisi. Set di Pengaturan → AI."
        case .invalidAPIKey:     return "API key tidak valid. Cek kembali di Pengaturan."
        case .networkError:      return "Gagal terhubung ke server AI."
        case .rateLimited:       return "Terlalu banyak request. Coba lagi sebentar."
        case .httpError(let c):  return "Server error \(c)."
        }
    }
}

// MARK: - Response Models

private struct AnthropicResponse: Decodable {
    let content: [ContentBlock]
    struct ContentBlock: Decodable {
        let text: String
    }
}
