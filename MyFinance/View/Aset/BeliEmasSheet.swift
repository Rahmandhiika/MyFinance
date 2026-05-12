import SwiftUI
import SwiftData

struct BeliEmasSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    let aset: Aset

    @Query(sort: \Pocket.urutan) private var allPockets: [Pocket]
    @Query(sort: \Kategori.urutan) private var allKategori: [Kategori]

    private var nabungKategori: Kategori? {
        allKategori.first { $0.isNabung && $0.tipe == .pengeluaran }
    }

    private var isDigital: Bool { aset.jenisEmas?.isDigital ?? true }

    // Digital emas form
    @State private var totalDibayar: Decimal = 0
    @State private var pajak: Decimal = 0
    @State private var hargaBeliPerGram: Decimal = 0

    // Fisik emas form
    @State private var beratTambahText = ""
    @State private var hargaBeliPerGramFisik: Decimal = 0

    @State private var selectedPocket: Pocket? = nil

    private let accentColor = Color(hex: "#EAB308")

    // MARK: - Computed

    private var oldBerat: Decimal { aset.beratGram ?? 0 }
    private var oldHarga: Decimal { aset.hargaBeliPerGram ?? 0 }
    private var oldPajak: Decimal { aset.pajakBeliEmas ?? 0 }

    // Gram yang akan dibeli (digital)
    private var nilaiEmasDigital: Decimal { totalDibayar - pajak }
    private var newBeratDigital: Decimal {
        guard hargaBeliPerGram > 0 else { return 0 }
        return nilaiEmasDigital / hargaBeliPerGram
    }

    // Gram yang akan dibeli (fisik)
    private var newBeratFisik: Decimal {
        Decimal(string: beratTambahText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var newBerat: Decimal { isDigital ? newBeratDigital : newBeratFisik }
    private var newHarga: Decimal { isDigital ? hargaBeliPerGram : hargaBeliPerGramFisik }
    private var totalBeratSetelah: Decimal { oldBerat + newBerat }

    private var weightedAvgHarga: Decimal {
        guard totalBeratSetelah > 0 else { return oldHarga }
        return (oldBerat * oldHarga + newBerat * newHarga) / totalBeratSetelah
    }

    private var avgTurun: Bool {
        guard newBerat > 0, oldHarga > 0 else { return false }
        return weightedAvgHarga < oldHarga
    }

    // Total yang keluar dari pocket
    private var nominalPocket: Decimal { isDigital ? totalDibayar : newBeratFisik * hargaBeliPerGramFisik }

    private var canSave: Bool {
        guard selectedPocket != nil else { return false }
        if isDigital { return totalDibayar > 0 && hargaBeliPerGram > 0 && newBeratDigital > 0 }
        return newBeratFisik > 0 && hargaBeliPerGramFisik > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bgApp.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {

                        // Header
                        headerSection

                        // Info kepemilikan saat ini
                        currentHoldingSection

                        // Form input
                        if isDigital {
                            digitalFormSection
                        } else {
                            fisikFormSection
                        }

                        // Preview
                        if newBerat > 0 {
                            previewSection
                        }

                        // Pocket
                        pocketSection

                        // Simpan
                        saveButton
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Beli \(aset.jenisEmas?.displayName ?? "Emas")")
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
                Image(systemName: isDigital ? "star.circle.fill" : "circle.hexagongrid.fill")
                    .font(.title3).foregroundStyle(accentColor)
            }
            Text(aset.nama)
                .font(.headline).foregroundStyle(theme.textPrimary)
            Text(isDigital ? "Emas Digital" : "Emas Fisik")
                .font(.caption).foregroundStyle(theme.textSecondary)
        }
        .padding(.top, 8)
    }

    private var currentHoldingSection: some View {
        VStack(spacing: 0) {
            infoRow(label: "Berat Dimiliki", value: "\(oldBerat.unitFormatted(4)) gram")
            Divider().background(theme.separator)
            infoRow(label: "Avg Harga Beli/Gram",
                    value: oldHarga > 0 ? oldHarga.idrDecimalFormatted : "–")
            if isDigital {
                Divider().background(theme.separator)
                infoRow(label: "Total Pajak/Spread",
                        value: oldPajak > 0 ? oldPajak.idrFormatted : "–")
            }
        }
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    private var digitalFormSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("PEMBELIAN BARU")
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                formFieldInCard(label: "TOTAL DIBAYAR (IDR)") {
                    HStack(spacing: 6) {
                        Text("Rp").foregroundStyle(.gray).font(.subheadline)
                        CurrencyInputField(value: $totalDibayar)
                    }
                }
                Divider().background(theme.separator)
                formFieldInCard(label: "PAJAK / SPREAD (IDR)") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Rp").foregroundStyle(.gray).font(.subheadline)
                            CurrencyInputField(value: $pajak)
                        }
                        Text("Selisih antara yang dibayar dan nilai emas yang diterima.")
                            .font(.caption2).foregroundStyle(theme.textSecondary.opacity(0.7))
                    }
                }
                Divider().background(theme.separator)
                formFieldInCard(label: "HARGA BELI / GRAM (IDR)") {
                    HStack(spacing: 6) {
                        Text("Rp").foregroundStyle(.gray).font(.subheadline)
                        CurrencyInputField(value: $hargaBeliPerGram)
                    }
                }

                // Auto-hitung gram
                if totalDibayar > 0 && hargaBeliPerGram > 0 {
                    Divider().background(theme.separator)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ESTIMASI GRAM BARU")
                                .font(.caption2).foregroundStyle(.gray).tracking(0.6)
                            Text("\(newBeratDigital.unitFormatted(4)) gram")
                                .font(.subheadline.weight(.bold)).foregroundStyle(accentColor)
                        }
                        Spacer()
                        Text("(\(totalDibayar.idrFormatted) − \(pajak.idrFormatted)) ÷ \(hargaBeliPerGram.idrFormatted)")
                            .font(.caption2).foregroundStyle(theme.textSecondary.opacity(0.7))
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                }
            }
            .background(theme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 16)
    }

    private var fisikFormSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("PEMBELIAN BARU")
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                formFieldInCard(label: "BERAT TAMBAHAN (GRAM)") {
                    TextField("Contoh: 1,5", text: $beratTambahText)
                        .keyboardType(.decimalPad)
                        .foregroundStyle(theme.textPrimary)
                }
                Divider().background(theme.separator)
                formFieldInCard(label: "HARGA BELI / GRAM (IDR)") {
                    HStack(spacing: 6) {
                        Text("Rp").foregroundStyle(.gray).font(.subheadline)
                        CurrencyInputField(value: $hargaBeliPerGramFisik)
                    }
                }
                if newBeratFisik > 0 && hargaBeliPerGramFisik > 0 {
                    Divider().background(theme.separator)
                    HStack {
                        Text("TOTAL PENGELUARAN")
                            .font(.caption2).foregroundStyle(.gray).tracking(0.6)
                        Spacer()
                        Text(nominalPocket.idrFormatted)
                            .font(.subheadline.weight(.bold)).foregroundStyle(accentColor)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                }
            }
            .background(theme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 16)
    }

    private var previewSection: some View {
        VStack(spacing: 0) {
            previewRow(label: "Gram Ditambahkan", value: "\(newBerat.unitFormatted(4)) gram")
            Divider().background(theme.separator)
            previewRow(label: "Total Dibayar", value: nominalPocket.idrFormatted, accent: true)
            Divider().background(theme.separator)
            previewRow(label: "Total Berat Setelah", value: "\(totalBeratSetelah.unitFormatted(4)) gram")
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
            sectionLabel("BAYAR DARI POCKET")
            PocketChipPicker(
                pockets: allPockets.filter { $0.isAktif && $0.kelompokPocket == .biasa },
                selected: $selectedPocket
            )
            if let pocket = selectedPocket {
                Text("Saldo: \(pocket.saldo.idrFormatted)")
                    .font(.caption).foregroundStyle(.gray)
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
                Text(oldHarga > 0 ? oldHarga.idrDecimalFormatted : "–")
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
                Text(weightedAvgHarga.idrDecimalFormatted)
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
        guard let pocket = selectedPocket, newBerat > 0 else { return }

        // ── Update Aset ──
        aset.beratGram = totalBeratSetelah
        aset.hargaBeliPerGram = weightedAvgHarga

        if isDigital {
            // Akumulasi pajak
            aset.pajakBeliEmas = oldPajak + pajak
        }

        // Nilai saat ini: pakai harga saat ini per gram kalau ada, fallback ke avg harga beli
        let hargaNow = aset.hargaSaatIniEmasPerGram ?? weightedAvgHarga
        aset.nilaiSaatIni = totalBeratSetelah * hargaNow

        // ── Potong Pocket ──
        pocket.saldo -= nominalPocket

        // ── Catat Transaksi ──
        let transaksi = Transaksi(
            tanggal: Date(),
            nominal: nominalPocket,
            tipe: .pengeluaran,
            subTipe: .normal,
            pocket: pocket,
            catatan: "Beli \(aset.jenisEmas?.displayName ?? "emas") \(newBerat.unitFormatted(4))g @ \(newHarga.idrFormatted)/g"
        )
        transaksi.kategori = nabungKategori
        context.insert(transaksi)

        try? context.save()
        dismiss()
    }
}
