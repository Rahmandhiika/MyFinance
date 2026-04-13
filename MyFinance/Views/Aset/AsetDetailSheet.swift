import SwiftUI
import SwiftData

struct AsetDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let aset: Aset

    @State private var showEdit = false
    @State private var editMode: AsetEditMode = .edit

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // MARK: Header
                        headerSection

                        // MARK: Detail Grid
                        detailGridSection

                        // MARK: Action Buttons
                        actionButtonsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(aset.nama)
                            .font(.headline)
                            .foregroundStyle(.white)
                        if let kode = aset.kode, !kode.isEmpty {
                            Text(kode.uppercased())
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.title3)
                    }
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            AddEditAsetView(existingAset: aset, mode: editMode)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            // Tipe icon
            ZStack {
                Circle()
                    .fill(aset.tipe.color.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: aset.tipe.iconName)
                    .font(.title2)
                    .foregroundStyle(aset.tipe.color)
            }

            Text("NILAI PASAR")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1)

            Text(aset.nilaiSaatIni.idrFormatted)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)

            // P&L badge
            HStack(spacing: 6) {
                Image(systemName: aset.pnl >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
                Text("\(aset.pnl.idrFormatted) (\(aset.returnPersen.percentFormatted))")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(aset.pnl >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444"))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background((aset.pnl >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444")).opacity(0.15))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Detail Grid

    private var detailGridSection: some View {
        VStack(spacing: 0) {
            DetailRow(label: "Tipe Aset", value: aset.tipe.displayName)
            Divider().background(Color.white.opacity(0.08))

            switch aset.tipe {
            case .saham:
                sahamDetails
            case .kripto:
                kriptoDetails
            case .reksadana:
                reksadanaDetails
            case .emas:
                emasDetails
            }

            Divider().background(Color.white.opacity(0.08))
            DetailRow(label: "Total Modal", value: aset.modal.idrFormatted)
            Divider().background(Color.white.opacity(0.08))
            DetailRow(
                label: "Keuntungan / Rugi",
                value: "\(aset.pnl >= 0 ? "+" : "")\(aset.pnl.idrFormatted)",
                valueColor: aset.pnl >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444")
            )
            Divider().background(Color.white.opacity(0.08))
            DetailRow(
                label: "Return",
                value: aset.returnPersen.percentFormatted,
                valueColor: aset.pnl >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444")
            )
        }
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var sahamDetails: some View {
        if let lot = aset.lot {
            DetailRow(label: "Jumlah Lot", value: "\(NSDecimalNumber(decimal: lot).intValue) lot")
            Divider().background(Color.white.opacity(0.08))
        }
        if let harga = aset.hargaPerLembar {
            DetailRow(label: "Harga Beli/Lembar", value: harga.idrFormatted)
            Divider().background(Color.white.opacity(0.08))
            let hargaSaatIniPerLembar = aset.lot != nil && aset.lot! > 0
                ? aset.nilaiSaatIni / ((aset.lot ?? 1) * 100)
                : 0
            DetailRow(label: "Harga Saat Ini/Lembar", value: hargaSaatIniPerLembar.idrFormatted)
            Divider().background(Color.white.opacity(0.08))
        }
    }

    @ViewBuilder
    private var kriptoDetails: some View {
        if let mataUang = aset.mataUang {
            DetailRow(label: "Mata Uang", value: mataUang.displayName)
            Divider().background(Color.white.opacity(0.08))
        }
        if let hargaPerUnit = aset.hargaPerUnit, hargaPerUnit > 0 {
            let jumlahUnit = aset.totalInvestasiKripto != nil && hargaPerUnit > 0
                ? (aset.totalInvestasiKripto! / hargaPerUnit)
                : Decimal(0)
            DetailRow(label: "Jumlah Koin", value: "\(Double(truncating: jumlahUnit as NSDecimalNumber).formatted(.number.precision(.fractionLength(4))))")
            Divider().background(Color.white.opacity(0.08))
        }
        if let harga = aset.hargaPerUnit {
            DetailRow(label: "Harga Beli/Unit", value: harga.idrFormatted)
            Divider().background(Color.white.opacity(0.08))
        }
    }

    @ViewBuilder
    private var reksadanaDetails: some View {
        if let jenis = aset.jenisReksadana, !jenis.isEmpty {
            DetailRow(label: "Jenis", value: jenis)
            Divider().background(Color.white.opacity(0.08))
        }
        if let nav = aset.nav {
            DetailRow(label: "NAV/Unit", value: nav.idrFormatted)
            Divider().background(Color.white.opacity(0.08))
            let totalInv = aset.totalInvestasiReksadana ?? 0
            let unitCount = nav > 0 ? totalInv / nav : Decimal(0)
            DetailRow(label: "Jumlah Unit", value: "\(Double(truncating: unitCount as NSDecimalNumber).formatted(.number.precision(.fractionLength(2))))")
            Divider().background(Color.white.opacity(0.08))
        }
    }

    @ViewBuilder
    private var emasDetails: some View {
        if let jenis = aset.jenisEmas {
            DetailRow(label: "Jenis Emas", value: jenis.displayName)
            Divider().background(Color.white.opacity(0.08))
        }
        if let tahun = aset.tahunCetak {
            DetailRow(label: "Tahun Cetak", value: "\(tahun)")
            Divider().background(Color.white.opacity(0.08))
        }
        if let berat = aset.beratGram {
            DetailRow(label: "Berat", value: "\(Double(truncating: berat as NSDecimalNumber).formatted(.number.precision(.fractionLength(2)))) gram")
            Divider().background(Color.white.opacity(0.08))
        }
        if let harga = aset.hargaBeliPerGram {
            DetailRow(label: "Harga Beli/Gram", value: harga.idrFormatted)
            Divider().background(Color.white.opacity(0.08))
        }
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            // Edit
            Button {
                editMode = .edit
                showEdit = true
            } label: {
                Label("Edit", systemImage: "pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Jual
            Button {
                editMode = .jual
                showEdit = true
            } label: {
                Label("Jual", systemImage: "arrow.up.right.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: "#EF4444"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#EF4444").opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Beli
            Button {
                editMode = .beli
                showEdit = true
            } label: {
                Label("Beli", systemImage: "arrow.down.left.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: "#22C55E"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#22C55E").opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .white

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Edit Mode

enum AsetEditMode {
    case edit, beli, jual
}
