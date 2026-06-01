import SwiftUI
import SwiftData
import Speech

// MARK: - Main View

struct AIAdvisorView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Transaksi.tanggal, order: .reverse) private var allTransaksi: [Transaksi]
    @Query private var allPockets:    [Pocket]
    @Query private var allTargets:    [Target]
    @Query private var allAnggaran:   [Anggaran]
    @Query private var allAset:       [Aset]
    @Query private var allLangganan:  [Langganan]
    @Query private var allKategori:   [Kategori]
    @Query private var profiles:      [UserProfile]
    @Query(sort: \SavedAIInsight.savedAt, order: .reverse) private var savedInsights: [SavedAIInsight]

    // API key disimpan di Keychain — bukan UserDefaults — via APIKeyStore
    @State private var keyStore = APIKeyStore.shared
    private var apiKey: String { keyStore.apiKey }

    @State private var chatMessages:  [AIChatMessage] = []
    @State private var inputText:     String = ""
    @State private var isTyping:      Bool   = false
    @State private var insightStates: [AIInsightType: InsightState] = [:]
    @State private var showSaved:     Bool   = false
    @State private var speechService  = SpeechRecognitionService()
    @State private var micWavePhase:  Bool   = false

    private var financialContext: String {
        FinancialContextBuilder.build(
            transaksi:  allTransaksi,
            pockets:    allPockets,
            targets:    allTargets,
            anggaran:   allAnggaran,
            aset:       allAset,
            langganan:  allLangganan,
            profile:    profiles.first
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            theme.bgApp.ignoresSafeArea()
            VStack(spacing: 0) {
                if apiKey.isEmpty {
                    apiKeyPrompt
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                headerCard
                                if !savedInsights.isEmpty { savedSection }
                                insightCardsSection
                                Divider().background(theme.separator).padding(.horizontal)
                                chatSection
                                Color.clear.frame(height: 8).id("bottom")
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                        }
                        .onChange(of: chatMessages.count) { _, _ in
                            withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                        }
                    }
                    chatInputBar
                }
            }
        }
        .navigationTitle("AI Advisor")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(theme.bgApp, for: .navigationBar)
        .toolbarColorScheme(theme.colorScheme == .dark ? .dark : .light, for: .navigationBar)
        .onAppear { if !apiKey.isEmpty { loadAllInsights() } }
    }

    // MARK: - API Key Prompt

    private var apiKeyPrompt: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "key.fill").font(.system(size: 48)).foregroundStyle(theme.accent)
            Text("API Key Belum Diisi").font(.title2.weight(.bold)).foregroundStyle(theme.textPrimary)
            Text("Masukkan Anthropic API key di Pengaturan → AI untuk mulai menggunakan fitur AI.")
                .font(.subheadline).foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            NavigationLink(destination: APIKeySettingView()) {
                Label("Buka Pengaturan AI", systemImage: "gearshape.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(theme.textOnColor)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(theme.accent).clipShape(Capsule())
            }
            Spacer()
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        ZStack(alignment: .leading) {
            LinearGradient(colors: [Color(hex: "#1D1040"), Color(hex: "#2D1B69")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Color(hex: "#A78BFA").opacity(0.15)).frame(width: 100, height: 100).offset(x: 260, y: -20)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile").font(.caption.weight(.bold)).foregroundStyle(Color(hex: "#A78BFA"))
                    Text("MYFINANCE AI").font(.caption.weight(.bold)).foregroundStyle(Color(hex: "#A78BFA")).tracking(1)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: "#22C55E")).frame(width: 6, height: 6)
                        Text("Online").font(.caption2.weight(.semibold)).foregroundStyle(Color(hex: "#22C55E"))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color(hex: "#22C55E").opacity(0.12)).clipShape(Capsule())
                }
                Text("Asisten Keuangan\nPersonal Kamu").font(.title2.weight(.bold)).foregroundStyle(.white).lineSpacing(2)
                Text("Powered by Claude Haiku · Bisa ubah data langsung").font(.caption).foregroundStyle(.white.opacity(0.55))
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18)).frame(minHeight: 130)
    }

    // MARK: - Saved Insights Section

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill").font(.caption).foregroundStyle(Color(hex: "#F59E0B"))
                    Text("INSIGHT TERSIMPAN")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.textSecondary).tracking(1)
                    Text("\(savedInsights.count)")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: "#F59E0B"))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(hex: "#F59E0B").opacity(0.15)).clipShape(Capsule())
                }
                Spacer()
                Button {
                    withAnimation { showSaved.toggle() }
                } label: {
                    Image(systemName: showSaved ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(theme.textSecondary)
                }
            }

            if showSaved {
                LazyVStack(spacing: 8) {
                    ForEach(savedInsights) { insight in
                        SavedInsightRow(insight: insight, theme: theme) {
                            modelContext.delete(insight)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(Color(hex: "#F59E0B").opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#F59E0B").opacity(0.2), lineWidth: 1))
    }

    // MARK: - Insight Cards

    private var insightCardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("INSIGHT BULAN INI")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.textSecondary).tracking(1)
                Spacer()
                Button { loadAllInsights() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold))
                        Text("Refresh").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(theme.accent).padding(.horizontal, 10).padding(.vertical, 5)
                    .background(theme.accent.opacity(0.1)).clipShape(Capsule())
                }
            }
            ForEach(AIInsightType.allCases, id: \.rawValue) { type in
                AIInsightCard(type: type, state: insightStates[type] ?? .idle, theme: theme,
                    onAskMore: {
                        let prompt = "Ceritakan lebih detail soal \(type.title.lowercased()) aku"
                        Task { await sendToAI(prompt) }
                    },
                    onSave: { text in
                        let insight = SavedAIInsight(content: text, source: type.title)
                        modelContext.insert(insight)
                        withAnimation { showSaved = true }
                    }
                )
            }
        }
    }

    // MARK: - Chat Section

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TANYA AI").font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.textSecondary).tracking(1)
            if chatMessages.isEmpty {
                quickPrompts
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(chatMessages) { msg in
                        if let tc = msg.toolCall, msg.role == .assistant {
                            AIToolConfirmationCard(toolCall: tc, theme: theme,
                                onConfirm: { executeTool(tc, messageId: msg.id) },
                                onReject:  { rejectTool(tc,  messageId: msg.id) }
                            )
                        } else if !msg.isToolResult {
                            ChatBubble(message: msg, theme: theme,
                                onSave: msg.role == .assistant ? {
                                    let insight = SavedAIInsight(content: msg.content, source: "Chat")
                                    modelContext.insert(insight)
                                    withAnimation { showSaved = true }
                                } : nil
                            )
                        }
                    }
                    if isTyping { TypingIndicator(theme: theme) }
                }
            }
        }
    }

    // MARK: - Quick Prompts

    private var quickPrompts: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mau tanya apa?").font(.subheadline).foregroundStyle(theme.textSecondary)
            let prompts = [
                ("💰", "Berapa sisa budget minggu ini?"),
                ("🎯", "Kapan bisa beli wishlist aku?"),
                ("📉", "Kategori mana yang paling boros?"),
                ("💡", "Kasih saran hemat bulan ini"),
                ("📊", "Gimana performa investasi aku?"),
                ("🔔", "Ada yang perlu aku perhatiin?"),
                ("🧾", "Catat: beli kopi 35rb pake GoPay tadi"),
                ("✏️", "Ubah budget makan jadi 1,5 juta")
            ]
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(prompts, id: \.1) { emoji, text in
                    Button {
                        Task { await sendToAI(text) }
                    } label: {
                        HStack(spacing: 6) {
                            Text(emoji).font(.system(size: 14))
                            Text(text).font(.system(size: 12, weight: .medium)).foregroundStyle(theme.textPrimary).multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(10).background(theme.bgCard).clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Chat Input Bar

    private var chatInputBar: some View {
        VStack(spacing: 0) {
            Divider().background(theme.separator)

            // Live waveform saat recording
            if speechService.isRecording {
                HStack(spacing: 4) {
                    Image(systemName: "waveform").font(.caption).foregroundStyle(Color(hex: "#22C55E"))
                    Text(speechService.transcribedText.isEmpty ? "Dengerin..." : speechService.transcribedText)
                        .font(.caption).foregroundStyle(theme.textSecondary)
                        .lineLimit(1).truncationMode(.tail)
                    Spacer()
                    // Mini waveform bars
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color(hex: "#22C55E"))
                                .frame(width: 3, height: micWavePhase ? CGFloat([8,14,10,16,8][i]) : CGFloat([4,7,5,8,4][i]))
                                .animation(.easeInOut(duration: 0.35 + Double(i) * 0.08).repeatForever(autoreverses: true), value: micWavePhase)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 8) {
                // Mic button
                Button {
                    if speechService.isRecording {
                        speechService.stopRecording()
                        // Jika ada hasil, pindah ke inputText
                        if !speechService.transcribedText.isEmpty {
                            inputText = speechService.transcribedText
                            speechService.transcribedText = ""
                        }
                    } else {
                        inputText = ""
                        Task {
                            await speechService.requestPermission()
                            try? speechService.startRecording()
                            micWavePhase = true
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(speechService.isRecording ? Color(hex: "#22C55E") : theme.bgCard)
                            .frame(width: 38, height: 38)
                            .overlay(Circle().stroke(speechService.isRecording ? Color.clear : theme.cardBorder, lineWidth: 1))
                        Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(speechService.isRecording ? .black : theme.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                TextField("Tanya sesuatu...", text: $inputText, axis: .vertical)
                    .font(.subheadline).foregroundStyle(theme.textPrimary).lineLimit(1...4)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(theme.bgCard).clipShape(RoundedRectangle(cornerRadius: 22))

                Button {
                    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty, !isTyping else { return }
                    inputText = ""
                    Task { await sendToAI(text) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 34))
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTyping
                                         ? theme.textSecondary.opacity(0.4) : theme.accent)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTyping)
            }
            .padding(.horizontal, 14).padding(.vertical, 10).background(theme.bgApp)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: speechService.isRecording)
        .onChange(of: speechService.isRecording) { _, isNowRecording in
            // Saat recording berhenti otomatis (silence timer) — auto-send kalau ada teks
            if !isNowRecording && !speechService.transcribedText.isEmpty {
                let text = speechService.transcribedText
                speechService.transcribedText = ""
                micWavePhase = false
                inputText = ""
                Task { await sendToAI(text) }
            } else if !isNowRecording {
                micWavePhase = false
            }
        }
        .onChange(of: speechService.transcribedText) { _, newText in
            // Live preview di inputField saat recording
            if speechService.isRecording {
                inputText = newText
            }
        }
    }

    // MARK: - Logic: Load Insights

    private func loadAllInsights() {
        for type in AIInsightType.allCases {
            insightStates[type] = .loading
            Task {
                do {
                    let result = try await AnthropicService.shared.generateInsight(
                        type: type, financialContext: financialContext, apiKey: apiKey)
                    insightStates[type] = .loaded(result)
                } catch {
                    insightStates[type] = .error(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Logic: Send to AI

    private func sendToAI(_ text: String) async {
        let userMsg = AIChatMessage(role: .user, content: text)
        chatMessages.append(userMsg)
        isTyping = true
        do {
            let reply = try await AnthropicService.shared.sendMessage(
                userMessage: text,
                history: Array(chatMessages.dropLast()),
                financialContext: financialContext,
                apiKey: apiKey
            )
            chatMessages.append(reply)
        } catch {
            chatMessages.append(AIChatMessage(role: .assistant, content: "⚠️ \(error.localizedDescription)"))
        }
        isTyping = false
        inputText = ""
    }

    // MARK: - Logic: Tool Execution

    private func executeTool(_ toolCall: AIToolCall, messageId: UUID) {
        // Guard idempotency — hanya jalankan kalau masih .pending
        guard let idx = chatMessages.firstIndex(where: { $0.id == messageId }),
              chatMessages[idx].toolCall?.status == .pending else { return }
        chatMessages[idx].toolCall?.status = .confirmed

        var resultText = ""
        switch toolCall.name {

        case .setAnggaran:
            let katNama = toolCall.input["kategori_nama"] ?? ""
            let nominalStr = toolCall.input["nominal"] ?? "0"
            let nominal = Decimal(string: nominalStr.filter(\.isNumber)) ?? 0
            let kategori = allKategori.first { $0.nama.lowercased() == katNama.lowercased() }
            let existing = allAnggaran.first { $0.kategori?.nama.lowercased() == katNama.lowercased() }
            if let existing {
                existing.nominal = nominal
            } else {
                let new = Anggaran(nominal: nominal, tipeAnggaran: .bulanan, kategori: kategori)
                modelContext.insert(new)
            }
            try? modelContext.save()
            resultText = "Berhasil set budget '\(katNama)' menjadi \(nominal.idrFormatted)"

        case .renameKategori:
            let namaLama = toolCall.input["nama_lama"] ?? ""
            let namaBaru = toolCall.input["nama_baru"] ?? ""
            if let kat = allKategori.first(where: { $0.nama.lowercased() == namaLama.lowercased() }) {
                kat.nama = namaBaru
                try? modelContext.save()
                resultText = "Berhasil rename kategori '\(namaLama)' → '\(namaBaru)'"
            } else {
                resultText = "Kategori '\(namaLama)' tidak ditemukan"
            }

        case .pindahKategoriTx:
            let dariNama = toolCall.input["dari_kategori"] ?? ""
            let keNama   = toolCall.input["ke_kategori"]   ?? ""
            let jumlah   = Int(toolCall.input["jumlah"] ?? "5") ?? 5
            let keKat    = allKategori.first { $0.nama.lowercased() == keNama.lowercased() }
            let txToMove = allTransaksi
                .filter { $0.kategori?.nama.lowercased() == dariNama.lowercased() }
                .prefix(jumlah)
            txToMove.forEach { $0.kategori = keKat }
            try? modelContext.save()
            resultText = "Berhasil memindahkan \(txToMove.count) transaksi dari '\(dariNama)' ke '\(keNama)'"

        case .buatTransaksi:
            let nominalStr  = toolCall.input["nominal"] ?? "0"
            let nominal     = Decimal(string: nominalStr.filter(\.isNumber)) ?? 0
            let tipeStr     = toolCall.input["tipe"] ?? "pengeluaran"
            let tipe: TipeTransaksi = tipeStr == "pemasukan" ? .pemasukan : .pengeluaran
            let catatan     = toolCall.input["catatan"]
            let katNama     = toolCall.input["kategori_nama"] ?? ""
            let pocketNama  = toolCall.input["pocket_nama"] ?? ""
            let tanggalStr  = toolCall.input["tanggal"] ?? ""

            // Parse tanggal dari ISO string
            let parsedDate: Date = {
                // Try full datetime first (YYYY-MM-DDTHH:mm or YYYY-MM-DDTHH:mm:ss)
                let fullFmt = ISO8601DateFormatter()
                fullFmt.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime]
                if let d = fullFmt.date(from: tanggalStr) { return d }

                // Try with dash separator for partial ISO
                let altFmt = DateFormatter()
                altFmt.locale = Locale(identifier: "en_US_POSIX")
                for fmt in ["yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
                    altFmt.dateFormat = fmt
                    if let d = altFmt.date(from: tanggalStr) { return d }
                }
                return Date()
            }()

            // Match kategori dan pocket (fuzzy lowercase)
            let matchedKat = allKategori.first {
                !katNama.isEmpty && $0.nama.lowercased().contains(katNama.lowercased())
                    || katNama.lowercased().contains($0.nama.lowercased())
            } ?? allKategori.first { $0.nama.lowercased() == katNama.lowercased() }

            let matchedPocket: Pocket? = {
                guard !pocketNama.isEmpty else { return nil }
                let lower = pocketNama.lowercased()
                return allPockets.first { $0.nama.lowercased().contains(lower) || lower.contains($0.nama.lowercased()) }
            }()

            let newTx = Transaksi(
                tanggal:  parsedDate,
                nominal:  nominal,
                tipe:     tipe,
                kategori: matchedKat,
                pocket:   matchedPocket,
                catatan:  catatan
            )

            // Check saldo negatif sebelum mutasi
            var warnings: [String] = []
            if tipe == .pengeluaran, let pocket = matchedPocket, pocket.saldo < nominal {
                let hasilSaldo = pocket.saldo - nominal
                warnings.append("⚠️ Saldo \(pocket.nama) akan jadi \(hasilSaldo.idrFormatted) (negatif).")
            }

            // Pocket tidak ketemu tapi user nyebut nama pocket
            if matchedPocket == nil && !pocketNama.isEmpty {
                warnings.append("⚠️ Pocket '\(pocketNama)' tidak ditemukan — saldo tidak disesuaikan. Cek nama pocket di app.")
            }

            // Adjust pocket saldo
            if let pocket = matchedPocket {
                if tipe == .pengeluaran { pocket.saldo -= nominal }
                else                   { pocket.saldo += nominal }
            }

            modelContext.insert(newTx)
            try? modelContext.save()

            let df = DateFormatter(); df.locale = Locale(identifier: "id_ID"); df.dateFormat = "d MMM yyyy, HH:mm"
            let katLabel    = matchedKat?.nama    ?? (katNama.isEmpty ? "-" : katNama)
            let pocketLabel = matchedPocket?.nama ?? (pocketNama.isEmpty ? "tidak dipilih" : "\(pocketNama) (tidak ditemukan)")
            let warningNote = warnings.isEmpty ? "" : " | \(warnings.joined(separator: " "))"
            resultText = "Berhasil membuat transaksi: \(catatan ?? "Tanpa catatan") \(nominal.idrFormatted) (\(tipeStr)) · \(katLabel) · \(pocketLabel) · \(df.string(from: parsedDate))\(warningNote)"
        }

        // Mark as executed
        if let idx = chatMessages.firstIndex(where: { $0.id == messageId }) {
            chatMessages[idx].toolCall?.status = .executed
        }

        // Add tool result ke history (hidden) lalu lanjut conversation
        let resultMsg = AIChatMessage(role: .user, content: resultText, isToolResult: true)
        chatMessages.append(resultMsg)

        isTyping = true
        Task {
            do {
                let followUp = try await AnthropicService.shared.continueAfterTool(
                    history: chatMessages,
                    toolCall: toolCall,
                    resultText: resultText,
                    financialContext: financialContext,
                    apiKey: apiKey
                )
                chatMessages.append(followUp)
            } catch {
                chatMessages.append(AIChatMessage(role: .assistant, content: "✅ \(resultText)"))
            }
            isTyping = false
        }
    }

    private func rejectTool(_ toolCall: AIToolCall, messageId: UUID) {
        if let idx = chatMessages.firstIndex(where: { $0.id == messageId }) {
            chatMessages[idx].toolCall?.status = .rejected
        }
        let rejectMsg = AIChatMessage(role: .user, content: "Tidak jadi, batalkan.", isToolResult: true)
        chatMessages.append(rejectMsg)
        Task { await sendToAI("Oke, batalkan dulu.") }
    }
}

// MARK: - Insight State

enum InsightState {
    case idle, loading
    case loaded(String)
    case error(String)
}

// MARK: - AI Insight Card

private struct AIInsightCard: View {
    let type: AIInsightType
    let state: InsightState
    let theme: AppTheme
    let onAskMore: () -> Void
    let onSave: (String) -> Void
    @State private var isExpanded = false
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color(hex: type.color).opacity(0.15)).frame(width: 38, height: 38)
                    Image(systemName: type.icon).font(.system(size: 16)).foregroundStyle(Color(hex: type.color))
                }
                Text(type.title).font(.subheadline.weight(.semibold)).foregroundStyle(theme.textPrimary)
                Spacer()
                switch state {
                case .loading:
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.separator)
                        .frame(width: 80, height: 14)
                        .shimmer()
                case .loaded:
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(theme.textSecondary)
                case .error:
                    Image(systemName: "exclamationmark.circle").font(.caption).foregroundStyle(Color(hex: "#EF4444"))
                case .idle: EmptyView()
                }
            }
            .padding(14).contentShape(Rectangle())
            .onTapGesture {
                if case .loaded = state {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isExpanded.toggle() }
                }
            }

            if isExpanded, case .loaded(let text) = state {
                Divider().background(theme.separator).padding(.horizontal, 14)
                VStack(alignment: .leading, spacing: 10) {
                    Text(text).font(.subheadline).foregroundStyle(theme.textPrimary).lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Button { onAskMore(); withAnimation { isExpanded = false } } label: {
                            HStack(spacing: 4) {
                                Text("Tanya lebih lanjut").font(.caption.weight(.semibold))
                                Image(systemName: "arrow.right").font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(Color(hex: type.color)).padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color(hex: type.color).opacity(0.1)).clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            guard !saved else { return }
                            onSave(text); saved = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: saved ? "bookmark.fill" : "bookmark")
                                    .font(.caption.weight(.semibold))
                                Text(saved ? "Tersimpan" : "Simpan").font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(saved ? Color(hex: "#F59E0B") : theme.textSecondary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background((saved ? Color(hex: "#F59E0B") : theme.separator).opacity(0.15))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14).transition(.opacity.combined(with: .move(edge: .top)))
            }

            if case .error(let msg) = state {
                Text("Gagal: \(msg)").font(.caption).foregroundStyle(Color(hex: "#EF4444"))
                    .padding(.horizontal, 14).padding(.bottom, 10)
            }
        }
        .background(theme.bgCard).clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.cardBorder, lineWidth: 1))
    }
}

// MARK: - AI Tool Confirmation Card

private struct AIToolConfirmationCard: View {
    let toolCall: AIToolCall
    let theme: AppTheme
    let onConfirm: () -> Void
    let onReject: () -> Void

    var body: some View {
        let isDone = toolCall.status == .executed || toolCall.status == .rejected || toolCall.status == .confirmed

        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Color(hex: "#A78BFA").opacity(0.15)).frame(width: 32, height: 32)
                    Image(systemName: "brain.head.profile").font(.system(size: 14)).foregroundStyle(Color(hex: "#A78BFA"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI ingin melakukan perubahan").font(.caption.weight(.semibold)).foregroundStyle(theme.textSecondary)
                    HStack(spacing: 4) {
                        Image(systemName: toolCall.name.icon).font(.system(size: 11))
                        Text(toolCall.name.displayName).font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Color(hex: "#A78BFA"))
                }
                Spacer()
                if toolCall.status == .executed {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: "#22C55E"))
                } else if toolCall.status == .rejected {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(theme.textSecondary.opacity(0.5))
                }
            }

            // Parameters
            VStack(alignment: .leading, spacing: 4) {
                ForEach(toolCall.input.sorted(by: { $0.key < $1.key }), id: \.key) { key, val in
                    HStack(spacing: 6) {
                        Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.textSecondary)
                            .frame(width: 100, alignment: .leading)
                        Text(val).font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.textPrimary)
                    }
                }
            }
            .padding(10).background(theme.separator.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 8))

            if !isDone {
                HStack(spacing: 8) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onReject()
                    } label: {
                        Text("Batalkan").font(.subheadline.weight(.semibold)).foregroundStyle(theme.textSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(theme.separator).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    Button {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        onConfirm()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                            Text("Jalankan")
                        }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color(hex: "#22C55E")).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack(spacing: 6) {
                    if toolCall.status == .confirmed {
                        ProgressView().scaleEffect(0.7).tint(Color(hex: "#22C55E"))
                        Text("Sedang dijalankan...").font(.caption.weight(.semibold)).foregroundStyle(theme.textSecondary)
                    } else {
                        Text(toolCall.status == .executed ? "✅ Perubahan berhasil dijalankan" : "❌ Dibatalkan")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(toolCall.status == .executed ? Color(hex: "#22C55E") : theme.textSecondary)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(hex: "#A78BFA").opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#A78BFA").opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: AIChatMessage
    let theme: AppTheme
    var onSave: (() -> Void)?
    @State private var saved = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                ZStack {
                    Circle().fill(Color(hex: "#A78BFA").opacity(0.2)).frame(width: 30, height: 30)
                    Image(systemName: "brain.head.profile").font(.system(size: 13)).foregroundStyle(Color(hex: "#A78BFA"))
                }
                .padding(.top, 2)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(message.role == .user ? .white : theme.textPrimary)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        message.role == .user
                        ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "#A78BFA"), Color(hex: "#7C3AED")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(theme.bgCard)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        message.role == .assistant
                        ? AnyView(RoundedRectangle(cornerRadius: 16).stroke(theme.cardBorder, lineWidth: 1))
                        : AnyView(EmptyView())
                    )

                // Bookmark button untuk pesan AI
                if message.role == .assistant, let onSave {
                    Button {
                        guard !saved else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSave(); saved = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: saved ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 10, weight: .semibold))
                            Text(saved ? "Tersimpan" : "Simpan")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(saved ? Color(hex: "#F59E0B") : theme.textSecondary.opacity(0.6))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background((saved ? Color(hex: "#F59E0B") : theme.separator).opacity(0.2))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Text(message.timestamp, style: .time)
                    .font(.system(size: 10)).foregroundStyle(theme.textSecondary.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user {
                Circle().fill(theme.accent.opacity(0.2)).frame(width: 30, height: 30)
                    .overlay(Image(systemName: "person.fill").font(.system(size: 13)).foregroundStyle(theme.accent))
                    .padding(.top, 2)
            }
        }
    }
}

// MARK: - Shimmer Modifier

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear,                         location: 0),
                            .init(color: .white.opacity(0.35),           location: 0.4),
                            .init(color: .clear,                         location: 0.8)
                        ],
                        startPoint: .init(x: phase, y: 0),
                        endPoint:   .init(x: phase + 0.8, y: 0)
                    )
                    .blendMode(.overlay)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

private extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    let theme: AppTheme
    @State private var animating = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle().fill(Color(hex: "#A78BFA").opacity(0.2)).frame(width: 30, height: 30)
                Image(systemName: "brain.head.profile").font(.system(size: 13)).foregroundStyle(Color(hex: "#A78BFA"))
            }
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle().fill(theme.textSecondary.opacity(0.5)).frame(width: 7, height: 7)
                        .offset(y: animating ? -4 : 0)
                        .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: animating)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(theme.bgCard).clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardBorder, lineWidth: 1))
            Spacer()
        }
        .onAppear { animating = true }
    }
}

// MARK: - Saved Insight Row

private struct SavedInsightRow: View {
    let insight: SavedAIInsight
    let theme: AppTheme
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bookmark.fill").font(.system(size: 12)).foregroundStyle(Color(hex: "#F59E0B")).padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(insight.source).font(.caption.weight(.semibold)).foregroundStyle(Color(hex: "#F59E0B"))
                    Spacer()
                    Text(insight.savedAt, style: .date).font(.caption2).foregroundStyle(theme.textSecondary.opacity(0.6))
                }
                Text(insight.content).font(.caption).foregroundStyle(theme.textSecondary).lineLimit(3).lineSpacing(2)
            }
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onDelete()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.textSecondary.opacity(0.5))
                    // Perbesar hit area ke 44×44pt (Apple HIG minimum)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(10).background(theme.bgCard).clipShape(RoundedRectangle(cornerRadius: 10))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onDelete()
            } label: {
                Label("Hapus", systemImage: "trash")
            }
        }
    }
}

// MARK: - API Key Setting View

struct APIKeySettingView: View {
    @Environment(\.appTheme) private var theme
    // API key disimpan di Keychain via APIKeyStore — bukan UserDefaults
    @State private var keyStore = APIKeyStore.shared
    private var apiKey: String { keyStore.apiKey }
    @State private var inputKey = ""
    @State private var isVisible = false
    @State private var testStatus: TestStatus = .idle
    @Environment(\.dismiss) private var dismiss

    enum TestStatus { case idle, testing, success, failed(String) }

    var body: some View {
        ZStack {
            theme.bgApp.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill").foregroundStyle(Color(hex: "#60A5FA"))
                            Text("Cara Mendapatkan API Key").font(.subheadline.weight(.semibold)).foregroundStyle(theme.textPrimary)
                        }
                        Text("1. Buka console.anthropic.com\n2. Login / daftar akun\n3. Pergi ke API Keys\n4. Buat key baru dan copy")
                            .font(.subheadline).foregroundStyle(theme.textSecondary).lineSpacing(3)
                    }
                    .padding(14).background(Color(hex: "#60A5FA").opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Anthropic API Key").font(.subheadline.weight(.semibold)).foregroundStyle(theme.textSecondary)
                        HStack {
                            Group {
                                if isVisible { TextField("sk-ant-api03-...", text: $inputKey) }
                                else { SecureField("sk-ant-api03-...", text: $inputKey) }
                            }
                            .font(.system(size: 13, design: .monospaced)).foregroundStyle(theme.textPrimary)
                            Button { isVisible.toggle() } label: {
                                Image(systemName: isVisible ? "eye.slash" : "eye").foregroundStyle(theme.textSecondary)
                            }
                        }
                        .padding(12).background(theme.bgCard).clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder))
                        Text("Key tersimpan hanya di device kamu, tidak dikirim ke mana pun selain Anthropic.")
                            .font(.caption).foregroundStyle(theme.textSecondary.opacity(0.7))
                    }

                    HStack(spacing: 10) {
                        Button { testAPIKey() } label: {
                            HStack(spacing: 6) {
                                if case .testing = testStatus { ProgressView().scaleEffect(0.7).tint(.white) }
                                else { Image(systemName: "bolt.fill") }
                                Text("Test")
                            }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color(hex: "#6B7280")).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button {
                            keyStore.apiKey = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            dismiss()
                        } label: {
                            HStack(spacing: 6) { Image(systemName: "checkmark"); Text("Simpan") }
                                .font(.subheadline.weight(.semibold)).foregroundStyle(theme.textOnColor)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(theme.accent).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    switch testStatus {
                    case .success:
                        resultBanner(icon: "checkmark.circle.fill", text: "API key valid! Siap digunakan.", color: "#22C55E")
                    case .failed(let msg):
                        resultBanner(icon: "xmark.circle.fill", text: msg, color: "#EF4444")
                    default: EmptyView()
                    }

                    if !apiKey.isEmpty {
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: "#22C55E")).frame(width: 6, height: 6)
                            Text("Key aktif: \(String(apiKey.prefix(12)))...")
                                .font(.caption).foregroundStyle(theme.textSecondary)
                        }
                        .padding(10).background(Color(hex: "#22C55E").opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Pengaturan AI")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { inputKey = apiKey }
    }

    private func resultBanner(icon: String, text: String, color: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color(hex: color))
            Text(text).font(.subheadline).foregroundStyle(theme.textPrimary)
        }
        .padding(12).background(Color(hex: color).opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func testAPIKey() {
        let key = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        testStatus = .testing
        Task {
            do {
                _ = try await AnthropicService.shared.sendMessage(
                    userMessage: "Balas hanya dengan kata: OK",
                    history: [], financialContext: "", apiKey: key)
                testStatus = .success
            } catch {
                testStatus = .failed(error.localizedDescription)
            }
        }
    }
}
