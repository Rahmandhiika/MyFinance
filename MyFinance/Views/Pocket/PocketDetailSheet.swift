import SwiftUI
import SwiftData

struct PocketDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let pocket: Pocket

    @Query private var allTransferInternal: [TransferInternal]

    @State private var showTransfer = false
    @State private var showEditPocket = false
    @State private var selectedTransaksi: Transaksi? = nil
    @State private var selectedTransfer: TransferInternal? = nil

    // MARK: - Computed

    private var isUtang: Bool { pocket.kelompokPocket == .utang }

    private var sisaLimit: Decimal? {
        guard let limit = pocket.limit else { return nil }
        return limit - pocket.saldo
    }

    private var utilizationRatio: Double {
        guard let limit = pocket.limit, limit > 0 else { return 0 }
        return Double(truncating: (pocket.saldo / limit) as NSDecimalNumber)
    }

    private var relatedTransferInternal: [TransferInternal] {
        allTransferInternal.filter {
            $0.pocketAsal?.id == pocket.id || $0.pocketTujuan?.id == pocket.id
        }
    }

    // Merged history: Transaksi + TransferInternal, sorted by tanggal desc
    private var histori: [HistoriItem] {
        var items: [HistoriItem] = []

        let transaksis = pocket.transaksi.map { HistoriItem.transaksi($0) }
        let transfers = relatedTransferInternal.map { HistoriItem.transfer($0) }

        items.append(contentsOf: transaksis)
        items.append(contentsOf: transfers)

        return items.sorted { $0.tanggal > $1.tanggal }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Handle
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 40, height: 4)
                            .padding(.top, 12)
                            .padding(.bottom, 20)

                        // Header
                        headerSection

                        // Utang info
                        if isUtang, pocket.limit != nil {
                            utangInfoSection
                                .padding(.horizontal, 16)
                                .padding(.top, 20)
                        }

                        // Action buttons
                        actionButtons
                            .padding(.horizontal, 16)
                            .padding(.top, 24)

                        // Histori
                        historiSection
                            .padding(.top, 28)
                            .padding(.horizontal, 16)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showTransfer) {
                TransferInternalSheet()
            }
            .sheet(isPresented: $showEditPocket) {
                AddEditPocketView(existingPocket: pocket)
            }
            .sheet(item: $selectedTransaksi) { t in
                TransaksiDetailSheet(transaksi: t)
            }
            .sheet(item: $selectedTransfer) { tf in
                TransferDetailSheet(transfer: tf)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            // Logo
            if let logoData = pocket.logo, let uiImage = UIImage(data: logoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
            } else {
                let accentColor: Color = isUtang ? .red : Color(hex: "#22C55E")
                Circle()
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Text(String(pocket.nama.prefix(1)).uppercased())
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(accentColor)
                    )
            }

            // Nama
            Text(pocket.nama)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            // Badges
            HStack(spacing: 8) {
                // Kelompok badge
                let kelompokColor: Color = isUtang ? .red : Color(hex: "#22C55E")
                Text(pocket.kelompokPocket.displayName.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(kelompokColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(kelompokColor.opacity(0.15))
                    .clipShape(Capsule())

                // Kategori badge
                if let kategori = pocket.kategoriPocket {
                    Text(kategori.nama)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
            }

            // Saldo
            VStack(spacing: 2) {
                Text(isUtang ? "Terpakai" : "Saldo")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(pocket.saldo.idrDecimalFormatted)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(isUtang ? .red : .white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Utang Info Section

    @ViewBuilder
    private var utangInfoSection: some View {
        if let limit = pocket.limit, let sisa = sisaLimit {
            VStack(spacing: 12) {
                // Limit row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Limit")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Text(limit.idrDecimalFormatted)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Sisa Limit")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Text(sisa.idrDecimalFormatted)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(sisa < 0 ? .red : Color(hex: "#22C55E"))
                    }
                }

                // Progress bar
                VStack(alignment: .leading, spacing: 4) {
                    ProgressBarView(
                        progress: utilizationRatio,
                        color: utilizationRatio > 0.8 ? .red : .orange,
                        height: 6
                    )
                    HStack {
                        Text(String(format: "%.0f%% terpakai", min(utilizationRatio * 100, 100)))
                            .font(.caption2)
                            .foregroundStyle(utilizationRatio > 0.8 ? .red : .gray)
                        Spacer()
                        if utilizationRatio > 0.8 {
                            Text("Mendekati limit!")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showTransfer = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Transfer")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                showEditPocket = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                    Text("Edit")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Histori Section

    @ViewBuilder
    private var historiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HISTORI TRANSAKSI")
                .font(.caption.weight(.bold))
                .foregroundStyle(.gray)
                .tracking(1)

            if histori.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.white.opacity(0.2))
                    Text("Belum ada transaksi")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(spacing: 1) {
                    ForEach(histori) { item in
                        HistoriRow(item: item, pocket: pocket)
                            .onTapGesture {
                                switch item {
                                case .transaksi(let t): selectedTransaksi = t
                                case .transfer(let tf): selectedTransfer = tf
                                }
                            }

                        if item.id != histori.last?.id {
                            Divider()
                                .background(Color.white.opacity(0.07))
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

// MARK: - Histori Item enum

enum HistoriItem: Identifiable {
    case transaksi(Transaksi)
    case transfer(TransferInternal)

    var id: UUID {
        switch self {
        case .transaksi(let t): return t.id
        case .transfer(let tf): return tf.id
        }
    }

    var tanggal: Date {
        switch self {
        case .transaksi(let t): return t.tanggal
        case .transfer(let tf): return tf.tanggal
        }
    }
}

// MARK: - Histori Row

private struct HistoriRow: View {
    let item: HistoriItem
    let pocket: Pocket

    private var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "dd MMM yyyy"
        return f.string(from: item.tanggal)
    }

    var body: some View {
        switch item {
        case .transaksi(let t):
            transaksiRow(t)
        case .transfer(let tf):
            transferRow(tf)
        }
    }

    @ViewBuilder
    private func transaksiRow(_ t: Transaksi) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: t.kategori?.warna ?? "#6B7280").opacity(0.18))
                    .frame(width: 38, height: 38)
                if let emoji = t.kategori?.ikonCustom, !emoji.isEmpty {
                    Text(emoji).font(.body)
                } else {
                    Image(systemName: t.kategori?.ikon ?? "tag")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: t.kategori?.warna ?? "#6B7280"))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(t.kategori?.nama ?? "Tanpa Kategori")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Text(dateString)
                    .font(.caption)
                    .foregroundStyle(.gray)
                if let catatan = t.catatan, !catatan.isEmpty {
                    Text(catatan)
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.4))
                        .lineLimit(1)
                }
            }

            Spacer()

            Text((t.tipe == .pengeluaran ? "-" : "+") + t.nominal.idrDecimalFormatted)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(t.tipe == .pengeluaran ? .red : Color(hex: "#22C55E"))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func transferRow(_ tf: TransferInternal) -> some View {
        let isOutgoing = tf.pocketAsal?.id == pocket.id

        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: isOutgoing ? "arrow.up.right" : "arrow.down.left")
                    .font(.system(size: 15))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isOutgoing ? "Transfer Keluar" : "Transfer Masuk")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Text(isOutgoing
                     ? "→ \(tf.pocketTujuan?.nama ?? "-")"
                     : "← \(tf.pocketAsal?.nama ?? "-")")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(dateString)
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.4))
            }

            Spacer()

            Text((isOutgoing ? "-" : "+") + tf.nominal.idrDecimalFormatted)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isOutgoing ? .red : Color(hex: "#22C55E"))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
