import SwiftUI
import SwiftData

struct TransferInternalSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var allPockets: [Pocket]

    @State private var nominal: Decimal = 0
    @State private var pocketAsal: Pocket? = nil
    @State private var pocketTujuan: Pocket? = nil
    @State private var catatan: String = ""
    @State private var tanggal: Date = Date()

    private var activePockets: [Pocket] {
        allPockets.filter { $0.isAktif }
    }

    private var tujuanPockets: [Pocket] {
        activePockets.filter { $0.id != pocketAsal?.id }
    }

    private var canSave: Bool {
        nominal > 0 && pocketAsal != nil && pocketTujuan != nil
    }

    private var nominalDisplay: String {
        nominal > 0 ? nominal.idrFormatted : "Rp 0"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Large nominal display
                        VStack(spacing: 6) {
                            Text(nominalDisplay)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)

                            CurrencyInputField(value: $nominal)
                                .padding(.horizontal, 16)
                        }
                        .padding(.top, 8)

                        // Pocket Asal
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("Dari Pocket")
                            PocketChipPicker(pockets: activePockets, selected: $pocketAsal)
                                .onChange(of: pocketAsal) { _, _ in
                                    if pocketTujuan?.id == pocketAsal?.id {
                                        pocketTujuan = nil
                                    }
                                }
                        }
                        .padding(.horizontal, 16)

                        // Arrow separator
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title)
                                .foregroundStyle(.blue)
                            Spacer()
                        }

                        // Pocket Tujuan
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("Ke Pocket")
                            PocketChipPicker(pockets: tujuanPockets, selected: $pocketTujuan)
                        }
                        .padding(.horizontal, 16)

                        // Catatan
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("Catatan")
                            TextField("Tulis catatan...", text: $catatan)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.horizontal, 16)

                        // Tanggal
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("Tanggal")
                            DatePicker("", selection: $tanggal, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .colorScheme(.dark)
                        }
                        .padding(.horizontal, 16)

                        Spacer(minLength: 32)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { saveTransfer() }
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? .blue : .gray)
                        .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.gray)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func saveTransfer() {
        guard let asal = pocketAsal, let tujuan = pocketTujuan else { return }

        let transfer = TransferInternal(
            tanggal: tanggal,
            nominal: nominal,
            pocketAsal: asal,
            pocketTujuan: tujuan,
            catatan: catatan.isEmpty ? nil : catatan
        )
        modelContext.insert(transfer)

        asal.saldo -= nominal
        tujuan.saldo += nominal

        try? modelContext.save()
        dismiss()
    }
}
