import SwiftUI
import SwiftData

struct BeliSahamSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let aset: Aset
    var onDismissParent: (() -> Void)? = nil

    @Query(sort: \Pocket.urutan) private var allPockets: [Pocket]
    @Query(sort: \Kategori.urutan) private var allKategori: [Kategori]

    private var nabungKategori: Kategori? {
        allKategori.first { $0.isNabung && $0.tipe == .pengeluaran }
    }

    @State private var lotBaruText = ""
    @State private var hargaBeli: Decimal = 0
    @State private var nominalPocket: Decimal = 0
    @State private var selectedPocket: Pocket? = nil

    private let accentColor = Color(hex: "#3B82F6")

    // MARK: - Computed

    private var lotBaru: Decimal { Decimal(string: lotBaruText) ?? 0 }
    private var lotLama: Decimal { aset.lot ?? 0 }
    private var hargaLama: Decimal { aset.hargaPerLembar ?? 0 }
    private var totalPengeluaran: Decimal { lotBaru * 100 * hargaBeli }

    private var hargaRataRataBaru: Decimal {
        let totalShares = (lotLama + lotBaru) * 100
        guard totalShares > 0, nominalPocket > 0 else { return hargaLama }
        // Pakai nominalPocket (aktual yg dibayar, termasuk komisi) — sama seperti cara Bibit
        let modalLama = lotLama * 100 * hargaLama
        return (modalLama + nominalPocket) / totalShares
    }

    private var canSave: Bool {
        lotBaru > 0 && hargaBeli > 0 && nominalPocket > 0 && selectedPocket != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {

                        // Header info aset
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(accentColor.opacity(0.15))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "chart.bar.fill")
                                    .font(.title3)
                                    .foregroundStyle(accentColor)
                            }
                            Text(aset.nama)
                                .font(.headline)
                                .foregroundStyle(.white)
                            if let kode = aset.kode, !kode.isEmpty {
                                Text(kode.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                        }
                        .padding(.top, 8)

                        // Info kepemilikan saat ini (read-only)
                        VStack(spacing: 0) {
                            infoRow(label: "Lot Dimiliki", value: "\(NSDecimalNumber(decimal: lotLama).intValue) lot")
                            Divider().background(Color.white.opacity(0.06))
                            infoRow(label: "Rata-rata Harga Beli",
                                    value: hargaLama > 0 ? hargaLama.idrFormatted : "–")
                        }
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16)

                        // Form beli
                        VStack(alignment: .leading, spacing: 14) {
                            sectionLabel("PEMBELIAN BARU")

                            VStack(spacing: 0) {
                                // Jumlah lot
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("JUMLAH LOT")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.gray)
                                        .tracking(0.5)
                                        .padding(.horizontal, 14)
                                        .padding(.top, 14)
                                    TextField("Contoh: 5", text: $lotBaruText)
                                        .keyboardType(.numberPad)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.bottom, 14)
                                        .onChange(of: lotBaruText) { _, _ in syncNominalPocket() }
                                }

                                Divider().background(Color.white.opacity(0.06))

                                // Harga beli per lembar
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("HARGA BELI / LEMBAR")
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
                                        CurrencyInputField(value: $hargaBeli, allowsDecimal: true)
                                    }
                                    .padding(.bottom, 14)
                                }
                            }
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .onChange(of: hargaBeli) { _, _ in syncNominalPocket() }
                        }
                        .padding(.horizontal, 16)

                        // Kepotong dari Pocket
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("KEPOTONG DARI POCKET")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.gray)
                                        .tracking(0.5)
                                    Text("Termasuk biaya komisi sekuritas")
                                        .font(.caption2)
                                        .foregroundStyle(.gray.opacity(0.7))
                                }
                                Spacer()
                                if totalPengeluaran > 0 && nominalPocket != totalPengeluaran {
                                    Button {
                                        nominalPocket = totalPengeluaran
                                    } label: {
                                        Text("Reset ke \(totalPengeluaran.idrFormatted)")
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(accentColor)
                                    }
                                }
                            }
                            HStack(spacing: 8) {
                                Text("Rp")
                                    .foregroundStyle(.gray)
                                    .font(.subheadline)
                                    .padding(.leading, 14)
                                CurrencyInputField(value: $nominalPocket, allowsDecimal: true)
                            }
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            if nominalPocket > totalPengeluaran && totalPengeluaran > 0 {
                                let selisih = nominalPocket - totalPengeluaran
                                HStack(spacing: 4) {
                                    Image(systemName: "building.columns.fill")
                                        .font(.caption2)
                                        .foregroundStyle(Color(hex: "#F59E0B"))
                                    Text("Selisih \(selisih.idrFormatted) = estimasi biaya komisi sekuritas")
                                        .font(.caption2)
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        // Preview kalkulasi
                        if lotBaru > 0 && hargaBeli > 0 {
                            VStack(spacing: 0) {
                                previewRow(label: "Total Pengeluaran (Market)",
                                           value: totalPengeluaran.idrFormatted)
                                Divider().background(Color.white.opacity(0.06))
                                previewRow(label: "Kepotong Pocket (Aktual)",
                                           value: nominalPocket.idrFormatted,
                                           accent: true)
                                Divider().background(Color.white.opacity(0.06))
                                previewRow(label: "Total Lot Setelah",
                                           value: "\(NSDecimalNumber(decimal: lotLama + lotBaru).intValue) lot")
                                Divider().background(Color.white.opacity(0.06))
                                previewRow(label: "Rata-rata Harga Baru",
                                           value: hargaRataRataBaru.idrFormatted)
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
            .navigationTitle("Beli Saham")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sub Views

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func previewRow(label: String, value: String, accent: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent ? accentColor : .white)
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

    // MARK: - Helpers

    private func syncNominalPocket() {
        let calc = totalPengeluaran
        if calc > 0 {
            nominalPocket = calc
        }
    }

    // MARK: - Save

    private func save() {
        guard let pocket = selectedPocket, lotBaru > 0, hargaBeli > 0, nominalPocket > 0 else { return }

        let totalLotBaru = lotLama + lotBaru

        // Update aset — rata-rata harga tetap pakai harga market (bukan termasuk komisi)
        aset.lot = totalLotBaru
        aset.hargaPerLembar = hargaRataRataBaru
        aset.nilaiSaatIni = totalLotBaru * 100 * hargaBeli

        // Catat transaksi dengan nominal aktual yang dipotong dari pocket
        let transaksi = Transaksi(
            tanggal: Date(),
            nominal: nominalPocket,
            tipe: .pengeluaran,
            subTipe: .normal,
            pocket: pocket,
            catatan: "Beli saham \(aset.kode ?? aset.nama) \(NSDecimalNumber(decimal: lotBaru).intValue) lot @ \(hargaBeli.idrFormatted)"
        )
        transaksi.kategori = nabungKategori
        pocket.saldo -= nominalPocket
        context.insert(transaksi)

        try? context.save()
        dismiss()
    }
}
