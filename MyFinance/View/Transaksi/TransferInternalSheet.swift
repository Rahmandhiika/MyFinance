import SwiftUI
import SwiftData

struct TransferInternalSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @Query(sort: \Pocket.urutan) private var allPockets: [Pocket]
    @Query(sort: \Kategori.urutan) private var allKategori: [Kategori]

    @State private var nominal: Decimal = 0
    @State private var biayaAdmin: Decimal = 0
    @State private var pocketAsal: Pocket? = nil
    @State private var pocketTujuan: Pocket? = nil
    @State private var catatan: String = ""
    @State private var tanggal: Date = Date()

    private var adminKategori: Kategori? {
        allKategori.first { $0.isAdmin && $0.tipe == .pengeluaran }
    }

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
                theme.bgApp.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Large nominal display
                        VStack(spacing: 10) {
                            Text(nominalDisplay)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(theme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)

                            CalcInputField(value: $nominal)
                                .padding(.horizontal, 16)

                            QuickAmountButtons(nominal: $nominal)
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

                        // Biaya Admin
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "building.columns.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color(hex: "#F59E0B"))
                                sectionLabel("Biaya Admin (opsional)")
                                Spacer()
                                adminQuickPick($biayaAdmin)
                            }
                            VStack(spacing: 0) {
                                CalcInputField(value: $biayaAdmin, placeholder: "Ketuk untuk input biaya admin")
                                if biayaAdmin > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "info.circle")
                                            .font(.caption2)
                                            .foregroundStyle(.gray)
                                        Text("Akan dicatat sebagai transaksi pengeluaran\(adminKategori != nil ? " kategori \"\(adminKategori!.nama)\"" : "") dari pocket asal")
                                            .font(.caption2)
                                            .foregroundStyle(.gray)
                                    }
                                    .padding(.top, 6)
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        // Catatan
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("Catatan")
                            TextField("Tulis catatan...", text: $catatan)
                                .foregroundStyle(theme.textPrimary)
                                .padding(12)
                                .background(theme.separator)
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
            .toolbarBackground(theme.bgApp, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme == .dark ? .dark : .light, for: .navigationBar)
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
        .preferredColorScheme(theme.colorScheme)
    }

    @ViewBuilder
    private func adminQuickPick(_ binding: Binding<Decimal>) -> some View {
        let presets: [(String, Decimal)] = [("1rb", 1_000), ("2,5rb", 2_500)]
        HStack(spacing: 6) {
            ForEach(presets, id: \.0) { label, amount in
                Button {
                    binding.wrappedValue += amount
                } label: {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: "#F59E0B"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#F59E0B").opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

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

        // Catat biaya admin jika ada
        if biayaAdmin > 0 {
            let adminTransaksi = Transaksi(
                tanggal: tanggal,
                nominal: biayaAdmin,
                tipe: .pengeluaran,
                subTipe: .normal,
                pocket: asal,
                catatan: "Biaya admin transfer ke \(tujuan.nama)"
            )
            adminTransaksi.kategori = adminKategori
            asal.saldo -= biayaAdmin
            modelContext.insert(adminTransaksi)
        }

        try? modelContext.save()
        dismiss()
    }
}
