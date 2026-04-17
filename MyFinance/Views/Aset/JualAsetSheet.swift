import SwiftUI
import SwiftData

struct JualAsetSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let aset: Aset
    var onJual: () -> Void

    @Query(sort: \Pocket.urutan) var allPockets: [Pocket]
    @Query(sort: \Kategori.urutan) private var allKategori: [Kategori]

    @State private var hasilJual: Decimal = 0
    @State private var biayaAdmin: Decimal = 0
    @State private var selectedPocket: Pocket? = nil
    @State private var tanggalJual: Date = Date()
    @State private var showConfirmJual = false

    private var adminKategori: Kategori? {
        allKategori.first { $0.isAdmin && $0.tipe == .pengeluaran }
    }

    private var hasilAsetKategori: Kategori? {
        allKategori.first { $0.isHasilAset && $0.tipe == .pemasukan }
    }

    private var modal: Decimal { aset.modal }
    private var pnl: Decimal { hasilJual - biayaAdmin - modal }
    private var pnlPositive: Bool { pnl >= 0 }
    private var hasilBersih: Decimal { hasilJual - biayaAdmin }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        asetInfoCard
                        hasilJualSection
                        biayaAdminSection
                        pocketSection
                        tanggalSection
                        if hasilJual > 0 { pnlPreview }
                        jualButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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
                    Text("Hasil bersih \(hasilBersih.idrFormatted) akan masuk ke pocket yang dipilih.")
                }
            }
        }
    }

    // MARK: - Aset Info

    private var asetInfoCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(aset.tipe.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: aset.tipe.iconName)
                    .font(.body)
                    .foregroundStyle(aset.tipe.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(aset.nama)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("Modal: \(modal.idrDecimalFormatted)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Nilai Saat Ini")
                    .font(.caption2).foregroundStyle(.white.opacity(0.4))
                Text(aset.nilaiSaatIni.idrDecimalFormatted)
                    .font(.subheadline.weight(.bold)).foregroundStyle(.white)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Hasil Jual Input

    private var hasilJualSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HASIL JUAL (IDR)")
                .font(.caption).foregroundStyle(.white.opacity(0.5)).tracking(1)
            HStack(spacing: 8) {
                Text("Rp")
                    .foregroundStyle(.white.opacity(0.5))
                    .font(.subheadline)
                CurrencyInputField(value: $hasilJual, allowsDecimal: true)
            }
            .padding(14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                hasilJual = aset.nilaiSaatIni
            } label: {
                Text("Gunakan nilai pasar saat ini")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(aset.tipe.color)
            }
        }
    }

    // MARK: - Biaya Admin

    private var biayaAdminSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "building.columns.fill")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#F59E0B"))
                Text("BIAYA ADMIN (OPSIONAL)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1)
            }
            HStack(spacing: 8) {
                Text("Rp")
                    .foregroundStyle(.white.opacity(0.5))
                    .font(.subheadline)
                CurrencyInputField(value: $biayaAdmin, allowsDecimal: true)
            }
            .padding(14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            if biayaAdmin > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    Text("Akan dicatat sebagai pengeluaran\(adminKategori != nil ? " kategori \"\(adminKategori!.nama)\"" : "") dari pocket yang sama")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
        }
    }

    // MARK: - Pocket Picker

    private var pocketSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MASUKKAN HASIL KE POCKET")
                .font(.caption).foregroundStyle(.white.opacity(0.5)).tracking(1)

            let pockets = allPockets.filter { $0.isAktif && $0.kelompokPocket == .biasa }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(pockets) { pocket in
                        Button {
                            selectedPocket = pocket
                        } label: {
                            VStack(spacing: 4) {
                                Text(pocket.nama)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(selectedPocket?.id == pocket.id ? .black : .white)
                                Text(pocket.saldo.idrFormatted)
                                    .font(.caption)
                                    .foregroundStyle(selectedPocket?.id == pocket.id ? .black.opacity(0.6) : .white.opacity(0.5))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(selectedPocket?.id == pocket.id ? aset.tipe.color : Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    // MARK: - Tanggal

    private var tanggalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TANGGAL JUAL")
                .font(.caption).foregroundStyle(.white.opacity(0.5)).tracking(1)
            DatePicker("", selection: $tanggalJual, displayedComponents: .date)
                .datePickerStyle(.compact)
                .colorScheme(.dark)
                .labelsHidden()
                .padding(12)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - P&L Preview

    private var pnlPreview: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                pnlItem(label: "Modal", value: modal.idrDecimalFormatted, color: .white)
                Divider().background(Color.white.opacity(0.1)).frame(height: 40)
                pnlItem(label: "Hasil Jual", value: hasilJual.idrDecimalFormatted, color: .white)
                Divider().background(Color.white.opacity(0.1)).frame(height: 40)
                pnlItem(
                    label: pnlPositive ? "Untung" : "Rugi",
                    value: "\(pnlPositive ? "+" : "")\(pnl.idrDecimalFormatted)",
                    color: pnlPositive ? Color(hex: "#22C55E") : Color(hex: "#EF4444")
                )
            }
            .padding(.vertical, 12)

            if biayaAdmin > 0 {
                Divider().background(Color.white.opacity(0.1))
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "building.columns.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: "#F59E0B"))
                        Text("Setelah admin")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Text(hasilBersih.idrDecimalFormatted)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(hasilBersih >= modal ? Color(hex: "#22C55E") : Color(hex: "#EF4444"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(
            (pnlPositive ? Color(hex: "#22C55E") : Color(hex: "#EF4444")).opacity(0.07)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke((pnlPositive ? Color(hex: "#22C55E") : Color(hex: "#EF4444")).opacity(0.2), lineWidth: 1)
        )
    }

    private func pnlItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.5))
            Text(value).font(.caption.weight(.bold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - CTA

    private var jualButton: some View {
        Button(action: { showConfirmJual = true }) {
            Label("Konfirmasi Jual", systemImage: "arrow.up.right.circle.fill")
                .font(.headline).foregroundStyle(.black)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(selectedPocket != nil && hasilJual > 0 ? Color(hex: "#EF4444") : Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(selectedPocket == nil || hasilJual == 0)
        .opacity(selectedPocket != nil && hasilJual > 0 ? 1 : 0.5)
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

        // Catat biaya admin jika ada
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
