import SwiftUI
import SwiftData

struct VoiceTabView: View {
    @State private var speechService = SpeechRecognitionService()
    @State private var showReview = false
    @State private var frozenText = ""
    @Query(filter: #Predicate<Pocket> { $0.isAktif }) private var pockets: [Pocket]

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    if speechService.transcribedText.isEmpty && !speechService.isRecording {
                        VStack(spacing: 8) {
                            Text("Katakan transaksi Anda")
                                .font(.title3.weight(.semibold))
                            Text("Contoh: \"beli nasi uduk 10rb pake gopay\"")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    } else if speechService.isRecording {
                        VStack(spacing: 8) {
                            Text("Mendengarkan...")
                                .font(.headline)
                                .foregroundStyle(.red)
                            if !speechService.transcribedText.isEmpty {
                                Text(speechService.transcribedText)
                                    .font(.title3.weight(.medium))
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    } else {
                        Text(speechService.transcribedText)
                            .font(.title3.weight(.medium))
                            .multilineTextAlignment(.center)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                if !speechService.isRecording {
                    Button {
                        startVoice()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 80, height: 80)
                                .shadow(color: Color.blue.opacity(0.4), radius: 12, y: 4)
                            Image(systemName: "mic.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                    }
                } else {
                    Button {
                        stopAndReview()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 80, height: 80)
                                .shadow(color: Color.red.opacity(0.4), radius: 12, y: 4)

                            Circle()
                                .stroke(Color.red.opacity(0.3), lineWidth: 3)
                                .frame(width: 100, height: 100)
                                .scaleEffect(1.2)
                                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: speechService.isRecording)

                            Image(systemName: "stop.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                    }
                }

                if !speechService.transcribedText.isEmpty && !speechService.isRecording {
                    Button {
                        frozenText = speechService.transcribedText
                        showReview = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Proses Transaksi")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .clipShape(Capsule())
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Contoh:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\"beli kopi 25rb\"").font(.caption).foregroundStyle(.secondary)
                        Text("\"terima gaji 5 juta\"").font(.caption).foregroundStyle(.secondary)
                        Text("\"transfer 500rb ke BCA\"").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Voice Input")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showReview) {
                VoiceReviewSheet(transcribedText: frozenText) {
                    speechService.transcribedText = ""
                    frozenText = ""
                }
            }
            .onChange(of: speechService.isRecording) { oldValue, newValue in
                if oldValue == true && newValue == false && !speechService.transcribedText.isEmpty {
                    frozenText = speechService.transcribedText
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showReview = true
                    }
                }
            }
        }
    }

    private func startVoice() {
        Task {
            await speechService.requestPermission()
            try? speechService.startRecording()
        }
    }

    private func stopAndReview() {
        let text = speechService.transcribedText
        speechService.stopRecording()
        if !text.isEmpty {
            frozenText = text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showReview = true
            }
        }
    }
}
