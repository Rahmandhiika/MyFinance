import SwiftUI
import SwiftData

// MARK: - State per saham

private enum AnalisisState {
    case loading
    case success(HasilAnalisa)
    case error(String)
}

// MARK: - Shared formatters

private func formatRp(_ val: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    f.locale = Locale(identifier: "id_ID")
    return "Rp\(f.string(from: NSNumber(value: val)) ?? "-")"
}

// MARK: - Detail Item (Identifiable wrapper — fixes blank black sheet bug)

private struct AnalisaDetailItem: Identifiable {
    let id = UUID()
    let aset: Aset
    let hasil: HasilAnalisa
}

// MARK: - Main View

struct AnalisaSahamView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Query(sort: [SortDescriptor(\Aset.urutan)]) private var allAset: [Aset]

    @State private var states: [String: AnalisisState] = [:]
    @State private var detailItem: AnalisaDetailItem? = nil

    private var sahamAset: [Aset] {
        allAset.filter { $0.tipe == .saham && !($0.kode ?? "").isEmpty }
    }

    var body: some View {
        ZStack {
            theme.bgApp.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom header — tanpa NavigationStack
                HStack {
                    Button("Tutup") { dismiss() }
                        .font(.body)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text("Analisa Saham")
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Button {
                        Task { await fetchAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider().background(theme.separator)

                if sahamAset.isEmpty {
                    emptyState
                } else {
                    ScrollView(.vertical) {
                        VStack(spacing: 12) {
                            ForEach(sahamAset) { aset in
                                AnalisaCard(
                                    aset: aset,
                                    state: states[aset.kode?.uppercased() ?? ""] ?? .loading
                                ) {
                                    if case .success(let hasil) = states[aset.kode?.uppercased() ?? ""] {
                                        detailItem = AnalisaDetailItem(aset: aset, hasil: hasil)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
        .task { await fetchAll() }
        .sheet(item: $detailItem) { item in
            AnalisaSahamDetailSheet(aset: item.aset, hasil: item.hasil)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func fetchAll() async {
        await withTaskGroup(of: Void.self) { group in
            for aset in sahamAset {
                let kode = (aset.kode ?? "").uppercased()
                guard !kode.isEmpty else { continue }
                await MainActor.run { states[kode] = .loading }
                group.addTask {
                    do {
                        let hasil = try await StockAnalysisService.shared.analisa(kode: kode)
                        await MainActor.run { states[kode] = .success(hasil) }
                    } catch let e as AnalisisError {
                        await MainActor.run { states[kode] = .error(e.localizedDescription) }
                    } catch {
                        await MainActor.run { states[kode] = .error("Tidak ada koneksi internet") }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 40))
                .foregroundStyle(theme.textSecondary.opacity(0.5))
            Text("Belum ada saham IDX")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
            Text("Tambah saham dengan kode bursa (BBCA, BBRI, dll)")
                .font(.caption)
                .foregroundStyle(theme.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Analisa Card

private struct AnalisaCard: View {
    @Environment(\.appTheme) private var theme
    let aset: Aset
    let state: AnalisisState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                switch state {
                case .loading:
                    loadingRow
                case .success(let hasil):
                    successRow(hasil: hasil)
                case .error(let msg):
                    errorRow(msg: msg)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled({ if case .success = state { return false }; return true }())
    }

    // MARK: Loading

    private var loadingRow: some View {
        HStack(spacing: 14) {
            asetIcon
            VStack(alignment: .leading, spacing: 4) {
                Text(aset.nama).font(.subheadline.weight(.semibold)).foregroundStyle(theme.textPrimary)
                Text(aset.kode?.uppercased() ?? "").font(.caption2).foregroundStyle(.gray)
            }
            Spacer()
            ProgressView().tint(theme.textSecondary).scaleEffect(0.8)
        }
        .padding(16)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Error

    private func errorRow(msg: String) -> some View {
        HStack(spacing: 14) {
            asetIcon
            VStack(alignment: .leading, spacing: 4) {
                Text(aset.nama).font(.subheadline.weight(.semibold)).foregroundStyle(theme.textPrimary)
                Text(aset.kode?.uppercased() ?? "").font(.caption2).foregroundStyle(.gray)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "wifi.slash")
                    .font(.caption)
                Text(msg)
                    .font(.caption2)
            }
            .foregroundStyle(Color(hex: "#EF4444").opacity(0.8))
        }
        .padding(16)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Success

    private func successRow(hasil: HasilAnalisa) -> some View {
        let sinyal = hasil.sinyal
        let color  = Color(hex: sinyal.hexColor)

        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                asetIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text(aset.nama)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                    Text(aset.kode?.uppercased() ?? "")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    // Signal badge
                    Text(sinyal.label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.15))
                        .clipShape(Capsule())

                    // Score segments
                    HStack(spacing: 3) {
                        ForEach(0..<4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i < hasil.score ? color : theme.cardBorder)
                                .frame(width: 14, height: 5)
                        }
                        Text("\(hasil.score)/4")
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                            .padding(.leading, 2)
                    }
                }
            }
            .padding(16)

            Divider().background(theme.separator)

            // Quick stats
            HStack(spacing: 0) {
                quickStat(label: "Harga", value: formatRp(hasil.hargaSaatIni))
                Divider().background(theme.separator).frame(height: 28)
                quickStat(label: "EMA20", value: formatRp(hasil.ema20),
                          ok: hasil.hargaDiAtasEMA20)
                Divider().background(theme.separator).frame(height: 28)
                quickStat(label: "RSI14",
                          value: String(format: "%.1f", hasil.rsi14),
                          ok: hasil.rsiDiAtas50)
            }
            .padding(.vertical, 10)

            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundStyle(theme.textSecondary.opacity(0.5))
                .padding(.bottom, 10)
        }
        .background(color.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    private func quickStat(label: String, value: String, ok: Bool? = nil) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
            HStack(spacing: 3) {
                if let ok {
                    Image(systemName: ok ? "checkmark" : "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(ok ? Color(hex: "#22C55E") : Color(hex: "#EF4444"))
                }
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var asetIcon: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#3B82F6").opacity(0.15))
                .frame(width: 40, height: 40)
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "#3B82F6"))
        }
    }

}

// MARK: - Detail Sheet

struct AnalisaSahamDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    let aset: Aset
    let hasil: HasilAnalisa

    private let sinyal: SinyalAnalisa
    private let color: Color

    init(aset: Aset, hasil: HasilAnalisa) {
        self.aset   = aset
        self.hasil  = hasil
        self.sinyal = hasil.sinyal
        self.color  = Color(hex: hasil.sinyal.hexColor)
    }

    var body: some View {
        ZStack {
            theme.bgApp.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom header — tanpa NavigationStack agar tidak ada horizontal pop gesture
                HStack {
                    Button("Tutup") { dismiss() }
                        .font(.body)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text(aset.kode?.uppercased() ?? aset.nama)
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    // Balance spacer agar title tetap center
                    Text("Tutup").font(.body).opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider().background(theme.separator)

                ScrollView(.vertical) {
                    VStack(spacing: 20) {
                        headerCard
                        posisiKamu
                        sinyalTeknikal
                        ringkasan
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
    }

    // MARK: Header

    private var headerCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#3B82F6").opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "chart.bar.fill")
                        .font(.title3)
                        .foregroundStyle(Color(hex: "#3B82F6"))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(aset.nama)
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                    Text(aset.kode?.uppercased() ?? "")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text(sinyal.label)
                        .font(.title3.weight(.black))
                        .foregroundStyle(color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(color.opacity(0.15))
                        .clipShape(Capsule())

                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i < hasil.score ? color : theme.cardBorder)
                                .frame(width: 18, height: 6)
                        }
                    }
                }
            }

            Divider().background(theme.separator)

            HStack(spacing: 0) {
                statItem(label: "Harga Kini", value: formatRp(hasil.hargaSaatIni))
                Divider().background(theme.separator).frame(height: 36)
                statItem(label: "EMA 20", value: formatRp(hasil.ema20))
                Divider().background(theme.separator).frame(height: 36)
                statItem(label: "RSI 14", value: String(format: "%.1f", hasil.rsi14))
            }
        }
        .padding(16)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: Posisi Kamu

    private var posisiKamu: some View {
        let lot = NSDecimalNumber(decimal: aset.lot ?? 0).intValue
        let avgBeli = aset.hargaPerLembar ?? 0
        let modal = aset.modal
        let nilaiKini = aset.nilaiSaatIni
        let pnl = nilaiKini - modal
        let pnlPct: Double = modal > 0
            ? Double(truncating: (pnl / modal * 100) as NSDecimalNumber)
            : 0

        return VStack(alignment: .leading, spacing: 12) {
            Text("POSISI KAMU")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.gray)
                .tracking(0.5)

            VStack(spacing: 0) {
                rowItem(label: "Lot Dimiliki", value: "\(lot) lot (\(lot * 100) lembar)")
                sep
                rowItem(label: "Rata-rata Harga Beli",
                        value: formatRp(Double(truncating: avgBeli as NSDecimalNumber)))
                sep
                rowItem(label: "Modal", value: modal.idrFormatted)
                sep
                rowPnl(pnl: pnl, pct: pnlPct)
            }
            .background(theme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: Sinyal Teknikal (redesigned)

    private var sinyalTeknikal: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("SINYAL TEKNIKAL")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.gray)
                    .tracking(0.5)
                Spacer()
                Text("Score \(hasil.score)/4")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
            }

            // 2x2 metric grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricCard(
                    label: "Harga Kini",
                    value: formatRp(hasil.hargaSaatIni),
                    sub: hasil.hargaDiAtasEMA20 ? "Di atas EMA20 ↑" : "Di bawah EMA20 ↓",
                    ok: hasil.hargaDiAtasEMA20
                )
                metricCard(
                    label: "EMA 20",
                    value: formatRp(hasil.ema20),
                    sub: "Rata-rata 20 hari",
                    ok: nil
                )
                metricCard(
                    label: "RSI 14",
                    value: String(format: "%.1f", hasil.rsi14),
                    sub: rsiLabel(hasil.rsi14),
                    ok: hasil.rsiDiAtas50
                )
                metricCard(
                    label: "Volume",
                    value: formatVol(hasil.volume),
                    sub: "Avg \(formatVol(hasil.avgVolume20))",
                    ok: hasil.volumeDiAtasAvg
                )
            }

            // Kondisi checklist
            VStack(spacing: 0) {
                kondisiItem(ok: hasil.hargaDiAtasEMA20, label: "Harga di atas EMA20")
                Divider().background(theme.separator).padding(.leading, 44)
                kondisiItem(ok: hasil.rsiDiAtas50, label: "RSI 14 di atas 50")
                Divider().background(theme.separator).padding(.leading, 44)
                kondisiItem(ok: hasil.volumeDiAtasAvg, label: "Volume di atas rata-rata 20 hari")
                Divider().background(theme.separator).padding(.leading, 44)
                kondisiItem(ok: hasil.candleBullish, label: "Candle bullish (Close > Open)")
            }
            .background(theme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Score bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Skor Teknikal")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text("\(hasil.score) dari 4 kondisi terpenuhi")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                }
                HStack(spacing: 5) {
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(i < hasil.score ? color : theme.separator)
                            .frame(maxWidth: .infinity)
                            .frame(height: 10)
                    }
                }
            }
            .padding(14)
            .background(theme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func metricCard(label: String, value: String, sub: String, ok: Bool?) -> some View {
        let cardColor: Color = ok.map { $0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444") }
            ?? theme.textSecondary
        let bgColor: Color = ok.map { $0 ? Color(hex: "#22C55E").opacity(0.08) : Color(hex: "#EF4444").opacity(0.08) }
            ?? theme.bgCard

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                if let ok {
                    Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(cardColor)
                }
            }
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(sub)
                .font(.caption2)
                .foregroundStyle(cardColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardColor.opacity(ok != nil ? 0.2 : 0.1), lineWidth: 1)
        )
    }

    private func kondisiItem(ok: Bool, label: String) -> some View {
        let okColor = Color(hex: ok ? "#22C55E" : "#EF4444")
        return HStack(spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(okColor)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(ok ? theme.textPrimary : theme.textSecondary)
                .strikethrough(!ok, color: theme.textSecondary.opacity(0.4))

            Spacer()

            Text("+1")
                .font(.caption.weight(.bold))
                .foregroundStyle(ok ? okColor : theme.textSecondary.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(ok ? okColor.opacity(0.12) : theme.separator)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: Ringkasan

    private var ringkasan: some View {
        let msg = ringkasanPesan(sinyal: sinyal, score: hasil.score)
        return VStack(alignment: .leading, spacing: 8) {
            Text("KESIMPULAN")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.gray)
                .tracking(0.5)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: sinyalIcon(sinyal))
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 32)
                Text(msg)
                    .font(.subheadline)
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(color.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 1))

            Text("Ini bukan saran investasi. Selalu lakukan riset sendiri sebelum mengambil keputusan.")
                .font(.caption2)
                .foregroundStyle(theme.textSecondary.opacity(0.6))
                .padding(.top, 4)
        }
    }

    // MARK: Helpers

    private var sep: some View {
        Divider().background(theme.separator).padding(.leading, 16)
    }

    private func rowItem(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(theme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func rowPnl(pnl: Decimal, pct: Double) -> some View {
        let pos = pnl >= 0
        let c   = Color(hex: pos ? "#22C55E" : "#EF4444")
        return HStack {
            Text("Unrealized P&L")
                .font(.subheadline).foregroundStyle(theme.textSecondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(pos ? "+" : "")\(pnl.idrFormatted)")
                    .font(.subheadline.weight(.bold)).foregroundStyle(c)
                Text(String(format: "%+.2f%%", pct))
                    .font(.caption2.weight(.semibold)).foregroundStyle(c.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(theme.textSecondary)
            Text(value).font(.caption.weight(.bold)).foregroundStyle(theme.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatVol(_ val: Double) -> String {
        if val >= 1_000_000 { return String(format: "%.1fM", val / 1_000_000) }
        if val >= 1_000     { return String(format: "%.0fK", val / 1_000) }
        return String(format: "%.0f", val)
    }

    private func rsiLabel(_ rsi: Double) -> String {
        switch rsi {
        case ..<30:  return "Oversold"
        case 30..<50: return "Bearish zone"
        case 50..<70: return "Bullish zone"
        default:     return "Overbought"
        }
    }

    private func sinyalIcon(_ s: SinyalAnalisa) -> String {
        switch s {
        case .beli: return "arrow.up.circle.fill"
        case .hold: return "pause.circle.fill"
        case .jual: return "arrow.down.circle.fill"
        }
    }

    private func ringkasanPesan(sinyal: SinyalAnalisa, score: Int) -> String {
        switch sinyal {
        case .beli:
            return "Secara teknikal \(aset.kode?.uppercased() ?? aset.nama) menunjukkan sinyal positif dengan \(score) dari 4 kondisi terpenuhi. Momentum sedang mendukung untuk akumulasi, namun perhatikan manajemen risiko."
        case .hold:
            return "\(aset.kode?.uppercased() ?? aset.nama) dalam kondisi netral dengan \(score) kondisi terpenuhi. Belum ada sinyal kuat untuk menambah atau mengurangi posisi saat ini."
        case .jual:
            return "Kondisi teknikal \(aset.kode?.uppercased() ?? aset.nama) kurang mendukung — hanya \(score) dari 4 kondisi terpenuhi. Pertimbangkan untuk mengevaluasi posisi atau menunggu konfirmasi pembalikan."
        }
    }
}
