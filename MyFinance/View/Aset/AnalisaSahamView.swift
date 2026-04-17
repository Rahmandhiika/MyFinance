import SwiftUI
import SwiftData

// MARK: - State per saham

private enum AnalisisState {
    case loading
    case success(HasilAnalisa)
    case error(String)
}

// MARK: - Main View

struct AnalisaSahamView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Aset.urutan)]) private var allAset: [Aset]

    @State private var states: [String: AnalisisState] = [:]
    @State private var showDetail = false
    @State private var detailAset: Aset? = nil
    @State private var detailHasil: HasilAnalisa? = nil

    private var sahamAset: [Aset] {
        allAset.filter { $0.tipe == .saham && !($0.kode ?? "").isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()

                if sahamAset.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(sahamAset) { aset in
                                AnalisaCard(
                                    aset: aset,
                                    state: states[aset.kode?.uppercased() ?? ""] ?? .loading
                                ) {
                                    if case .success(let hasil) = states[aset.kode?.uppercased() ?? ""] {
                                        detailAset = aset
                                        detailHasil = hasil
                                        showDetail = true
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Analisa Saham")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Tutup") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await fetchAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .sheet(isPresented: $showDetail) {
                if let aset = detailAset, let hasil = detailHasil {
                    AnalisaSahamDetailSheet(aset: aset, hasil: hasil)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await fetchAll() }
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
                        await MainActor.run { states[kode] = .error(e.localizedDescription ?? "Error") }
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
                .foregroundStyle(.white.opacity(0.2))
            Text("Belum ada saham IDX")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
            Text("Tambah saham dengan kode bursa (BBCA, BBRI, dll)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Analisa Card

private struct AnalisaCard: View {
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
                Text(aset.nama).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                Text(aset.kode?.uppercased() ?? "").font(.caption2).foregroundStyle(.gray)
            }
            Spacer()
            ProgressView().tint(.white).scaleEffect(0.8)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Error

    private func errorRow(msg: String) -> some View {
        HStack(spacing: 14) {
            asetIcon
            VStack(alignment: .leading, spacing: 4) {
                Text(aset.nama).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
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
        .background(Color.white.opacity(0.05))
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
                        .foregroundStyle(.white)
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

                    // Score dots
                    HStack(spacing: 3) {
                        ForEach(0..<4, id: \.self) { i in
                            Circle()
                                .fill(i < hasil.score ? color : Color.white.opacity(0.15))
                                .frame(width: 6, height: 6)
                        }
                        Text("\(hasil.score)/4")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.leading, 2)
                    }
                }
            }
            .padding(16)

            Divider().background(Color.white.opacity(0.06))

            // Quick stats
            HStack(spacing: 0) {
                quickStat(label: "Harga", value: formatRupiah(hasil.hargaSaatIni))
                Divider().background(Color.white.opacity(0.06)).frame(height: 28)
                quickStat(label: "EMA20", value: formatRupiah(hasil.ema20),
                          ok: hasil.hargaDiAtasEMA20)
                Divider().background(Color.white.opacity(0.06)).frame(height: 28)
                quickStat(label: "RSI14",
                          value: String(format: "%.1f", hasil.rsi14),
                          ok: hasil.rsiDiAtas50)
            }
            .padding(.vertical, 10)

            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.2))
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
                .foregroundStyle(.white.opacity(0.4))
            HStack(spacing: 3) {
                if let ok {
                    Image(systemName: ok ? "checkmark" : "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(ok ? Color(hex: "#22C55E") : Color(hex: "#EF4444"))
                }
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
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

    private func formatRupiah(_ val: Double) -> String {
        let n = NSNumber(value: val)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.locale = Locale(identifier: "id_ID")
        return "Rp\(f.string(from: n) ?? "-")"
    }
}

// MARK: - Detail Sheet

struct AnalisaSahamDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
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
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        headerCard
                        posisiKamu
                        kondisiTeknikal
                        ringkasan
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle(aset.kode?.uppercased() ?? aset.nama)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Tutup") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .preferredColorScheme(.dark)
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
                        .foregroundStyle(.white)
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
                                .fill(i < hasil.score ? color : Color.white.opacity(0.12))
                                .frame(width: 18, height: 6)
                        }
                    }
                }
            }

            Divider().background(Color.white.opacity(0.08))

            HStack(spacing: 0) {
                statItem(label: "Harga Kini", value: formatRp(hasil.hargaSaatIni))
                Divider().background(Color.white.opacity(0.08)).frame(height: 36)
                statItem(label: "EMA 20", value: formatRp(hasil.ema20))
                Divider().background(Color.white.opacity(0.08)).frame(height: 36)
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
                rowItem(label: "Rata-rata Harga Beli", value: formatRp(Double(truncating: avgBeli as NSDecimalNumber)))
                sep
                rowItem(label: "Modal", value: Decimal(0).idrFormatted.replacingOccurrences(of: "Rp", with: "Rp ")
                    .replacingOccurrences(of: "Rp ", with: ""))
                    .overlay(
                        HStack {
                            Spacer()
                            Text(modal.idrFormatted).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        }.padding(.trailing, 16)
                    )
                sep
                rowPnl(pnl: pnl, pct: pnlPct)
            }
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: Kondisi Teknikal

    private var kondisiTeknikal: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("KONDISI TEKNIKAL")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.gray)
                    .tracking(0.5)
                Spacer()
                Text("Score \(hasil.score)/4")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
            }

            VStack(spacing: 0) {
                kondisiRow(
                    ok:     hasil.hargaDiAtasEMA20,
                    label:  "Harga di atas EMA20",
                    detail: "\(formatRp(hasil.hargaSaatIni)) vs EMA \(formatRp(hasil.ema20))",
                    penjelasan: hasil.hargaDiAtasEMA20
                        ? "Harga saham sedang di atas rata-rata 20 hari — tren naik."
                        : "Harga di bawah EMA20, tren masih cenderung turun."
                )
                sep
                kondisiRow(
                    ok:     hasil.rsiDiAtas50,
                    label:  "RSI 14 di atas 50",
                    detail: String(format: "RSI: %.1f", hasil.rsi14),
                    penjelasan: rsiPenjelasan(hasil.rsi14)
                )
                sep
                kondisiRow(
                    ok:     hasil.volumeDiAtasAvg,
                    label:  "Volume di atas rata-rata 20 hari",
                    detail: "\(formatVol(hasil.volume)) vs avg \(formatVol(hasil.avgVolume20))",
                    penjelasan: hasil.volumeDiAtasAvg
                        ? "Volume hari ini tinggi — ada minat beli yang kuat."
                        : "Volume rendah — kurang ada konfirmasi dari pelaku pasar."
                )
                sep
                kondisiRow(
                    ok:     hasil.candleBullish,
                    label:  "Candle bullish",
                    detail: hasil.candleBullish ? "Close > Open" : "Close ≤ Open",
                    penjelasan: hasil.candleBullish
                        ? "Candle hari ini ditutup lebih tinggi dari pembukaan — momentum positif."
                        : "Candle merah hari ini — tekanan jual masih dominan."
                )
            }
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func kondisiRow(ok: Bool, label: String, detail: String, penjelasan: String) -> some View {
        let okColor = Color(hex: ok ? "#22C55E" : "#EF4444")
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(okColor.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: ok ? "checkmark" : "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(okColor)
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(ok ? label : label)
                        .font(.subheadline)
                        .foregroundStyle(ok ? .white : .white.opacity(0.5))
                        .strikethrough(!ok, color: .white.opacity(0.3))
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Text(penjelasan)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 56)
                .padding(.bottom, 12)
        }
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
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(color.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 1))

            Text("Ini bukan saran investasi. Selalu lakukan riset sendiri sebelum mengambil keputusan.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.25))
                .padding(.top, 4)
        }
    }

    // MARK: Helpers

    private var sep: some View {
        Divider().background(Color.white.opacity(0.06)).padding(.leading, 16)
    }

    private func rowItem(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func rowPnl(pnl: Decimal, pct: Double) -> some View {
        let pos = pnl >= 0
        let c   = Color(hex: pos ? "#22C55E" : "#EF4444")
        return HStack {
            Text("Unrealized P&L")
                .font(.subheadline).foregroundStyle(.white.opacity(0.6))
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
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.4))
            Text(value).font(.caption.weight(.bold)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatRp(_ val: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.locale = Locale(identifier: "id_ID")
        return "Rp\(f.string(from: NSNumber(value: val)) ?? "-")"
    }

    private func formatVol(_ val: Double) -> String {
        if val >= 1_000_000 { return String(format: "%.1fM", val / 1_000_000) }
        if val >= 1_000     { return String(format: "%.0fK", val / 1_000) }
        return String(format: "%.0f", val)
    }

    private func rsiPenjelasan(_ rsi: Double) -> String {
        switch rsi {
        case ..<30:  return String(format: "RSI %.1f — oversold, potensi rebound tapi konfirmasi dulu.", rsi)
        case 30..<50: return String(format: "RSI %.1f — masih di area bearish, momentum belum kuat.", rsi)
        case 50..<70: return String(format: "RSI %.1f — zona bullish, momentum positif.", rsi)
        default:     return String(format: "RSI %.1f — overbought, waspadai potensi koreksi.", rsi)
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
