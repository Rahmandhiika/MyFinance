import SwiftUI
import SwiftData

// MARK: - Main View

struct AIAdvisorView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Transaksi.tanggal, order: .reverse) private var allTransaksi: [Transaksi]
    @Query private var allPockets:   [Pocket]
    @Query private var allTargets:   [Target]
    @Query private var allAnggaran:  [Anggaran]
    @Query private var allAset:      [Aset]
    @Query private var allLangganan: [Langganan]
    @Query private var profiles:     [UserProfile]

    @AppStorage("anthropicAPIKey") private var apiKey: String = ""

    @State private var chatMessages:  [AIChatMessage] = []
    @State private var inputText:     String = ""
    @State private var isTyping:      Bool   = false
    @State private var insightStates: [AIInsightType: InsightState] = [:]
    @State private var showAPIKeyAlert = false

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
                                insightCardsSection
                                Divider().background(theme.separator).padding(.horizontal)
                                chatSection
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                            .id("bottom")
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
        .onAppear {
            if !apiKey.isEmpty { loadAllInsights() }
        }
    }

    // MARK: - API Key Prompt

    private var apiKeyPrompt: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.accent)
            Text("API Key Belum Diisi")
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.textPrimary)
            Text("Masukkan Anthropic API key di Pengaturan → AI untuk mulai menggunakan fitur AI.")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            NavigationLink(destination: APIKeySettingView()) {
                Label("Buka Pengaturan AI", systemImage: "gearshape.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textOnColor)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(theme.accent)
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        ZStack(alignment: .leading) {
            LinearGradient(
                colors: [Color(hex: "#1D1040"), Color(hex: "#2D1B69")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color(hex: "#A78BFA").opacity(0.15))
                .frame(width: 100, height: 100)
                .offset(x: 260, y: -20)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(hex: "#A78BFA"))
                    Text("MYFINANCE AI")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(hex: "#A78BFA"))
                        .tracking(1)
                    Spacer()
                    // Online indicator
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: "#22C55E")).frame(width: 6, height: 6)
                        Text("Online").font(.caption2.weight(.semibold)).foregroundStyle(Color(hex: "#22C55E"))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color(hex: "#22C55E").opacity(0.12))
                    .clipShape(Capsule())
                }
                Text("Asisten Keuangan\nPersonal Kamu")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineSpacing(2)
                Text("Powered by Claude Haiku · Data real-time dari app")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .frame(minHeight: 130)
    }

    // MARK: - Insight Cards

    private var insightCardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("INSIGHT BULAN INI")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .tracking(1)
                Spacer()
                Button {
                    loadAllInsights()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Refresh")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(theme.accent.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            ForEach(AIInsightType.allCases, id: \.rawValue) { type in
                AIInsightCard(
                    type: type,
                    state: insightStates[type] ?? .idle,
                    theme: theme
                ) {
                    // Tap card → kirim ke chat untuk explore lebih
                    if case .loaded(let text) = insightStates[type] {
                        let msg = AIChatMessage(role: .user, content: "Ceritakan lebih detail soal \(type.title.lowercased()) aku")
                        chatMessages.append(msg)
                        Task { await sendToAI("Ceritakan lebih detail soal \(type.title.lowercased()) aku") }
                    }
                }
            }
        }
    }

    // MARK: - Chat Section

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TANYA AI")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .tracking(1)

            if chatMessages.isEmpty {
                quickPrompts
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(chatMessages) { msg in
                        ChatBubble(message: msg, theme: theme)
                    }
                    if isTyping {
                        TypingIndicator(theme: theme)
                    }
                }
            }
        }
    }

    // MARK: - Quick Prompts

    private var quickPrompts: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mau tanya apa?")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)

            let prompts = [
                ("💰", "Berapa sisa budget minggu ini?"),
                ("🎯", "Kapan bisa beli wishlist aku?"),
                ("📉", "Kategori mana yang paling boros?"),
                ("💡", "Kasih saran hemat bulan ini"),
                ("📊", "Gimana performa investasi aku?"),
                ("🔔", "Ada yang perlu aku perhatiin?")
            ]

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(prompts, id: \.1) { emoji, text in
                    Button {
                        inputText = text
                        Task { await sendToAI(text) }
                    } label: {
                        HStack(spacing: 6) {
                            Text(emoji).font(.system(size: 14))
                            Text(text)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(theme.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(10)
                        .background(theme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
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
            HStack(spacing: 10) {
                TextField("Tanya sesuatu...", text: $inputText, axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(theme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                Button {
                    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty, !isTyping else { return }
                    inputText = ""
                    Task { await sendToAI(text) }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTyping
                                         ? theme.textSecondary.opacity(0.4) : theme.accent)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTyping)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(theme.bgApp)
        }
    }

    // MARK: - Logic

    private func loadAllInsights() {
        for type in AIInsightType.allCases {
            insightStates[type] = .loading
            Task {
                do {
                    let result = try await AnthropicService.shared.generateInsight(
                        type: type,
                        financialContext: financialContext,
                        apiKey: apiKey
                    )
                    insightStates[type] = .loaded(result)
                } catch {
                    insightStates[type] = .error(error.localizedDescription)
                }
            }
        }
    }

    private func sendToAI(_ text: String) async {
        let userMsg = AIChatMessage(role: .user, content: text)
        chatMessages.append(userMsg)
        isTyping = true

        do {
            let reply = try await AnthropicService.shared.sendMessage(
                userMessage: text,
                history: chatMessages.dropLast(),
                financialContext: financialContext,
                apiKey: apiKey
            )
            chatMessages.append(AIChatMessage(role: .assistant, content: reply))
        } catch {
            chatMessages.append(AIChatMessage(role: .assistant, content: "⚠️ \(error.localizedDescription)"))
        }

        isTyping = false
        inputText = ""
    }
}

// MARK: - Insight State

enum InsightState {
    case idle
    case loading
    case loaded(String)
    case error(String)
}

// MARK: - AI Insight Card

private struct AIInsightCard: View {
    let type: AIInsightType
    let state: InsightState
    let theme: AppTheme
    let onTap: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: type.color).opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: type.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: type.color))
                }

                Text(type.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                switch state {
                case .loading:
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(Color(hex: type.color))
                case .loaded:
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                case .error:
                    Image(systemName: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#EF4444"))
                case .idle:
                    EmptyView()
                }
            }
            .padding(14)
            .contentShape(Rectangle())
            .onTapGesture {
                if case .loaded = state {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }
            }

            // Expanded content
            if isExpanded, case .loaded(let text) = state {
                Divider().background(theme.separator).padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 10) {
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(theme.textPrimary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        onTap()
                        withAnimation { isExpanded = false }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Tanya lebih lanjut")
                                .font(.caption.weight(.semibold))
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color(hex: type.color))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color(hex: type.color).opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if case .error(let msg) = state {
                Text("Gagal: \(msg)")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#EF4444"))
                    .padding(.horizontal, 14).padding(.bottom, 10)
            }
        }
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.cardBorder, lineWidth: 1))
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: AIChatMessage
    let theme: AppTheme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                ZStack {
                    Circle().fill(Color(hex: "#A78BFA").opacity(0.2)).frame(width: 30, height: 30)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#A78BFA"))
                }
                .padding(.top, 2)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(message.role == .user ? .white : theme.textPrimary)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(
                        message.role == .user
                        ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "#A78BFA"), Color(hex: "#7C3AED")],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(theme.bgCard)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        message.role == .assistant
                        ? AnyView(RoundedRectangle(cornerRadius: 16).stroke(theme.cardBorder, lineWidth: 1))
                        : AnyView(EmptyView())
                    )

                Text(message.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textSecondary.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user {
                Circle()
                    .fill(theme.accent.opacity(0.2))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.accent)
                    )
                    .padding(.top, 2)
            }
        }
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    let theme: AppTheme
    @State private var animating = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle().fill(Color(hex: "#A78BFA").opacity(0.2)).frame(width: 30, height: 30)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#A78BFA"))
            }
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(theme.textSecondary.opacity(0.5))
                        .frame(width: 7, height: 7)
                        .offset(y: animating ? -4 : 0)
                        .animation(
                            .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(theme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardBorder, lineWidth: 1))
            Spacer()
        }
        .onAppear { animating = true }
    }
}

// MARK: - API Key Setting View

struct APIKeySettingView: View {
    @Environment(\.appTheme) private var theme
    @AppStorage("anthropicAPIKey") private var apiKey: String = ""
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
                    // Info card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill").foregroundStyle(Color(hex: "#60A5FA"))
                            Text("Cara Mendapatkan API Key")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.textPrimary)
                        }
                        Text("1. Buka console.anthropic.com\n2. Login / daftar akun\n3. Pergi ke API Keys\n4. Buat key baru dan copy")
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                            .lineSpacing(3)
                    }
                    .padding(14)
                    .background(Color(hex: "#60A5FA").opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Anthropic API Key")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.textSecondary)

                        HStack {
                            Group {
                                if isVisible {
                                    TextField("sk-ant-api03-...", text: $inputKey)
                                } else {
                                    SecureField("sk-ant-api03-...", text: $inputKey)
                                }
                            }
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(theme.textPrimary)

                            Button {
                                isVisible.toggle()
                            } label: {
                                Image(systemName: isVisible ? "eye.slash" : "eye")
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        .padding(12)
                        .background(theme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.cardBorder))

                        Text("Key tersimpan hanya di device kamu, tidak dikirim ke mana pun selain Anthropic.")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary.opacity(0.7))
                    }

                    // Test & Save buttons
                    HStack(spacing: 10) {
                        Button {
                            testAPIKey()
                        } label: {
                            HStack(spacing: 6) {
                                if case .testing = testStatus {
                                    ProgressView().scaleEffect(0.7).tint(.white)
                                } else {
                                    Image(systemName: "bolt.fill")
                                }
                                Text("Test")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color(hex: "#6B7280"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button {
                            apiKey = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                Text("Simpan")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.textOnColor)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(inputKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    // Test result
                    switch testStatus {
                    case .success:
                        resultBanner(icon: "checkmark.circle.fill", text: "API key valid! Siap digunakan.", color: "#22C55E")
                    case .failed(let msg):
                        resultBanner(icon: "xmark.circle.fill", text: msg, color: "#EF4444")
                    default:
                        EmptyView()
                    }

                    // Current key status
                    if !apiKey.isEmpty {
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: "#22C55E")).frame(width: 6, height: 6)
                            Text("Key aktif: \(String(apiKey.prefix(12)))...")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        .padding(10)
                        .background(Color(hex: "#22C55E").opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        .padding(12)
        .background(Color(hex: color).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func testAPIKey() {
        let key = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        testStatus = .testing
        Task {
            do {
                _ = try await AnthropicService.shared.sendMessage(
                    userMessage: "Balas hanya dengan kata: OK",
                    history: [],
                    financialContext: "",
                    apiKey: key
                )
                testStatus = .success
            } catch {
                testStatus = .failed(error.localizedDescription)
            }
        }
    }
}
