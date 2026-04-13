import SwiftUI
import SwiftData

struct VoiceTabView: View {
    @State private var speechService = SpeechRecognitionService()
    @State private var showReview = false
    @State private var parsedResult: ParsedResult = ParsedResult()

    // For waveform animation
    @State private var wavePhase: Bool = false

    @Query(filter: #Predicate<Pocket> { $0.isAktif }) private var pockets: [Pocket]
    @Query private var kategoris: [Kategori]

    private let waveBarCount = 7
    private let waveHeights: [CGFloat] = [12, 24, 36, 48, 36, 24, 12]

    var body: some View {
        ZStack {
            Color(hex: "#0D0D0D").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Status text + transcription area
                VStack(spacing: 16) {
                    if speechService.isRecording {
                        Text("Mendengarkan...")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(hex: "#22C55E"))
                            .transition(.opacity)
                    } else if speechService.transcribedText.isEmpty {
                        Text("Ketuk untuk mulai")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .transition(.opacity)
                    } else {
                        Text("Rekaman selesai")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .transition(.opacity)
                    }

                    // Transcription display
                    if !speechService.transcribedText.isEmpty {
                        Text(speechService.transcribedText)
                            .font(.body)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 24)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    } else if !speechService.isRecording {
                        // Example hints
                        VStack(alignment: .leading, spacing: 6) {
                            exampleRow("beli nasi uduk 15rb pake gopay")
                            exampleRow("terima gaji 5 juta")
                            exampleRow("bayar listrik 200rb dari BCA")
                        }
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: speechService.isRecording)
                .animation(.easeInOut(duration: 0.25), value: speechService.transcribedText)

                Spacer()

                // Waveform (visible only when recording)
                if speechService.isRecording {
                    waveformView
                        .frame(height: 64)
                        .padding(.bottom, 24)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                // Mic button
                micButton
                    .padding(.bottom, 16)

                // "Proses" button — shown after recording stops with text
                if !speechService.isRecording && !speechService.transcribedText.isEmpty {
                    Button {
                        triggerReview()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Proses Transaksi")
                        }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(Color(hex: "#22C55E"))
                        .clipShape(Capsule())
                        .shadow(color: Color(hex: "#22C55E").opacity(0.4), radius: 10, y: 4)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .padding(.bottom, 8)

                    Button {
                        withAnimation {
                            speechService.transcribedText = ""
                        }
                    } label: {
                        Text("Ulangi")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                    .padding(.bottom, 4)
                }

                Spacer(minLength: 40)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: speechService.isRecording)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: speechService.transcribedText.isEmpty)
        .sheet(isPresented: $showReview) {
            VoiceReviewSheet(parsed: parsedResult) {
                speechService.transcribedText = ""
                parsedResult = ParsedResult()
            }
        }
        .onChange(of: speechService.isRecording) { oldValue, newValue in
            // When recording stops automatically (silence timer) and has text
            if oldValue == true && newValue == false && !speechService.transcribedText.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    triggerReview()
                }
            }
        }
        .onAppear {
            startWaveAnimation()
        }
    }

    // MARK: - Mic button

    @ViewBuilder
    private var micButton: some View {
        Button {
            if speechService.isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            ZStack {
                // Outer pulse ring (recording only)
                if speechService.isRecording {
                    Circle()
                        .stroke(Color(hex: "#22C55E").opacity(0.25), lineWidth: 2)
                        .frame(width: 112, height: 112)
                        .scaleEffect(wavePhase ? 1.15 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                            value: wavePhase
                        )

                    Circle()
                        .stroke(Color(hex: "#22C55E").opacity(0.12), lineWidth: 2)
                        .frame(width: 130, height: 130)
                        .scaleEffect(wavePhase ? 1.1 : 0.95)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: wavePhase
                        )
                }

                // Main circle
                Circle()
                    .fill(speechService.isRecording ? Color(hex: "#22C55E") : Color.white.opacity(0.1))
                    .frame(width: 88, height: 88)
                    .shadow(
                        color: speechService.isRecording
                            ? Color(hex: "#22C55E").opacity(0.45)
                            : Color.clear,
                        radius: 16, y: 4
                    )

                Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(speechService.isRecording ? .black : Color(hex: "#22C55E"))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Waveform

    @ViewBuilder
    private var waveformView: some View {
        HStack(spacing: 5) {
            ForEach(0..<waveBarCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "#22C55E").opacity(0.8))
                    .frame(width: 4, height: animatedHeight(for: i))
                    .animation(
                        .easeInOut(duration: 0.4 + Double(i) * 0.07)
                            .repeatForever(autoreverses: true),
                        value: wavePhase
                    )
            }
        }
    }

    private func animatedHeight(for index: Int) -> CGFloat {
        let base = waveHeights[index]
        return wavePhase ? base : base * 0.35
    }

    private func startWaveAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            wavePhase = true
        }
    }

    // MARK: - Actions

    private func startRecording() {
        Task {
            await speechService.requestPermission()
            try? speechService.startRecording()
        }
    }

    private func stopRecording() {
        speechService.stopRecording()
    }

    private func triggerReview() {
        let text = speechService.transcribedText
        guard !text.isEmpty else { return }
        parsedResult = NLPParser.shared.parse(
            text: text,
            kategoris: kategoris,
            pockets: pockets
        )
        showReview = true
    }

    // MARK: - Helper views

    @ViewBuilder
    private func exampleRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: "#22C55E").opacity(0.7))
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}
