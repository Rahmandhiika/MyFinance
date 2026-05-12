import SwiftUI
import SwiftData

struct TambahReksadanaSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    let aset: Aset

    @Query(sort: \Pocket.urutan) private var allPockets: [Pocket]
    @Query(sort: \Kategori.urutan) private var allKategori: [Kategori]

    private var nabungKategori: Kategori? {
        allKategori.first { $0.isNabung && $0.tipe == .pengeluaran }
    }

    @State private var tambahInvestasi: Decimal = 0
    @State private var navBaru: Decimal = 0
    @State private var selectedPocket: Pocket? = nil

    private let accentColor = Color(hex: "#22C55E")

    // MARK: - Computed

    private var totalInvestasiLama: Decimal { aset.totalInvestasiReksadana ?? 0 }
    private var unitLama: Decimal { aset.estimasiUnitReksadana }
    private var unitBaru: Decimal {
        guard navBaru > 0 else { return 0 }
        return tambahInvestasi / navBaru
    }
    private var totalUnit: Decimal { unitLama + unitBaru }
    private var totalInvestasiBar: Decimal { totalInvestasiLama + tambahInvestasi }
    private var avgNavBaru: Decimal {
        guard totalUnit > 0 else { return navBaru }
        return totalInvestasiBar / totalUnit
    }
    private var estimasiNilaiBaru: Decimal { totalUnit * navBaru }

    private var canSave: Bool {
        tambahInvestasi > 0 && navBaru > 0 && selectedPocket != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bgApp.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {

                        // Header aset
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(accentColor.opacity(0.15))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "chart.xyaxis.line")
                                    .font(.title3)
                                    .foregroundStyle(accentColor)
                            }
                            Text(aset.nama)
                                .font(.headline)
                                .foregroundStyle(theme.textPrimary)
                            if let jenis = aset.jenisReksadana, !jenis.isEmpty {
                                Text(jenis)
                                    .font(.caption)
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        .padding(.top, 8)

                        // Info posisi saat ini (read-only)
                        VStack(spacing: 0) {
                            infoRow(label: "Total Investasi", value: totalInvestasiLama.idrFormatted)
                            Divider().background(theme.separator)
                            infoRow(label: "Estimasi Unit", value: unitLama > 0 ? unitLama.unitFormatted(4) : "–")
                            Divider().background(theme.separator)
                            infoRow(label: "NAV Rata-rata Beli",
                                    value: aset.hargaBeliPerUnit.map { $0.idrDecimalFormatted } ?? "–")
                        }
                        .background(theme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16)

                        // Form tambah investasi
                        VStack(alignment: .leading, spacing: 14) {
                            sectionLabel("TAMBAH INVESTASI")

                            VStack(spacing: 0) {
                                // Jumlah tambah
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("JUMLAH INVESTASI BARU")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.gray)
                                        .tracking(0.5)
                                        .padding(.horizontal, 14)
                                        .padding(.top, 14)
                                    HStack {
                                        Text("Rp")
                                            .foregroundStyle(.gray)
                                            .font(.subheadline)
                                            .padding(.leading, 14)
                                        CurrencyInputField(value: $tambahInvestasi)
                                    }
                                    .padding(.bottom, 14)
                                }

                                Divider().background(theme.separator)

                                // NAV saat ini
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("NAV SAAT INI / UNIT")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.gray)
                                        .tracking(0.5)
                                        .padding(.horizontal, 14)
                                        .padding(.top, 14)
                                    HStack {
                                        Text("Rp")
                                            .foregroundStyle(.gray)
                                            .font(.subheadline)
                                            .padding(.leading, 14)
                                        CurrencyInputField(value: $navBaru)
                                    }
                                    .padding(.bottom, 14)
                                }
                            }
                            .background(theme.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 16)

                        // Preview kalkulasi
                        if tambahInvestasi > 0 && navBaru > 0 {
                            VStack(spacing: 0) {
                                previewRow(label: "Total Pengeluaran",
                                           value: tambahInvestasi.idrFormatted,
                                           accent: true)
                                Divider().background(theme.separator)
                                previewRow(label: "Unit Didapat",
                                           value: unitBaru.unitFormatted(4))
                                Divider().background(theme.separator)
                                previewRow(label: "Total Unit Setelah",
                                           value: totalUnit.unitFormatted(4))
                                Divider().background(theme.separator)
                                previewRow(label: "NAV Rata-rata Baru",
                                           value: avgNavBaru.idrDecimalFormatted)
                                Divider().background(theme.separator)
                                previewRow(label: "Est. Nilai Portofolio",
                                           value: estimasiNilaiBaru.idrFormatted,
                                           accent: true)
                            }
                            .background(accentColor.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(accentColor.opacity(0.2), lineWidth: 1))
                            .padding(.horizontal, 16)
                        }

                        // Pocket picker
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("BAYAR DARI POCKET")
                            PocketChipPicker(
                                pockets: allPockets.filter { $0.isAktif },
                                selected: $selectedPocket
                            )
                        }
                        .padding(.horizontal, 16)

                        // Confirm button
                        Button { save() } label: {
                            Text("Catat Pembelian")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(canSave ? accentColor : Color.gray)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!canSave)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Tambah Investasi")
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
        .onAppear {
            // Pre-fill NAV dengan nilai terakhir yang disimpan
            if let navTerakhir = aset.navSaatIni, navTerakhir > 0 {
                navBaru = navTerakhir
            }
        }
    }

    // MARK: - Sub Views

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func previewRow(label: String, value: String, accent: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent ? accentColor : theme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.gray)
            .tracking(0.5)
    }

    // MARK: - Save

    private func save() {
        guard let pocket = selectedPocket, tambahInvestasi > 0, navBaru > 0 else { return }

        // Update aset
        aset.totalInvestasiReksadana = totalInvestasiBar
        aset.hargaBeliPerUnit = avgNavBaru
        aset.navSaatIni = navBaru
        aset.jumlahUnitReksadana = totalUnit  // simpan total unit aktual
        aset.nilaiSaatIni = estimasiNilaiBaru

        // Catat transaksi pengeluaran
        let transaksi = Transaksi(
            tanggal: Date(),
            nominal: tambahInvestasi,
            tipe: .pengeluaran,
            subTipe: .normal,
            pocket: pocket,
            catatan: "Tambah investasi \(aset.nama) @ NAV \(navBaru.idrDecimalFormatted)"
        )
        transaksi.kategori = nabungKategori
        pocket.saldo -= tambahInvestasi
        context.insert(transaksi)

        try? context.save()
        dismiss()
    }
}
