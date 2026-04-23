import SwiftUI
import SwiftData

struct CairkanDepositoSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let aset: Aset
    var onCairkan: () -> Void

    @Query(sort: \Pocket.urutan) private var allPockets: [Pocket]
    @State private var selectedPocket: Pocket? = nil
    @State private var tanggalCair: Date = Date()

    private var nominal: Decimal { aset.nominalDeposito ?? 0 }
    private var bungaBersih: Decimal { aset.bungaBersihDeposito }
    private var totalDiterima: Decimal { nominal + bungaBersih }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        summaryCard
                        pocketSection
                        tanggalSection
                        cairkanButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
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
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("TOTAL YANG DITERIMA")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1)
                Text(totalDiterima.idrDecimalFormatted)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color(hex: "#A78BFA").opacity(0.1))

            Divider().background(Color.white.opacity(0.08))

            VStack(spacing: 0) {
                summaryRow(label: "Nominal Pokok", value: nominal.idrDecimalFormatted, color: .white)
                Divider().background(Color.white.opacity(0.06))
                summaryRow(label: "Bunga Bersih (setelah PPh)", value: "+ \(bungaBersih.idrDecimalFormatted)", color: Color(hex: "#22C55E"))
                Divider().background(Color.white.opacity(0.06))
                HStack {
                    Text("Total")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(totalDiterima.idrDecimalFormatted)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(hex: "#A78BFA"))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }

            if let pph = aset.pphFinal, let bunga = aset.bungaPA {
                Divider().background(Color.white.opacity(0.08))
                Text("PPh \(NSDecimalNumber(decimal: pph).intValue)% sudah dipotong dari bunga kotor \(bunga.idrDecimalFormatted)% p.a.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func summaryRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(color)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Pocket Picker

    private var activePockets: [Pocket] {
        allPockets.filter { $0.isAktif && $0.kelompokPocket == .biasa }
    }

    private var pocketSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CAIRKAN KE POCKET")
                .font(.caption).foregroundStyle(.white.opacity(0.5)).tracking(1)
            PocketChipPicker(pockets: activePockets, selected: $selectedPocket)
        }
    }

    // MARK: - Tanggal

    private var tanggalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TANGGAL PENCAIRAN")
                .font(.caption).foregroundStyle(.white.opacity(0.5)).tracking(1)
            DatePicker("", selection: $tanggalCair, displayedComponents: .date)
                .datePickerStyle(.compact)
                .colorScheme(.dark)
                .labelsHidden()
                .padding(12)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - CTA

    private var cairkanButton: some View {
        Button(action: konfirmasiCairkan) {
            Label("Cairkan Sekarang", systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundStyle(.black)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(selectedPocket != nil ? Color(hex: "#A78BFA") : Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(selectedPocket == nil)
        .opacity(selectedPocket != nil ? 1 : 0.5)
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
        modelContext.insert(transaksi)
        modelContext.delete(aset)

        try? modelContext.save()
        dismiss()
        onCairkan()
    }
}
