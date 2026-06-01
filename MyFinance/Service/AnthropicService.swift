import Foundation
import SwiftData
import Observation

// MARK: - Chat Message Model

struct AIChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date = Date()
    var toolCall: AIToolCall? = nil     // non-nil kalau AI minta jalankan tool
    var isToolResult: Bool = false      // pesan berisi hasil eksekusi tool

    enum Role { case user, assistant }
}

// MARK: - AI Tool Call

struct AIToolCall: Equatable {
    let toolUseId: String
    let name: AIToolName
    let input: [String: String]         // parameter dari AI
    var status: Status = .pending

    enum Status { case pending, confirmed, rejected, executed }
}

enum AIToolName: String, CaseIterable {
    case setAnggaran          = "set_anggaran"
    case renameKategori       = "rename_kategori"
    case pindahKategoriTx     = "pindah_kategori_transaksi"
    case buatTransaksi        = "buat_transaksi"

    var displayName: String {
        switch self {
        case .setAnggaran:       return "Set Budget"
        case .renameKategori:    return "Rename Kategori"
        case .pindahKategoriTx:  return "Pindah Kategori Transaksi"
        case .buatTransaksi:     return "Buat Transaksi"
        }
    }

    var icon: String {
        switch self {
        case .setAnggaran:       return "chart.bar.fill"
        case .renameKategori:    return "tag.fill"
        case .pindahKategoriTx:  return "arrow.triangle.2.circlepath"
        case .buatTransaksi:     return "plus.circle.fill"
        }
    }
}

// MARK: - Anthropic Service

@Observable @MainActor
final class AnthropicService {
    static let shared = AnthropicService()
    private init() {}

    var isLoading = false
    var errorMessage: String? = nil

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model    = "claude-haiku-4-5"

    // MARK: - Send Message (returns text or tool call)

    func sendMessage(
        userMessage: String,
        history: [AIChatMessage],
        financialContext: String,
        apiKey: String
    ) async throws -> AIChatMessage {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AnthropicError.missingAPIKey
        }
        isLoading = true
        defer { isLoading = false }

        let messages = buildMessages(history: history, newUserMessage: userMessage)
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": buildSystemPrompt(context: financialContext),
            "tools": aiTools,
            "messages": messages
        ]

        let raw = try await postToAnthropic(body: body, apiKey: apiKey)
        return parseResponse(raw)
    }

    // MARK: - Continue after tool result

    /// Kirim hasil eksekusi tool balik ke Claude, dapat respons akhir
    func continueAfterTool(
        history: [AIChatMessage],
        toolCall: AIToolCall,
        resultText: String,
        financialContext: String,
        apiKey: String
    ) async throws -> AIChatMessage {
        isLoading = true
        defer { isLoading = false }

        // Rebuild messages including tool_use + tool_result
        var messages = buildMessages(history: history.filter { !$0.isToolResult }, newUserMessage: nil)

        // Append assistant tool_use block
        messages.append([
            "role": "assistant",
            "content": [[
                "type": "tool_use",
                "id": toolCall.toolUseId,
                "name": toolCall.name.rawValue,
                "input": toolCall.input
            ]]
        ])
        // Append tool_result
        messages.append([
            "role": "user",
            "content": [[
                "type": "tool_result",
                "tool_use_id": toolCall.toolUseId,
                "content": resultText
            ]]
        ])

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 512,
            "system": buildSystemPrompt(context: financialContext),
            "tools": aiTools,
            "messages": messages
        ]

        let raw = try await postToAnthropic(body: body, apiKey: apiKey)
        return parseResponse(raw)
    }

    // MARK: - Generate Insight Card

    func generateInsight(type: AIInsightType, financialContext: String, apiKey: String) async throws -> String {
        let result = try await sendMessage(
            userMessage: type.prompt,
            history: [],
            financialContext: financialContext,
            apiKey: apiKey
        )
        return result.content
    }

    // MARK: - Helpers

    private func buildMessages(history: [AIChatMessage], newUserMessage: String?) -> [[String: Any]] {
        var messages: [[String: Any]] = history.compactMap { msg in
            guard !msg.isToolResult else { return nil }
            if let tc = msg.toolCall, msg.role == .assistant {
                // reconstruct tool_use assistant message
                return [
                    "role": "assistant",
                    "content": [[
                        "type": "tool_use",
                        "id": tc.toolUseId,
                        "name": tc.name.rawValue,
                        "input": tc.input
                    ]]
                ]
            }
            return ["role": msg.role == .user ? "user" : "assistant", "content": msg.content]
        }
        if let newMsg = newUserMessage {
            messages.append(["role": "user", "content": newMsg])
        }
        return messages
    }

    private func postToAnthropic(body: [String: Any], apiKey: String) async throws -> AnthropicRawResponse {
        var request = URLRequest(url: endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AnthropicError.networkError }
        if http.statusCode == 401 { throw AnthropicError.invalidAPIKey }
        if http.statusCode == 429 { throw AnthropicError.rateLimited }
        guard http.statusCode == 200 else { throw AnthropicError.httpError(http.statusCode) }
        return try JSONDecoder().decode(AnthropicRawResponse.self, from: data)
    }

    private func parseResponse(_ raw: AnthropicRawResponse) -> AIChatMessage {
        // Check for tool_use block first
        for block in raw.content {
            if block.type == "tool_use",
               let toolName = AIToolName(rawValue: block.name ?? ""),
               let id = block.id,
               let inputDict = block.input {
                // Convert input to [String: String]
                let strInput = inputDict.reduce(into: [String: String]()) { result, pair in
                    if case let .string(s) = pair.value { result[pair.key] = s }
                    else { result[pair.key] = "\(pair.value)" }
                }
                let toolCall = AIToolCall(toolUseId: id, name: toolName, input: strInput)
                return AIChatMessage(role: .assistant, content: "", toolCall: toolCall)
            }
        }
        // Normal text response
        let text = raw.content.first(where: { $0.type == "text" })?.text ?? ""
        return AIChatMessage(role: .assistant, content: text)
    }

    // MARK: - Tool Definitions

    private var aiTools: [[String: Any]] {
        [
            [
                "name": AIToolName.setAnggaran.rawValue,
                "description": "Set atau update budget (anggaran) untuk kategori pengeluaran tertentu. Gunakan kalau user minta set/ubah budget.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "kategori_nama": ["type": "string", "description": "Nama kategori yang ingin diset budgetnya"],
                        "nominal": ["type": "string", "description": "Nominal budget dalam rupiah, angka saja tanpa titik/koma"]
                    ],
                    "required": ["kategori_nama", "nominal"]
                ]
            ],
            [
                "name": AIToolName.renameKategori.rawValue,
                "description": "Ganti nama kategori transaksi. Gunakan kalau user minta rename kategori.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "nama_lama": ["type": "string", "description": "Nama kategori saat ini"],
                        "nama_baru": ["type": "string", "description": "Nama baru yang diinginkan"]
                    ],
                    "required": ["nama_lama", "nama_baru"]
                ]
            ],
            [
                "name": AIToolName.pindahKategoriTx.rawValue,
                "description": "Pindahkan transaksi-transaksi terakhir dari satu kategori ke kategori lain. Gunakan kalau user minta recategorize transaksi.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "dari_kategori": ["type": "string", "description": "Nama kategori asal"],
                        "ke_kategori":   ["type": "string", "description": "Nama kategori tujuan"],
                        "jumlah":        ["type": "string", "description": "Berapa transaksi terakhir yang dipindah, default 5"]
                    ],
                    "required": ["dari_kategori", "ke_kategori"]
                ]
            ],
            [
                "name": AIToolName.buatTransaksi.rawValue,
                "description": "Buat transaksi baru (pengeluaran atau pemasukan). Gunakan kalau user menyebut pengeluaran/pembelian/pembayaran atau penerimaan uang. Selalu ekstrak nominal, tipe, nama merchant/keterangan, pocket, dan tanggal dari konteks user.",
                "input_schema": [
                    "type": "object",
                    "properties": [
                        "nominal":       ["type": "string", "description": "Nominal transaksi dalam rupiah, angka saja tanpa titik/koma. Contoh: 87000"],
                        "tipe":          ["type": "string", "description": "Tipe transaksi: 'pengeluaran' atau 'pemasukan'"],
                        "catatan":       ["type": "string", "description": "Keterangan/nama merchant transaksi. Contoh: Chagee, Gojek, Gaji"],
                        "kategori_nama": ["type": "string", "description": "Nama kategori yang sesuai berdasarkan konteks. Inferensikan dari daftar kategori user."],
                        "pocket_nama":   ["type": "string", "description": "Nama pocket/rekening yang digunakan. Inferensikan dari kata kunci: mandiri=Mandiri/Bank Mandiri, gopay=GoPay, dll."],
                        "tanggal":       ["type": "string", "description": "Tanggal transaksi format ISO 8601: YYYY-MM-DD atau YYYY-MM-DDTHH:mm. Konversi 'kemarin', 'hari ini', 'tadi', atau tanggal spesifik sesuai konteks."]
                    ],
                    "required": ["nominal", "tipe", "tanggal"]
                ]
            ]
        ]
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(context: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        let todayISO = isoFormatter.string(from: Date())

        return """
        Lo adalah temen deket yang kebetulan ngerti banget soal keuangan. Nama lo MyFinance AI.
        Lo ngobrol pake bahasa sehari-hari anak muda Indonesia — santai, to the point, nggak kaku.

        HARI INI: \(todayISO)

        DATA KEUANGAN:
        \(context)

        CARA LO NGOBROL:
        - Pake "lo/gue", bukan "kamu/saya/Anda"
        - Singkat dan langsung ke intinya — nggak perlu basa-basi panjang
        - Kalau ada temuan menarik, bilang apa adanya kayak temen yang jujur
        - Nggak perlu formal, boleh pake kata kayak "wah", "btw", "eh", "lho", "sih", "dong"
        - Emoji boleh tapi jangan lebay — 1-2 per pesan cukup
        - Untuk investasi/aset: kasih observasi doang, jangan kasih rekomendasi beli/jual
        - Kalau user minta ubah data (budget, kategori, dll) — pake tool yang ada
        - Kalau user nyebut pengeluaran/beli sesuatu — langsung panggil tool buat_transaksi
        - "kemarin" → hari ini -1, "hari ini"/"tadi" → hari ini, jam disebutkan → sertakan di tanggal
        - Inferensikan pocket dari nama bank/ewallet (mandiri, gopay, ovo, bca, dll)
        - Inferensikan kategori dari konteks (chagee/kopi/boba → kategori makan/minuman, dll)
        - Sebelum jalanin tool, kasih tau dulu mau ngapain dalam 1 kalimat
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
        profile: UserProfile?,
        snapshots: [NetWorthSnapshot] = []
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
            let plPct = a.returnPersen   // Decimal-based, no Double roundtrip
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

        // --- Net worth trend (dari snapshot historis) ---
        let snapshotFormatter: DateFormatter = {
            let f = DateFormatter(); f.locale = Locale(identifier: "id_ID"); f.dateFormat = "MMM yyyy"; return f
        }()
        let recentSnapshots = snapshots
            .sorted { ($0.tahun, $0.bulan) < ($1.tahun, $1.bulan) }
            .suffix(6)
        var netWorthTrend = ""
        for (i, snap) in recentSnapshots.enumerated() {
            let comps = DateComponents(calendar: cal, year: snap.tahun, month: snap.bulan)
            let label = comps.date.map { snapshotFormatter.string(from: $0) } ?? "\(snap.bulan)/\(snap.tahun)"
            var deltaStr = ""
            if i > 0 {
                let prev = recentSnapshots[recentSnapshots.index(recentSnapshots.startIndex, offsetBy: i - 1)]
                let delta = snap.totalKekayaan - prev.totalKekayaan
                let sign = delta >= 0 ? "+" : ""
                deltaStr = " (\(sign)\(delta.shortFormatted))"
            }
            netWorthTrend += "  \(label): \(snap.totalKekayaan.shortFormatted)\(deltaStr)\n"
        }
        // Hitung total return jika ada >= 2 snapshot
        var totalReturnStr = ""
        if let first = recentSnapshots.first, let last = recentSnapshots.last,
           recentSnapshots.count >= 2, first.totalKekayaan > 0 {
            let totalReturn = last.totalKekayaan - first.totalKekayaan
            let totalPct = Double(truncating: (totalReturn / first.totalKekayaan * 100) as NSDecimalNumber)
            let sign = totalReturn >= 0 ? "+" : ""
            totalReturnStr = "  Total return: \(sign)\(totalReturn.shortFormatted) (\(sign)\(String(format: "%.1f%%", totalPct)))\n"
        }

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

        TREN NET WORTH (6 BULAN TERAKHIR):
        \(netWorthTrend.isEmpty ? "  Belum cukup data" : netWorthTrend)\(totalReturnStr)
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
            return "Gimana kondisi keuangan gue bulan ini? Saving rate-nya sehat nggak, pengeluaran ada yang aneh? Kasih 1 saran utama. Singkat aja, 2-3 kalimat."
        case .analisaPengeluaran:
            return "Liat pengeluaran gue bulan ini dibanding bulan-bulan sebelumnya dong. Ada kategori yang tiba-tiba melonjak? Bisa dihemat di mana? Kasih saran yang spesifik ya, bukan yang generik."
        case .analisaAset:
            return "Gimana performa aset dan investasi gue? Yang lagi bagus mana, yang perlu dipantau mana? Kalau belum ada, kasih saran mulai dari mana yang realistis. Observasi aja ya, jangan kasih rekomendasi beli/jual."
        case .wishlistForecast:
            return "Berdasarkan pola nabung gue, kira-kira kapan bisa nyampe wishlist? Kalau mau lebih cepet, harus nambah nabung berapa per bulan?"
        case .peringatan:
            return "Ada yang perlu gue waspadain nggak? Budget yang mau habis, pengeluaran yang aneh, langganan yang kayaknya nggak kepake, atau tren yang kurang bagus. Kalau semua fine, bilang aja fine."
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

private struct AnthropicRawResponse: Decodable {
    let content: [ContentBlock]

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
        let id: String?
        let name: String?
        let input: [String: JSONValue]?
    }
}

enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self)  { self = .string(s); return }
        if let n = try? c.decode(Double.self)  { self = .number(n); return }
        if let b = try? c.decode(Bool.self)    { self = .bool(b);   return }
        self = .null
    }
}
