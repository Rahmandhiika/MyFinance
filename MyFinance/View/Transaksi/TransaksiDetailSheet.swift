import SwiftUI
import SwiftData

struct TransaksiDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var allTargets: [Target]

    let transaksi: Transaksi

    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    private var linkedTarget: Target? {
        guard let gid = transaksi.goalID else { return nil }
        return allTargets.first { $0.id == gid }
    }

    private var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "EEEE, dd MMMM yyyy · HH:mm"
        return f.string(from: transaksi.tanggal)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Handle indicator
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 40, height: 4)
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                    // Category icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(hex: transaksi.kategori?.warna ?? "#6B7280").opacity(0.2))
                            .frame(width: 72, height: 72)
                        if let emoji = transaksi.kategori?.ikonCustom, !emoji.isEmpty {
                            Text(emoji).font(.largeTitle)
                        } else {
                            Image(systemName: transaksi.kategori?.ikon ?? "tag")
                                .font(.system(size: 30))
                                .foregroundStyle(Color(hex: transaksi.kategori?.warna ?? "#6B7280"))
                        }
                    }

                    // Category name
                    Text(transaksi.kategori?.nama.uppercased() ?? "TANPA KATEGORI")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.gray)
                        .tracking(1.5)
                        .padding(.top, 10)

                    // Nominal
                    Text((transaksi.tipe == .pengeluaran ? "-" : "+") + transaksi.nominal.idrFormatted)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(transaksi.tipe == .pengeluaran ? .red : .green)
                        .padding(.top, 4)

                    // Detail rows
                    VStack(spacing: 0) {
                        detailRow(
                            icon: "clock",
                            iconColor: .gray,
                            label: "Tanggal",
                            value: dateString
                        )

                        if let pocket = transaksi.pocket {
                            Divider().background(Color.white.opacity(0.08))
                            detailRow(
                                icon: "wallet.pass",
                                iconColor: Color(hex: "#22C55E"),
                                label: "Pocket",
                                value: pocket.nama
                            )
                        }

                        if let catatan = transaksi.catatan, !catatan.isEmpty {
                            Divider().background(Color.white.opacity(0.08))
                            detailRow(
                                icon: "note.text",
                                iconColor: .yellow,
                                label: "Catatan",
                                value: catatan
                            )
                        }

                        if let target = linkedTarget {
                            Divider().background(Color.white.opacity(0.08))
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: target.warna).opacity(0.2))
                                        .frame(width: 36, height: 36)
                                    if let emoji = target.ikonCustom, !emoji.isEmpty {
                                        Text(emoji).font(.body)
                                    } else {
                                        Image(systemName: target.ikon)
                                            .foregroundStyle(Color(hex: target.warna))
                                    }
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Target")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                    Text(target.nama)
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                Text(transaksi.subTipe.displayName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: target.warna).opacity(0.3))
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                    Spacer()

                    // Action buttons
                    HStack(spacing: 12) {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                Text("Hapus")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            showEdit = true
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .sheet(isPresented: $showEdit) {
                AddEditTransaksiSheet(transaksi: transaksi)
            }
            .confirmationDialog("Hapus Transaksi?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Hapus", role: .destructive) { deleteTransaksi() }
                Button("Batal", role: .cancel) {}
            } message: {
                Text("Transaksi ini akan dihapus dan saldo pocket akan dikembalikan.")
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func detailRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func deleteTransaksi() {
        // 1. Revert saldo pocket sumber
        if let pocket = transaksi.pocket {
            if transaksi.tipe == .pengeluaran {
                pocket.saldo += transaksi.nominal
            } else {
                pocket.saldo -= transaksi.nominal
            }
        }

        // 2. Rollback target-related side effects
        if transaksi.subTipe != .normal, let target = linkedTarget {
            let cal = Calendar.current

            // Hapus SimpanKeTarget record yang matching (tanggal ±1 menit, nominal sama)
            if let record = target.riwayat.first(where: {
                cal.isDate($0.tanggal, equalTo: transaksi.tanggal, toGranularity: .minute)
                && $0.nominal == transaksi.nominal
            }) {
                modelContext.delete(record)
            }

            // Rollback linkedPocket target biasa (hanya simpanKeTarget yang menambah saldo)
            if transaksi.subTipe == .simpanKeTarget,
               let linkedPocket = target.linkedPocket {
                linkedPocket.saldo -= transaksi.nominal
            }
        }

        modelContext.delete(transaksi)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Transfer detail sheet

struct TransferDetailSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let transfer: TransferInternal

    @State private var showDeleteConfirm = false

    private var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "EEEE, dd MMMM yyyy · HH:mm"
        return f.string(from: transfer.tanggal)
    }

    var body: some View {
        ZStack {
            Color(hex: "#0D0D0D").ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 28))
                        .foregroundStyle(.blue)
                }

                Text("TRANSFER")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.gray)
                    .tracking(1.5)
                    .padding(.top, 10)

                Text(transfer.nominal.idrFormatted)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.blue)
                    .padding(.top, 4)

                // Details
                VStack(spacing: 0) {
                    detailRow(icon: "clock", iconColor: .gray, label: "Tanggal", value: dateString)

                    Divider().background(Color.white.opacity(0.08))
                    detailRow(icon: "wallet.pass", iconColor: .red, label: "Dari", value: transfer.pocketAsal?.nama ?? "-")

                    Divider().background(Color.white.opacity(0.08))
                    detailRow(icon: "wallet.pass.fill", iconColor: .green, label: "Ke", value: transfer.pocketTujuan?.nama ?? "-")

                    if let catatan = transfer.catatan, !catatan.isEmpty {
                        Divider().background(Color.white.opacity(0.08))
                        detailRow(icon: "note.text", iconColor: .yellow, label: "Catatan", value: catatan)
                    }
                }
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
                .padding(.top, 24)

                Spacer()

                Button {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Hapus Transfer")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .confirmationDialog("Hapus Transfer?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Hapus", role: .destructive) { deleteTransfer() }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Transfer ini akan dihapus dan saldo pocket akan dikembalikan.")
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func detailRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func deleteTransfer() {
        if let asal = transfer.pocketAsal { asal.saldo += transfer.nominal }
        if let tujuan = transfer.pocketTujuan { tujuan.saldo -= transfer.nominal }
        modelContext.delete(transfer)
        try? modelContext.save()
        dismiss()
    }
}
