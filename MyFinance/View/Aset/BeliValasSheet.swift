import SwiftUI
import SwiftData

struct BeliValasSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let aset: Aset

    @Query(sort: \Pocket.urutan) private var allPockets: [Pocket]
    @Query(sort: \Kategori.urutan) private var allKategori: [Kategori]

    private var nabungKategori: Kategori? {
        allKategori.first { $0.isNabung && $0.tipe == .pengeluaran }
    }

    @State private var jumlahBeli: Decimal = 0
    @State private var kursBeli: Decimal = 0
    @State private var selectedPocket: Pocket? = nil
    @State private var isLoadingKurs = false

    private let accentColor = Color(hex: "#06B6D4")

    // MARK: - Computed

    private var mata: MataUangValas? { aset.mataUangValas }
    private var jumlahLama: Decimal { aset.jumlahValas ?? 0 }
    private var kursLama: Decimal { aset.kursBeliPerUnit ?? 0 }
    private var totalPengeluaran: Decimal { jumlahBeli * kursBeli }

    private var kursRataRataBaru: Decimal {
        let totalBaru = jumlahLama + jumlahBeli
        guard totalBaru > 0 else { return kursLama }
        return (jumlahLama * kursLama + jumlahBeli * kursBeli) / totalBaru
    }

    private var canSave: Bool {
        jumlahBeli > 0 && kursBeli > 0 && selectedPocket != nil
    }

    private var kursNaikTurun: Bool {
        // true = naik (kurs rata-rata lebih tinggi dari sebelumnya) — untuk valas, kurs tinggi = biaya lebih mahal
        guard kursBeli > 0, jumlahBeli > 0, kursLama > 0 else { return false }
        return kursRataRataBaru > kursLama
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {

                        // Header
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(accentColor.opacity(0.15))
                                    .frame(width: 52, height: 52)
                                Text(mata?.flag ?? "💱")
                                    .font(.title2)
                            }
                            Text(aset.nama)
                                .font(.headline)
                                .foregroundStyle(.white)
                            if let m = mata {
                                Text(m.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                        }
                        .padding(.top, 8)

                        // Info kepemilikan saat ini
                        VStack(spacing: 0) {
                            infoRow(label: "Dimiliki Saat Ini",
                                    value: "\(jumlahLama.unitFormatted(2)) \(mata?.rawValue ?? "")")
                            Divider().background(Color.white.opacity(0.06))
                            infoRow(label: "Rata-rata Kurs Beli",
                                    value: kursLama > 0 ? kursLama.idrDecimalFormatted : "–")
                        }
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16)

                        // Form pembelian
                        VStack(alignment: .leading, spacing: 14) {
                            sectionLabel("PEMBELIAN BARU")

                            VStack(spacing: 0) {
                                // Jumlah beli
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("JUMLAH \(mata?.rawValue ?? "VALAS") YANG DIBELI")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.gray)
                                        .tracking(0.5)
                                        .padding(.horizontal, 14)
                                        .padding(.top, 14)
                                    HStack {
                                        Text(mata?.flag ?? "")
                                            .foregroundStyle(.gray)
                                            .font(.subheadline)
                                            .padding(.leading, 14)
                                        CurrencyInputField(value: $jumlahBeli, allowsDecimal: true)
                                    }
                                    .padding(.bottom, 14)
                                }

                                Divider().background(Color.white.opacity(0.06))

                                // Kurs beli
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("KURS BELI (IDR / \(mata?.rawValue ?? "UNIT"))")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.gray)
                                            .tracking(0.5)
                                        Spacer()
                                        // Ambil kurs otomatis
                                        Button {
                                            guard let m = mata else { return }
                                            isLoadingKurs = true
                                            Task {
                                                if let k = await AsetPriceService.shared.fetchKursValas(m) {
                                                    kursBeli = k
                                                }
                                                isLoadingKurs = false
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                if isLoadingKurs {
                                                    ProgressView().tint(accentColor).scaleEffect(0.7)
                                                } else {
                                                    Image(systemName: "arrow.clockwise")
                                                        .font(.caption2.weight(.semibold))
                                                }
                                                Text("Ambil Kurs")
                                                    .font(.caption2.weight(.semibold))
                                            }
                                            .foregroundStyle(accentColor)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(accentColor.opacity(0.12))
                                            .clipShape(Capsule())
                                        }
                                        .disabled(isLoadingKurs)
                                        .padding(.trailing, 14)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.top, 14)
                                    HStack {
                                        Text("Rp")
                                            .foregroundStyle(.gray)
                                            .font(.subheadline)
                                            .padding(.leading, 14)
                                        CurrencyInputField(value: $kursBeli, allowsDecimal: true)
                                    }
                                    .padding(.bottom, 14)
                                }
                            }
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 16)

                        // Preview kalkulasi
                        if jumlahBeli > 0 && kursBeli > 0 {
                            VStack(spacing: 0) {
                                previewRow(label: "Total Pengeluaran (IDR)",
                                           value: totalPengeluaran.idrDecimalFormatted,
                                           accent: true)
                                Divider().background(Color.white.opacity(0.06))
                                previewRow(label: "Total \(mata?.rawValue ?? "Valas") Setelah",
                                           value: "\((jumlahLama + jumlahBeli).unitFormatted(2)) \(mata?.rawValue ?? "")")
                                Divider().background(Color.white.opacity(0.06))
                                kursComparisonRow
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
            .navigationTitle("Beli \(mata?.rawValue ?? "Valas")")
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
    private var kursComparisonRow: some View {
        let changeColor = kursNaikTurun ? Color(hex: "#F59E0B") : Color(hex: "#22C55E")
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Kurs rata-rata sekarang")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                Text(kursLama > 0 ? kursLama.idrFormatted : "–")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 3) {
                Image(systemName: kursNaikTurun ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(changeColor)
                Text(kursNaikTurun ? "naik" : "turun")
                    .font(.caption2)
                    .foregroundStyle(changeColor)
            }
            .frame(width: 52)

            VStack(alignment: .trailing, spacing: 3) {
                Text("Kurs rata-rata setelah")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                Text(kursRataRataBaru.idrFormatted)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(changeColor)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

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

    // MARK: - Save

    private func save() {
        guard let pocket = selectedPocket, jumlahBeli > 0, kursBeli > 0 else { return }

        let jumlahBaru = jumlahLama + jumlahBeli

        // Update aset
        aset.jumlahValas = jumlahBaru
        aset.kursBeliPerUnit = kursRataRataBaru
        aset.kursSaatIni = kursBeli
        aset.nilaiSaatIni = jumlahBaru * kursBeli

        // Catat transaksi pengeluaran
        let catatan = "Beli \(jumlahBeli.unitFormatted(2)) \(mata?.rawValue ?? "valas") @ \(kursBeli.idrFormatted)"
        let transaksi = Transaksi(
            tanggal: Date(),
            nominal: totalPengeluaran,
            tipe: .pengeluaran,
            subTipe: .normal,
            pocket: pocket,
            catatan: catatan
        )
        transaksi.kategori = nabungKategori
        pocket.saldo -= totalPengeluaran
        context.insert(transaksi)

        try? context.save()
        dismiss()
    }
}
