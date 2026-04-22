import SwiftUI
import SwiftData

struct TargetDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let target: Target

    @State private var showAddTransaksi = false
    @State private var showEditAset = false
    @State private var showUpdateNAV = false
    @State private var navInput = ""

    private var targetColor: Color { Color(hex: target.warna) }
    private var isInvestasi: Bool { target.jenisTarget == .investasi }
    private var linkedAset: Aset? { target.linkedAset }

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

                        // Jenis target badge
                        HStack(spacing: 5) {
                            Image(systemName: target.jenisTarget.icon)
                                .font(.caption.weight(.semibold))
                            Text(target.jenisTarget.displayName)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(targetColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(targetColor.opacity(0.15))
                        .clipShape(Capsule())

                        // Aset tipe badge (investasi only)
                        if isInvestasi, let aset = linkedAset {
                            Text(aset.tipe.displayName)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.bottom, 24)

                    // Detail rows
                    if isInvestasi, let aset = linkedAset {
                        investasiDetailRows(aset: aset)
                    } else {
                        biasaDetailRows
                    }

                    // Progress bar
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

                    // Action buttons
                    if isInvestasi {
                        investasiActionButtons
                    } else {
                        biasaActionButton
                    }

                    // Riwayat (biasa only)
                    if !isInvestasi {
                        riwayatSection
                    }

                    Spacer(minLength: 32)
                }
            }

            // Dismiss button overlay
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
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
        .sheet(isPresented: $showEditAset) {
            if let aset = linkedAset {
                AddEditAsetView(existingAset: aset, mode: .edit)
            }
        }
        .alert("Update NAV Reksadana", isPresented: $showUpdateNAV) {
            TextField("NAV per unit (Rp)", text: $navInput)
                .keyboardType(.decimalPad)
            Button("Simpan") { saveNAV() }
            Button("Batal", role: .cancel) { navInput = "" }
        } message: {
            if let aset = linkedAset {
                Text("NAV saat ini: \(aset.navSaatIni?.idrFormatted ?? "-")\nMasukkan NAV terbaru per unit.")
            }
        }
    }

    // MARK: - Biasa Detail Rows

    @ViewBuilder
    private var biasaDetailRows: some View {
        VStack(spacing: 1) {
            detailRow(label: "TARGET", value: target.targetNominal.idrFormatted, valueColor: .white)
            detailRow(label: "DEADLINE", value: deadlineFormatted, valueColor: .white)

            // Pocket linked
            if let pocket = target.linkedPocket {
                HStack {
                    Text("SIMPAN DI")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.gray)
                        .tracking(0.4)
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "folder.fill")
                            .font(.caption.weight(.semibold))
                        Text(pocket.nama)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Color(hex: "#A78BFA"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.05))
            }

            detailRow(label: "TERSIMPAN", value: target.tersimpan.idrFormatted, valueColor: Color(hex: "#22D3EE"))
            detailRow(label: "SISA", value: target.sisa.idrFormatted, valueColor: Color(hex: "#22D3EE"))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Investasi Detail Rows

    @ViewBuilder
    private func investasiDetailRows(aset: Aset) -> some View {
        VStack(spacing: 1) {
            detailRow(label: "TARGET", value: target.targetNominal.idrFormatted, valueColor: .white)
            detailRow(label: "DEADLINE", value: deadlineFormatted, valueColor: .white)
            detailRow(label: "MODAL (BIAYA MASUK)", value: aset.modal.idrFormatted, valueColor: .white)
            detailRow(label: "NILAI SAAT INI", value: aset.nilaiEfektif.idrFormatted, valueColor: Color(hex: "#22D3EE"))

            let pnl = aset.pnl
            let pnlColor: Color = pnl >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444")
            let pnlPrefix = pnl >= 0 ? "+" : ""
            detailRow(label: "P&L", value: "\(pnlPrefix)\(pnl.idrFormatted)", valueColor: pnlColor)

            let ret = aset.returnPersen
            let retColor: Color = ret >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444")
            let retPrefix = ret >= 0 ? "+" : ""
            detailRow(label: "RETURN", value: String(format: "\(retPrefix)%.2f%%", ret), valueColor: retColor)

            detailRow(label: "SISA MENUJU TARGET", value: target.sisa.idrFormatted, valueColor: Color(hex: "#F59E0B"))

            // Deposito extra info
            if aset.tipe == .deposito {
                detailRow(label: "JATUH TEMPO", value: aset.jatuhTempoDeposito.map { formatDate($0) } ?? "-", valueColor: .white)
                detailRow(label: "SISA HARI", value: "\(aset.hariLagiDeposito) hari", valueColor: .white)
                detailRow(label: "BUNGA BERSIH S/D HARI INI", value: aset.bungaBersihDeposito.idrFormatted, valueColor: Color(hex: "#22C55E"))
            }

            // Reksadana extra info
            if aset.tipe == .reksadana {
                if let nav = aset.navSaatIni {
                    detailRow(label: "NAV SAAT INI", value: nav.idrFormatted, valueColor: .white)
                }
                let units = aset.estimasiUnitReksadana
                if units > 0 {
                    detailRow(label: "ESTIMASI UNIT", value: "\(units.unitFormatted(4)) unit", valueColor: .white)
                }
            }

            // Saham extra info
            if aset.tipe == .saham {
                if let lot = aset.lot {
                    detailRow(label: "LOT", value: "\(lot.unitFormatted(0)) lot", valueColor: .white)
                }
                if let harga = aset.hargaPerLembar {
                    detailRow(label: "HARGA BELI/LEMBAR", value: harga.idrFormatted, valueColor: .white)
                }
            }

            // Saham AS extra info
            if aset.tipe == .sahamAS {
                if let totalUSD = aset.totalInvestasiUSD {
                    detailRow(label: "TOTAL INVESTASI (USD)", value: "$\(totalUSD.unitFormatted(2))", valueColor: .white)
                }
                let shares = aset.jumlahSharesAS
                if shares > 0 {
                    detailRow(label: "JUMLAH SHARES", value: "\(shares.unitFormatted(4))", valueColor: .white)
                }
            }

            // Valas extra info
            if aset.tipe == .valas {
                if let jml = aset.jumlahValas, let mata = aset.mataUangValas {
                    detailRow(label: "JUMLAH VALAS", value: "\(mata.rawValue) \(jml.unitFormatted(2))", valueColor: .white)
                }
                if let kurs = aset.kursSaatIni {
                    detailRow(label: "KURS SAAT INI", value: kurs.idrFormatted, valueColor: .white)
                }
            }

            // Emas extra info
            if aset.tipe == .emas {
                if let berat = aset.beratGram {
                    detailRow(label: "BERAT", value: "\(berat.unitFormatted(2)) gram", valueColor: .white)
                }
                if let harga = aset.hargaBeliPerGram {
                    detailRow(label: "HARGA BELI/GRAM", value: harga.idrFormatted, valueColor: .white)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var biasaActionButton: some View {
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
    }

    @ViewBuilder
    private var investasiActionButtons: some View {
        VStack(spacing: 10) {
            // Edit aset button
            Button {
                showEditAset = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 18))
                    Text("Edit Investasi")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#22C55E"), Color(hex: "#16A34A")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Update NAV (reksadana only)
            if linkedAset?.tipe == .reksadana {
                Button {
                    if let nav = linkedAset?.navSaatIni {
                        navInput = "\(nav)"
                    } else {
                        navInput = ""
                    }
                    showUpdateNAV = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16))
                        Text("Update NAV")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Color(hex: "#22C55E"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#22C55E").opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "#22C55E").opacity(0.3), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Riwayat Section

    @ViewBuilder
    private var riwayatSection: some View {
        if !target.riwayat.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("RIWAYAT SIMPAN")
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
                Text("RIWAYAT SIMPAN")
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
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "id_ID")
        return f.string(from: date)
    }

    private func saveNAV() {
        guard let aset = linkedAset else { return }
        guard let navValue = Decimal(string: navInput.replacingOccurrences(of: ",", with: ".")) else { return }
        aset.navSaatIni = navValue
        // Recalculate nilaiSaatIni = estimasi unit × nav saat ini
        let units = aset.estimasiUnitReksadana
        aset.nilaiSaatIni = units * navValue
        try? context.save()
        navInput = ""
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
