import SwiftUI

// MARK: - Goals Section (Wishlist Aktif)

struct HomeGoalsSection: View {
    let targets: [Target]
    let hideBalance: Bool
    @Environment(\.appTheme) private var theme

    private let accentCyan = Color(hex: "#06B6D4")

    private static let deadlineFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "dd MMM yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(theme.accent)
                Text("WISHLIST AKTIF")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.textSecondary)
            }
            ForEach(targets) { target in
                goalCard(target: target)
            }
        }
        .padding(.horizontal)
    }

    private func masked(_ value: String) -> String {
        hideBalance ? "••••••" : value
    }

    private func goalCard(target: Target) -> some View {
        let targetColor = Color(hex: target.warna)
        let pct = target.progressPersen
        let hasFoto = target.fotoData != nil

        return ZStack(alignment: .bottom) {
            if let data = target.fotoData, let uiImg = UIImage(data: data) {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 140)
                    .clipped()
            } else {
                theme.bgCard
            }

            if hasFoto {
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black.opacity(0.55), Color.black.opacity(0.88)],
                    startPoint: .top, endPoint: .bottom
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(hasFoto ? Color.black.opacity(0.3) : targetColor.opacity(0.2))
                            .frame(width: 36, height: 36)
                        if let emoji = target.ikonCustom {
                            Text(emoji).font(.system(size: 16))
                        } else {
                            Image(systemName: target.ikon)
                                .foregroundStyle(hasFoto ? .white : targetColor)
                                .font(.system(size: 14))
                        }
                    }
                    HStack(alignment: .center, spacing: 6) {
                        Text(target.nama)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(hasFoto ? .white : theme.textPrimary)
                            .lineLimit(1)
                            .shadow(color: hasFoto ? .black.opacity(0.6) : .clear, radius: 3)
                        if target.jenisTarget == .investasi {
                            HStack(spacing: 3) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(target.linkedAset?.tipe.displayName ?? "Investasi")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(hasFoto ? .white : theme.accent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(hasFoto ? Color.white.opacity(0.2) : theme.accent.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        Spacer()
                    }
                }

                HStack {
                    Text(String(format: "%.0f%%", pct))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(hasFoto ? .white : targetColor)
                    Text("•").font(.caption).foregroundStyle(hasFoto ? .white.opacity(0.4) : theme.textSecondary)
                    Text(masked("\(target.tersimpan.shortFormatted) / \(target.targetNominal.shortFormatted)"))
                        .font(.caption)
                        .foregroundStyle(hasFoto ? .white.opacity(0.8) : theme.textSecondary)
                }

                ProgressBarView(progress: pct / 100, color: hasFoto ? .white : targetColor, height: 6)
                    .opacity(hasFoto ? 0.85 : 1)

                if let deadline = target.deadline {
                    let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
                    let deadlineStr = Self.deadlineFormatter.string(from: deadline)

                    Text("Estimasi Kelar: \(deadlineStr) • \(daysLeft) hari")
                        .font(.caption)
                        .foregroundStyle(hasFoto ? .white.opacity(0.7) : theme.textSecondary)

                    if target.tersimpan < target.targetNominal && daysLeft > 0 {
                        let perBulan = (target.targetNominal - target.tersimpan) / Decimal(max(daysLeft / 30, 1))
                        Text("PERLU MENYISIHKAN: \(masked(perBulan.idrFormatted)) /bln")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(hasFoto ? .white : theme.accent)
                    }
                }
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.cardBorder, lineWidth: 1))
    }
}
