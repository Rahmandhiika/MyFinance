import SwiftUI
import SwiftData

struct VoiceTabView: View {
    @State private var speechService = SpeechRecognitionService()
    @State private var showReview = false
    @State private var permissionDenied = false
    @Query(filter: #Predicate<Pocket> { $0.isAktif }) private var pockets: [Pocket]

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Transcription area
                VStack(spacing: 16) {
                    if speechService.transcribedText.isEmpty {
                        VStack(spacing: 8) {
                            Text("Katakan transaksi Anda")
                                .font(.title3.weight(.semibold))
                            Text("Contoh: \"beli nasi uduk 10rb pake gopay\"")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
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

                // Mic button
                Button {
                    if speechService.isRecording {
                        speechService.stopRecording()
                    } else {
                        Task {
                            await speechService.requestPermission()
                            try? speechService.startRecording()
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(speechService.isRecording ? Color.red : Color.blue)
                            .frame(width: 80, height: 80)
                            .shadow(color: (speechService.isRecording ? Color.red : Color.blue).opacity(0.4), radius: 12, y: 4)

                        if speechService.isRecording {
                            Circle()
                                .stroke(Color.red.opacity(0.3), lineWidth: 3)
                                .frame(width: 100, height: 100)
                                .scaleEffect(speechService.isRecording ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 1).repeatForever(), value: speechService.isRecording)
                        }

                        Image(systemName: speechService.isRecording ? "stop.fill" : "mic.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }

                // Process button
                if !speechService.transcribedText.isEmpty && !speechService.isRecording {
                    Button {
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

                // Examples
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contoh:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        exampleRow("\"beli kopi 25rb\"")
                        exampleRow("\"terima gaji 5 juta\"")
                        exampleRow("\"transfer 500rb ke BCA\"")
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
                VoiceReviewSheet(transcribedText: speechService.transcribedText) {
                    speechService.transcribedText = ""
                }
            }
        }
    }

    private func exampleRow(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
