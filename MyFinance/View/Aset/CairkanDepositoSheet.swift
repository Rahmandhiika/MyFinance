import SwiftUI
import SwiftData

struct CairkanDepositoSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let aset: Aset
    var onCairkan: () -> Void

    @Query(sort: \Pocket.urutan) private var allPockets: [Pocket]
    @Query(sort: \Kategori.urutan) private var allKategori: [Kategori]

    @State private var selectedPocket: Pocket? = nil
    @State private var tanggalCair: Date = Date()
    @State private var showConfirm = false

    private let accentColor = Color(hex: "#A78BFA")

    private var hasilAsetKategori: Kategori? {
        allKategori.first { $0.isHasilAset && $0.tipe == .pemasukan }
    }
    private var activePockets: [Pocket] {
        allPockets.filter { $0.isAktif && $0.kelompokPocket == .biasa }
    }
    private var nominal: Decimal { aset.nominalDeposito ?? 0 }
    private var bungaBersih: Decimal { aset.bungaBersihDeposito }
    private var totalDiterima: Decimal { nominal + bungaBersih }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {

                        // Header
                        headerCard
                            .padding(.top, 8)

                        // Info deposito (read-only)
                        VStack(spacing: 0) {
                            infoRow(label: "Nominal Pokok", value: nominal.idrDecimalFormatted)
                            Divider().background(Color.white.opacity(0.06))
                            infoRow(label: "Tenor", value: tenorLabel)
                            Divider().background(Color.white.opacity(0.06))
                            infoRow(label: "Bunga p.a.", value: bungaPALabel)
                        }
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16)

                        // Breakdown pencairan
                        breakdownCard
                            .padding(.horizontal, 16)

                        // Tanggal
                        VStack(alignment: .leading, spacing: 14) {
                            sectionLabel("DETAIL PENCAIRAN")
                            VStack(spacing: 0) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("TANGGAL CAIR")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.gray)
                                            .tracking(0.5)
                                        Text(tanggalCair.formatted(date: .abbreviated, time: .omitted))
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                    }
                                    Spacer()
                                    DatePicker("", selection: $tanggalCair, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .colorScheme(.dark)
                                        .labelsHidden()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                            }
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 16)

                        // Pocket picker
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("CAIRKAN KE POCKET")
                                .padding(.horizontal, 16)
                            PocketChipPicker(pockets: activePockets, selected: $selectedPocket)
                                .padding(.horizontal, 16)
                        }

                        // CTA
                        Button { showConfirm = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Cairkan Sekarang")
                                    .fontWeight(.bold)
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(selectedPocket != nil ? accentColor : Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(selectedPocket == nil)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Cairkan Deposito")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .alert("Konfirmasi Pencairan?", isPresented: $showConfirm) {
                Button("Cairkan", role: .destructive) { konfirmasiCairkan() }
                Button("Batal", role: .cancel) {}
            } message: {
                Text("Total \(totalDiterima.idrFormatted) akan masuk ke pocket \"\(selectedPocket?.nama ?? "")\".")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "building.columns.fill")
                    .font(.title2)
                    .foregroundStyle(accentColor)
            }
            Text(aset.nama)
                .font(.headline)
                .foregroundStyle(.white)
            if let bank = aset.kode, !bank.isEmpty {
                Text(bank.uppercased())
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }

    // MARK: - Breakdown Card

    private var breakdownCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                breakdownItem(label: "Pokok", value: nominal.idrFormatted, color: .white.opacity(0.8))
                Divider().background(Color.white.opacity(0.1)).frame(height: 40)
                breakdownItem(label: "Bunga Bersih", value: "+\(bungaBersih.idrFormatted)", color: Color(hex: "#22C55E"))
                Divider().background(Color.white.opacity(0.1)).frame(height: 40)
                breakdownItem(label: "Total Cair", value: totalDiterima.idrFormatted, color: accentColor)
            }
            .padding(.vertical, 14)

            if let pph = aset.pphFinal, let bunga = aset.bungaPA {
                Divider().background(Color.white.opacity(0.1))
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    Text("PPh \(NSDecimalNumber(decimal: pph).intValue)% dipotong dari bunga kotor \(bunga.idrDecimalFormatted)% p.a.")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(accentColor.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Helpers

    private var tenorLabel: String {
        guard let bulan = aset.tenorBulan else { return "-" }
        if bulan >= 12 && bulan % 12 == 0 {
            return "\(bulan / 12) tahun"
        }
        return "\(bulan) bulan"
    }

    private var bungaPALabel: String {
        guard let b = aset.bungaPA else { return "-" }
        return "\(b.idrDecimalFormatted)%"
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
    private func breakdownItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.5))
            Text(value).font(.caption.weight(.bold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.gray)
            .tracking(0.5)
    }

    // MARK: - Action

    private func konfirmasiCairkan() {
        guard let pocket = selectedPocket else { return }

        pocket.saldo += totalDiterima

        let transaksi = Transaksi(
            tanggal: tanggalCair,
            nominal: totalDiterima,
            tipe: .pemasukan,
            subTipe: .normal,
            pocket: pocket,
            catatan: "Pencairan Deposito: \(aset.nama)"
        )
        transaksi.kategori = hasilAsetKategori
        modelContext.insert(transaksi)
        modelContext.delete(aset)

        try? modelContext.save()
        dismiss()
        onCairkan()
    }
}
