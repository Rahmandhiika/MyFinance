import SwiftUI
import SwiftData

struct TargetDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let target: Target

    @State private var showAddTransaksi = false

    private var targetColor: Color { Color(hex: target.warna) }

    private var sortedRiwayat: [SimpanKeTarget] {
        target.riwayat.sorted { $0.tanggal > $1.tanggal }
    }

    private var deadlineFormatted: String {
        guard let deadline = target.deadline else { return "-" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "id_ID")
        return f.string(from: deadline)
    }

    var body: some View {
        ZStack {
            Color(hex: "#0D0D0D").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Handle bar
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 36, height: 4)
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                    // Header
                    VStack(spacing: 12) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(targetColor.opacity(0.2))
                                .frame(width: 60, height: 60)
                            if let emoji = target.ikonCustom, !emoji.isEmpty {
                                Text(emoji)
                                    .font(.system(size: 28))
                            } else {
                                Image(systemName: target.ikon)
                                    .font(.system(size: 26))
                                    .foregroundStyle(targetColor)
                            }
                        }

                        Text(target.nama)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("Tabungan")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(targetColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(targetColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .padding(.bottom, 24)

                    // Detail rows
                    VStack(spacing: 1) {
                        detailRow(label: "TARGET", value: target.targetNominal.idrFormatted, valueColor: .white)
                        detailRow(label: "TARGET KAPAN TERCAPAI?", value: deadlineFormatted, valueColor: .white)
                        detailRow(label: "TERSIMPAN", value: target.tersimpan.idrFormatted, valueColor: Color(hex: "#22D3EE"))
                        detailRow(label: "SISA", value: target.sisa.idrFormatted, valueColor: Color(hex: "#22D3EE"))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                    // Progress bar section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("PROGRESS")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.gray)
                                .tracking(0.5)
                            Spacer()
                            Text(String(format: "%.1f%%", target.progressPersen))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(targetColor)
                        }
                        ProgressBarView(progress: min(target.progressPersen / 100.0, 1.0), color: targetColor, height: 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                    // Tarik button
                    Button {
                        showAddTransaksi = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 18))
                            Text("Simpan ke Target")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#22D3EE"), Color(hex: "#22C55E")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)

                    // Transactions section
                    if !target.riwayat.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TRANSAKSI")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.gray)
                                .tracking(0.5)
                                .padding(.horizontal, 16)

                            VStack(spacing: 1) {
                                ForEach(sortedRiwayat) { record in
                                    riwayatRow(record)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 24)
                    } else {
                        VStack(spacing: 8) {
                            Text("TRANSAKSI")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.gray)
                                .tracking(0.5)
                            Text("Belum ada riwayat simpan")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }

                    Spacer(minLength: 32)
                }
            }

            // Dismiss button overlay
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }
                Spacer()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAddTransaksi) {
            AddEditTransaksiSheet(
                prefilledSubTipe: .simpanKeTarget,
                prefilledTargetID: target.id
            )
        }
    }

    // MARK: - Detail Row

    @ViewBuilder
    private func detailRow(label: String, value: String, valueColor: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.gray)
                .tracking(0.4)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.05))
    }

    // MARK: - Riwayat Row

    @ViewBuilder
    private func riwayatRow(_ record: SimpanKeTarget) -> some View {
        let isSaldoAwal = record.catatan == "Saldo awal"
        let isPenyesuaian = record.catatan == "Penyesuaian manual"
        let isSpecial = isSaldoAwal || isPenyesuaian
        let rowColor: Color = isSaldoAwal ? Color(hex: "#A78BFA") : isPenyesuaian ? Color(hex: "#F59E0B") : targetColor

        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(rowColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: isSaldoAwal ? "flag.fill" : isPenyesuaian ? "pencil.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(rowColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isSpecial ? (record.catatan ?? "") : target.nama)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    if !isSpecial {
                        Text("Simpan ke Target")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(rowColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(rowColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text(record.tanggal.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }

            Spacer()

            Text("\(record.nominal >= 0 ? "+" : "")\(record.nominal.idrFormatted)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(record.nominal >= 0 ? Color(hex: "#22D3EE") : Color(hex: "#EF4444"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
    }
}
