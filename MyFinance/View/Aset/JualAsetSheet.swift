import SwiftUI
import SwiftData

struct JualAsetSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let aset: Aset
    var onJual: () -> Void

    @Query(sort: \Pocket.urutan) private var allPockets: [Pocket]
    @Query(sort: \Kategori.urutan) private var allKategori: [Kategori]

    @State private var hasilJual: Decimal = 0
    @State private var biayaAdmin: Decimal = 0
    @State private var selectedPocket: Pocket? = nil
    @State private var tanggalJual: Date = Date()
    @State private var showConfirmJual = false

    private let accentColor = Color(hex: "#EF4444")

    private var adminKategori: Kategori? {
        allKategori.first { $0.isAdmin && $0.tipe == .pengeluaran }
    }
    private var hasilAsetKategori: Kategori? {
        allKategori.first { $0.isHasilAset && $0.tipe == .pemasukan }
    }
    private var activePockets: [Pocket] {
        allPockets.filter { $0.isAktif && $0.kelompokPocket == .biasa }
    }
    private var modal: Decimal { aset.modal }
    private var pnl: Decimal { hasilJual - biayaAdmin - modal }
    private var pnlPositive: Bool { pnl >= 0 }
    private var hasilBersih: Decimal { hasilJual - biayaAdmin }
    private var canSave: Bool { selectedPocket != nil && hasilJual > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {

                        // Header — info aset
                        headerCard
                            .padding(.top, 8)

                        // Info kepemilikan (read-only)
                        VStack(spacing: 0) {
                            infoRow(label: "Total Modal", value: modal.idrDecimalFormatted)
                            Divider().background(Color.white.opacity(0.06))
                            infoRow(label: "Nilai Pasar Saat Ini", value: aset.nilaiSaatIni.idrDecimalFormatted)
                        }
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16)

                        // Form input — grouped dalam satu card
                        VStack(alignment: .leading, spacing: 14) {
                            sectionLabel("DETAIL PENJUALAN")

                            VStack(spacing: 0) {
                                // Hasil jual
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("HARGA JUAL (IDR)")
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
                                        CurrencyInputField(value: $hasilJual, allowsDecimal: true)
                                    }
                                    // Shortcut pakai nilai pasar
                                    if aset.nilaiSaatIni > 0 && hasilJual != aset.nilaiSaatIni {
                                        Button { hasilJual = aset.nilaiSaatIni } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.clockwise")
                                                    .font(.caption2.weight(.semibold))
                                                Text("Pakai nilai pasar (\(aset.nilaiSaatIni.idrFormatted))")
                                                    .font(.caption2.weight(.medium))
                                            }
                                            .foregroundStyle(accentColor)
                                        }
                                        .padding(.horizontal, 14)
                                    }
                                    Spacer(minLength: 14)
                                }

                                Divider().background(Color.white.opacity(0.06))

                                // Biaya admin
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "building.columns.fill")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(Color(hex: "#F59E0B"))
                                        Text("BIAYA ADMIN (OPSIONAL)")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.gray)
                                            .tracking(0.5)
                                        Spacer()
                                        adminQuickPick($biayaAdmin)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.top, 14)
                                    HStack {
                                        Text("Rp")
                                            .foregroundStyle(.gray)
                                            .font(.subheadline)
                                            .padding(.leading, 14)
                                        CurrencyInputField(value: $biayaAdmin, allowsDecimal: true)
                                    }
                                    if biayaAdmin > 0 {
                                        HStack(spacing: 4) {
                                            Image(systemName: "info.circle")
                                                .font(.caption2)
                                                .foregroundStyle(.gray)
                                            Text("Dicatat sebagai pengeluaran\(adminKategori != nil ? " \"\(adminKategori!.nama)\"" : "") dari pocket yang sama")
                                                .font(.caption2)
                                                .foregroundStyle(.gray)
                                        }
                                        .padding(.horizontal, 14)
                                    }
                                    Spacer(minLength: 14)
                                }

                                Divider().background(Color.white.opacity(0.06))

                                // Tanggal
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("TANGGAL JUAL")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.gray)
                                            .tracking(0.5)
                                        Text(tanggalJual.formatted(date: .abbreviated, time: .omitted))
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                    }
                                    Spacer()
                                    DatePicker("", selection: $tanggalJual, displayedComponents: .date)
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

                        // P&L preview
                        if hasilJual > 0 {
                            pnlPreview
                                .padding(.horizontal, 16)
                        }

                        // Pocket picker
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("MASUKKAN HASIL KE POCKET")
                                .padding(.horizontal, 16)
                            PocketChipPicker(pockets: activePockets, selected: $selectedPocket)
                                .padding(.horizontal, 16)
                        }

                        // Confirm button
                        Button { showConfirmJual = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.right.circle.fill")
                                Text("Konfirmasi Jual")
                                    .fontWeight(.bold)
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canSave ? accentColor : Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!canSave)
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
                    Text("Jual \(aset.tipe.displayName)")
                        .font(.headline).foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .onAppear { hasilJual = aset.nilaiSaatIni }
            .alert("Konfirmasi Jual?", isPresented: $showConfirmJual) {
                Button("Jual", role: .destructive) { konfirmasiJual() }
                Button("Batal", role: .cancel) {}
            } message: {
                if aset.linkedTarget != nil {
                    Text("Aset ini terhubung ke target \"\(aset.linkedTarget?.nama ?? "")\". Menjual aset akan menghapus target tersebut secara permanen.")
                } else {
                    Text("Hasil bersih \(hasilBersih.idrFormatted) akan masuk ke pocket \"\(selectedPocket?.nama ?? "")\".")
                }
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
                Image(systemName: aset.tipe.iconName)
                    .font(.title2)
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
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }

    // MARK: - P&L Preview

    private var pnlPreview: some View {
        let color = pnlPositive ? Color(hex: "#22C55E") : accentColor
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                pnlItem(label: "Modal", value: modal.idrFormatted, color: .white.opacity(0.7))
                Divider().background(Color.white.opacity(0.1)).frame(height: 40)
                pnlItem(label: "Hasil Jual", value: hasilJual.idrFormatted, color: .white)
                Divider().background(Color.white.opacity(0.1)).frame(height: 40)
                pnlItem(
                    label: pnlPositive ? "Untung" : "Rugi",
                    value: "\(pnlPositive ? "+" : "")\(pnl.idrFormatted)",
                    color: color
                )
            }
            .padding(.vertical, 14)

            if biayaAdmin > 0 {
                Divider().background(Color.white.opacity(0.1))
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "building.columns.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: "#F59E0B"))
                        Text("Hasil bersih (setelah admin)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Text(hasilBersih.idrFormatted)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(hasilBersih >= modal ? Color(hex: "#22C55E") : accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Admin Quick Pick

    @ViewBuilder
    private func adminQuickPick(_ binding: Binding<Decimal>) -> some View {
        let presets: [(String, Decimal)] = [("1rb", 1_000), ("2,5rb", 2_500)]
        HStack(spacing: 6) {
            ForEach(presets, id: \.0) { label, amount in
                Button {
                    binding.wrappedValue = binding.wrappedValue == amount ? 0 : amount
                } label: {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(binding.wrappedValue == amount ? .black : Color(hex: "#F59E0B"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(binding.wrappedValue == amount ? Color(hex: "#F59E0B") : Color(hex: "#F59E0B").opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

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
    private func pnlItem(label: String, value: String, color: Color) -> some View {
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

    private func konfirmasiJual() {
        guard let pocket = selectedPocket, hasilJual > 0 else { return }

        pocket.saldo += hasilJual

        let transaksi = Transaksi(
            tanggal: tanggalJual,
            nominal: hasilJual,
            tipe: .pemasukan,
            subTipe: .normal,
            pocket: pocket,
            catatan: "Jual \(aset.tipe.displayName): \(aset.nama)"
        )
        transaksi.kategori = hasilAsetKategori
        modelContext.insert(transaksi)

        if biayaAdmin > 0 {
            let adminTransaksi = Transaksi(
                tanggal: tanggalJual,
                nominal: biayaAdmin,
                tipe: .pengeluaran,
                subTipe: .normal,
                pocket: pocket,
                catatan: "Biaya admin jual \(aset.tipe.displayName): \(aset.nama)"
            )
            adminTransaksi.kategori = adminKategori
            pocket.saldo -= biayaAdmin
            modelContext.insert(adminTransaksi)
        }

        modelContext.delete(aset)
        try? modelContext.save()
        dismiss()
        onJual()
    }
}
