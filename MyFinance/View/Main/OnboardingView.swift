import SwiftUI
import SwiftData

// MARK: - Onboarding View (3 halaman)

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.appTheme)     private var theme
    @Query private var profiles: [UserProfile]

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @State private var namaUser    = ""
    @State private var pocketNama  = ""

    var body: some View {
        ZStack {
            theme.bgApp.ignoresSafeArea()

            TabView(selection: $currentPage) {
                page1.tag(0)
                page2.tag(1)
                page3.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Page indicator + nav button
            VStack {
                Spacer()
                HStack {
                    // Dots
                    HStack(spacing: 8) {
                        ForEach(0..<3) { i in
                            Capsule()
                                .fill(currentPage == i ? theme.accent : theme.separator)
                                .frame(width: currentPage == i ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    Spacer()
                    // Next / Selesai button
                    Button {
                        if currentPage < 2 {
                            withAnimation { currentPage += 1 }
                        } else {
                            finish()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(currentPage < 2 ? "Lanjut" : "Mulai")
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: currentPage < 2 ? "arrow.right" : "checkmark")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(theme.textOnColor)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(theme.accent)
                        .clipShape(Capsule())
                    }
                    .disabled(currentPage == 1 && pocketNama.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }
        }
    }

    // MARK: - Page 1: Value Proposition

    private var page1: some View {
        VStack(spacing: 32) {
            Spacer()
            // Illustration
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.12))
                    .frame(width: 160, height: 160)
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(theme.accent)
            }

            VStack(spacing: 16) {
                Text("Satu tempat untuk\nsemua uang kamu")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("Track pemasukan, pengeluaran, investasi, deposito, dan target tabungan — semuanya dalam satu dashboard.")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                featureRow(icon: "wallet.pass.fill",          color: "#3B82F6", text: "Multi-pocket — pisahkan uang per rekening")
                featureRow(icon: "briefcase.fill",            color: "#F59E0B", text: "Semua aset investasi dalam satu tempat")
                featureRow(icon: "brain.head.profile",        color: "#A78BFA", text: "AI Advisor untuk analisa keuangan personal")
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 80)
        }
    }

    // MARK: - Page 2: Setup Pocket

    private var page2: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(hex: "#3B82F6").opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color(hex: "#3B82F6"))
            }

            VStack(spacing: 12) {
                Text("Buat pocket pertama")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                Text("Pocket adalah wadah uang kamu — bisa berupa rekening bank, e-wallet, atau dompet tunai.")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("NAMA POCKET")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                    .tracking(0.5)

                TextField("Contoh: BCA, GoPay, Dompet...", text: $pocketNama)
                    .font(.subheadline)
                    .foregroundStyle(theme.textPrimary)
                    .padding(14)
                    .background(theme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                        pocketNama.isEmpty ? theme.cardBorder : theme.accent.opacity(0.5),
                        lineWidth: 1
                    ))
            }
            .padding(.horizontal, 24)

            Text("Kamu bisa tambah lebih banyak pocket nanti di tab Pocket.")
                .font(.caption)
                .foregroundStyle(theme.textSecondary.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer().frame(height: 80)
        }
    }

    // MARK: - Page 3: Siap!

    private var page3: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(theme.accent)
            }

            VStack(spacing: 12) {
                Text("Siap dimulai! 🎉")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(theme.textPrimary)

                Text("Dashboard sudah siap. Mulai catat transaksi pertama kamu atau tambah aset investasi.")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                nextStepRow(number: "1", text: "Catat pemasukan & pengeluaran harian")
                nextStepRow(number: "2", text: "Tambah aset investasi yang kamu punya")
                nextStepRow(number: "3", text: "Set target alokasi portofolio ideal")
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 80)
        }
    }

    // MARK: - Helpers

    private func featureRow(icon: String, color: String, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: color).opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(Color(hex: color))
                    .font(.system(size: 16))
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(theme.textPrimary)
            Spacer()
        }
    }

    private func nextStepRow(number: String, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(theme.accent.opacity(0.15)).frame(width: 32, height: 32)
                Text(number).font(.system(size: 14, weight: .bold)).foregroundStyle(theme.accent)
            }
            Text(text).font(.subheadline).foregroundStyle(theme.textPrimary)
            Spacer()
        }
    }

    // MARK: - Finish

    private func finish() {
        // Update nama profil jika user mengisi
        if let profile = profiles.first {
            if !namaUser.trimmingCharacters(in: .whitespaces).isEmpty {
                profile.nama = namaUser.trimmingCharacters(in: .whitespaces)
            }
        }

        // Buat pocket pertama
        let nama = pocketNama.trimmingCharacters(in: .whitespaces)
        if !nama.isEmpty {
            let pocket = Pocket(
                nama: nama,
                kelompokPocket: .biasa,
                kategoriPocket: nil,
                saldo: 0,
                catatan: nil
            )
            context.insert(pocket)
        }

        try? context.save()

        // Request notification permission
        Task { await NotificationService.shared.requestPermission() }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        hasCompletedOnboarding = true
    }
}
