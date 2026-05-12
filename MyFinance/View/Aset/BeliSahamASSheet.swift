import SwiftUI
import SwiftData

struct BeliSahamASSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    let aset: Aset

    @Query(sort: \Pocket.urutan) private var allPockets: [Pocket]
    @Query(sort: \Kategori.urutan) private var allKategori: [Kategori]

    private var nabungKategori: Kategori? {
        allKategori.first { $0.isNabung && $0.tipe == .pengeluaran }
    }

    private var usdPockets: [Pocket] { allPockets.filter { $0.isAktif && $0.saldoUSD > 0 } }

    @State private var purchaseUSD: Decimal = 0
    @State private var hargaBeliPerShare: Decimal = 0
    @State private var feeUSD: Decimal = 0
    @State private var selectedPocket: Pocket? = nil

    private let accentColor = Color(hex: "#2252BA")

    // MARK: - Computed

    private var oldShares: Decimal { aset.jumlahSharesAS }
    private var oldHarga: Decimal { aset.hargaBeliPerShareUSD ?? 0 }
    private var oldKurs: Decimal { aset.kursBeliUSD ?? 0 }
    private var oldFee: Decimal { aset.biayaFeeUSD ?? 0 }

    /// Net USD yang benar-benar dipakai beli saham (exclude fee) — sama seperti Pluang "Amount"
    private var netUSD: Decimal { max(purchaseUSD - feeUSD, 0) }

    private var newShares: Decimal {
        guard hargaBeliPerShare > 0, netUSD > 0 else { return 0 }
        return netUSD / hargaBeliPerShare   // sama persis dengan cara Pluang hitung shares
    }

    private var totalSharesAfter: Decimal { oldShares + newShares }

    private var weightedAvgHarga: Decimal {
        guard totalSharesAfter > 0 else { return oldHarga }
        return (oldShares * oldHarga + newShares * hargaBeliPerShare) / totalSharesAfter
    }

    /// Total yang keluar dari pocket USD = seluruh pembayaran termasuk fee
    private var totalUSDKeluar: Decimal { purchaseUSD }
    private var saldoUSDPocket: Decimal { selectedPocket?.saldoUSD ?? 0 }
    private var saldoCukup: Bool { totalUSDKeluar <= saldoUSDPocket }

    private var canSave: Bool {
        purchaseUSD > 0 && hargaBeliPerShare > 0
        && selectedPocket != nil && saldoCukup
    }

    private var avgTurun: Bool {
        guard newShares > 0, oldHarga > 0 else { return false }
        return weightedAvgHarga < oldHarga
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bgApp.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
                        currentHoldingSection
                        formSection
                        if newShares > 0 { previewSection }
                        pocketSection
                        saveButton
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Beli \(aset.kode ?? aset.nama)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.bgApp, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
    }

    // MARK: - Sub Views

    private var headerSection: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                if let logo = aset.logoData, let uiImg = UIImage(data: logo) {
                    Image(uiImage: uiImg)
                        .resizable().scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "globe.americas.fill")
                        .font(.title3).foregroundStyle(accentColor)
                }
            }
            Text(aset.nama).font(.headline).foregroundStyle(theme.textPrimary)
            if let kode = aset.kode, !kode.isEmpty {
                Text(kode.uppercased()).font(.caption).foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.top, 8)
    }

    private var currentHoldingSection: some View {
        VStack(spacing: 0) {
            infoRow(label: "Shares Dimiliki",
                    value: "\(oldShares.unitFormattedSmart) shares")
            Divider().background(theme.separator)
            infoRow(label: "Avg Harga Beli",
                    value: oldHarga > 0 ? "$\(oldHarga.unitFormatted(2))" : "–")
            Divider().background(theme.separator)
            infoRow(label: "Harga Saat Ini",
                    value: aset.hargaSaatIniUSD.map { "$\($0.unitFormatted(2))" } ?? "–")
        }
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("PEMBELIAN BARU").padding(.bottom, 10)

            VStack(spacing: 0) {
                // Total Amount di Pluang (sudah termasuk fee)
                formFieldInCard(label: "TOTAL AMOUNT (USD)") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("$").foregroundStyle(.gray).font(.subheadline)
                            CurrencyInputField(value: $purchaseUSD)
                        }
                        Text("Lihat \"Total Amount\" di bukti transaksi Pluang.")
                            .font(.caption2).foregroundStyle(theme.textSecondary.opacity(0.7))
                    }
                }
                Divider().background(theme.separator)
                formFieldInCard(label: "HARGA BELI / SHARE (USD)") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("$").foregroundStyle(.gray).font(.subheadline)
                            CurrencyInputField(value: $hargaBeliPerShare)
                        }
                        Text("Lihat \"Average Price\" di bukti transaksi Pluang.")
                            .font(.caption2).foregroundStyle(theme.textSecondary.opacity(0.7))
                    }
                }
                Divider().background(theme.separator)
                formFieldInCard(label: "FEE + PAJAK (USD)") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("$").foregroundStyle(.gray).font(.subheadline)
                            CurrencyInputField(value: $feeUSD)
                        }
                        Text("Transaction Fee + Taxes & Third Party Fees di Pluang.")
                            .font(.caption2).foregroundStyle(theme.textSecondary.opacity(0.7))
                        // Live net amount
                        if purchaseUSD > 0 && feeUSD > 0 {
                            HStack(spacing: 4) {
                                Text("Net beli saham:")
                                    .font(.caption2).foregroundStyle(theme.textSecondary)
                                Text("$\(netUSD.unitFormatted(2))")
                                    .font(.caption2.weight(.semibold)).foregroundStyle(accentColor)
                            }
                        }
                    }
                }
            }
            .background(theme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 16)
    }

    private var previewSection: some View {
        VStack(spacing: 0) {
            previewRow(label: "Net Beli Saham", value: "$\(netUSD.unitFormatted(2))")
            Divider().background(theme.separator)
            previewRow(label: "Shares Dibeli", value: "\(newShares.unitFormattedSmart) shares", accent: true)
            Divider().background(theme.separator)
            previewRow(label: "Total USD Keluar", value: "$\(totalUSDKeluar.unitFormatted(2))")
            Divider().background(theme.separator)
            previewRow(label: "Total Shares Setelah", value: "\(totalSharesAfter.unitFormattedSmart) shares")
            Divider().background(theme.separator)
            avgComparisonRow
        }
        .background(accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private var pocketSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("BAYAR DARI POCKET USD")
            if usdPockets.isEmpty {
                Text("⚠ Belum ada pocket dengan saldo USD")
                    .font(.caption).foregroundStyle(.orange)
            } else {
                PocketChipPicker(pockets: usdPockets, selected: $selectedPocket)
                if let pocket = selectedPocket {
                    HStack {
                        Text("Saldo USD: $\(pocket.saldoUSD.unitFormatted(2))")
                            .font(.caption).foregroundStyle(.gray)
                        Spacer()
                        if !saldoCukup && totalUSDKeluar > 0 {
                            Text("⚠ Kurang $\((totalUSDKeluar - saldoUSDPocket).unitFormatted(2))")
                                .font(.caption.weight(.semibold)).foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var saveButton: some View {
        Button { save() } label: {
            Text("Catat Pembelian")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(canSave ? .black : theme.textSecondary.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? accentColor : theme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canSave)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var avgComparisonRow: some View {
        let changeColor = Color(hex: avgTurun ? "#22C55E" : "#F59E0B")
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Avg Harga Skrg").font(.caption2).foregroundStyle(theme.textSecondary)
                Text(oldHarga > 0 ? "$\(oldHarga.unitFormatted(2))" : "–")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 3) {
                Image(systemName: avgTurun ? "arrow.down.right" : "arrow.up.right")
                    .font(.caption.weight(.bold)).foregroundStyle(changeColor)
                Text(avgTurun ? "turun" : "naik")
                    .font(.caption2).foregroundStyle(changeColor)
            }
            .frame(width: 52)

            VStack(alignment: .trailing, spacing: 3) {
                Text("Avg Harga Setelah").font(.caption2).foregroundStyle(.gray)
                Text("$\(weightedAvgHarga.unitFormatted(2))")
                    .font(.subheadline.weight(.bold)).foregroundStyle(changeColor)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func formFieldInCard<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold)).foregroundStyle(.gray).tracking(0.5)
                .padding(.horizontal, 14).padding(.top, 14)
            content()
                .padding(.horizontal, 14).padding(.bottom, 14)
        }
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(theme.textPrimary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    @ViewBuilder
    private func previewRow(label: String, value: String, accent: Bool = false) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value).font(.subheadline.weight(.bold))
                .foregroundStyle(accent ? accentColor : theme.textPrimary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.gray).tracking(0.5)
    }

    // MARK: - Save

    private func save() {
        guard let pocket = selectedPocket,
              purchaseUSD > 0, hargaBeliPerShare > 0,
              saldoCukup else { return }

        // ── Update Aset ──
        // totalInvestasiUSD = net amount (pre-fee), sama dengan definisi model
        let oldNetUSD = aset.totalInvestasiUSD ?? 0
        let newTotalInvestasiUSD = oldNetUSD + netUSD
        let newTotalFeeUSD = oldFee + feeUSD
        aset.totalInvestasiUSD = newTotalInvestasiUSD
        aset.biayaFeeUSD = newTotalFeeUSD > 0 ? newTotalFeeUSD : nil
        aset.hargaBeliPerShareUSD = weightedAvgHarga

        // Weighted avg kurs — pakai kurs tersimpan di aset, jaga modal IDR akurat
        let storedKurs = aset.kursSaatIniUSD ?? aset.kursBeliUSD ?? 0
        if storedKurs > 0 {
            let oldModalIDR = (oldNetUSD + oldFee) * (aset.kursBeliUSD ?? storedKurs)
            let newModalIDR = purchaseUSD * storedKurs   // total paid (net+fee) × kurs
            let totalUSD = newTotalInvestasiUSD + newTotalFeeUSD
            if totalUSD > 0 {
                aset.kursBeliUSD = (oldModalIDR + newModalIDR) / totalUSD
            }
        }

        // ── Potong Pocket USD (total paid termasuk fee) ──
        pocket.saldoUSD -= totalUSDKeluar   // = purchaseUSD (total)

        // ── Catat Transaksi (IDR) — jika kurs tersedia ──
        if storedKurs > 0 {
            let nominalIDR = purchaseUSD * storedKurs
            let transaksi = Transaksi(
                tanggal: Date(),
                nominal: nominalIDR,
                tipe: .pengeluaran,
                subTipe: .normal,
                pocket: pocket,
                catatan: "Beli \(aset.kode ?? aset.nama) \(newShares.unitFormattedSmart) shares @ $\(hargaBeliPerShare.unitFormatted(2))"
            )
            transaksi.kategori = nabungKategori
            context.insert(transaksi)
        }

        try? context.save()
        dismiss()
    }
}
