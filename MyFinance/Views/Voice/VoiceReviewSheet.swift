import SwiftUI
import SwiftData

struct VoiceReviewSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Account> { !$0.isArchived }) private var accounts: [Account]

    @State private var speechService = SpeechRecognitionService()
    @State private var parsedTransaction: ParsedTransaction? = nil
    @State private var showReview = false
    @State private var permissionDenied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Status
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(speechService.isRecording ? Color.red.opacity(0.15) : Color.blue.opacity(0.1))
                            .frame(width: 120, height: 120)
                            .scaleEffect(speechService.isRecording ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: speechService.isRecording)

                        Image(systemName: speechService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(speechService.isRecording ? .red : .blue)
                    }
                    .onTapGesture { toggleRecording() }

                    Text(speechService.isRecording ? "Ketuk untuk stop" : "Ketuk untuk mulai")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Transcription
                if !speechService.transcribedText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hasil Transkripsi:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(speechService.transcribedText)
                            .font(.body)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)

                    if !speechService.isRecording {
                        Button("Proses Transaksi") {
                            let parsed = NLPParser.shared.parse(
                                text: speechService.transcribedText,
                                accounts: accounts
                            )
                            parsedTransaction = parsed
                            showReview = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(spacing: 8) {
                        Text("Contoh:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Group {
                            Text("\"Beli kopi dua puluh ribu pakai gopay\"")
                            Text("\"Transfer lima ratus ribu ke BCA dari Mandiri\"")
                            Text("\"Gajian lima juta masuk BCA\"")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Voice Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Tutup") { dismiss() }
                }
            }
            .sheet(isPresented: $showReview) {
                if let parsed = parsedTransaction {
                    AddEditTransactionView(existingTransaction: nil, prefilled: parsed)
                }
            }
            .onDisappear {
                if speechService.isRecording { speechService.stopRecording() }
            }
            .task {
                let granted = await speechService.requestPermission()
                permissionDenied = !granted
            }
            .alert("Izin Diperlukan", isPresented: $permissionDenied) {
                Button("OK") { dismiss() }
            } message: {
                Text("Voice input memerlukan izin Speech Recognition. Aktifkan di Settings > Privacy.")
            }
        }
    }

    private func toggleRecording() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            try? speechService.startRecording()
        }
    }
}
