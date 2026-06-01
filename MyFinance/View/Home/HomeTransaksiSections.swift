import SwiftUI

// MARK: - Kategori Teratas

struct HomeKategoriTeratSection: View {
    let kategoriTeratas: [(Kategori, Decimal)]
    let hideBalance: Bool
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.clipboard.fill")
                    .font(.caption).foregroundStyle(theme.accent)
                Text("KATEGORI TERATAS")
                    .font(.caption.weight(.semibold)).foregroundStyle(theme.textSecondary)
            }

            let maxAmount = kategoriTeratas.map { $0.1 }.max() ?? 1
            ForEach(Array(kategoriTeratas.enumerated()), id: \.offset) { _, pair in
                let (kat, amount) = pair
                let progress = (amount / maxAmount as NSDecimalNumber).doubleValue
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color(hex: kat.warna).opacity(0.2)).frame(width: 36, height: 36)
                        if let emoji = kat.ikonCustom {
                            Text(emoji).font(.system(size: 16))
                        } else {
                            Image(systemName: kat.ikon)
                                .foregroundStyle(Color(hex: kat.warna)).font(.system(size: 14))
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(kat.nama).font(.subheadline).foregroundStyle(theme.textPrimary)
                            Spacer()
                            Text(masked(amount.idrFormatted))
                                .font(.subheadline.weight(.semibold)).foregroundStyle(theme.pengeluaran)
                        }
                        ProgressBarView(progress: progress, color: Color(hex: kat.warna), height: 4)
                    }
                }
            }
        }
        .padding(14)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.cardBorder, lineWidth: 1))
        .padding(.horizontal)
    }

    private func masked(_ v: String) -> String { hideBalance ? "••••••" : v }
}

// MARK: - Transaksi Terbaru

struct HomeTerbarSection: View {
    let terbaru: [Transaksi]
    let hideBalance: Bool
    @Environment(\.appTheme) private var theme

    private let accentCyan = Color(hex: "#06B6D4")

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.caption).foregroundStyle(theme.accent)
                Text("TERBARU")
                    .font(.caption.weight(.semibold)).foregroundStyle(theme.textSecondary)
            }

            ForEach(terbaru) { tx in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill((tx.tipe == .pemasukan ? theme.pemasukan : theme.pengeluaran).opacity(0.15))
                            .frame(width: 36, height: 36)
                        if let emoji = tx.kategori?.ikonCustom {
                            Text(emoji).font(.system(size: 16))
                        } else {
                            Image(systemName: tx.kategori?.ikon ?? (tx.tipe == .pemasukan
                                ? "arrow.down.circle.fill" : "arrow.up.circle.fill"))
                                .foregroundStyle(tx.tipe == .pemasukan ? theme.pemasukan : theme.pengeluaran)
                                .font(.system(size: 14))
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tx.kategori?.nama ?? (tx.tipe == .pemasukan ? "Pemasukan" : "Pengeluaran"))
                            .font(.subheadline).foregroundStyle(theme.textPrimary)
                        HStack(spacing: 4) {
                            Text(tx.tipe == .pemasukan ? "Pemasukan" : "Pengeluaran")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(tx.tipe == .pemasukan ? theme.pemasukan : theme.pengeluaran)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background((tx.tipe == .pemasukan ? theme.pemasukan : theme.pengeluaran).opacity(0.15))
                                .clipShape(Capsule())
                            if tx.subTipe != .normal {
                                Text(tx.subTipe.displayName)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(accentCyan)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(accentCyan.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Spacer()

                    Text(masked((tx.tipe == .pemasukan ? "+" : "-") + tx.nominal.idrFormatted))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tx.tipe == .pemasukan ? theme.pemasukan : theme.pengeluaran)
                }
                if tx.id != terbaru.last?.id {
                    Divider().background(theme.separator)
                }
            }
        }
        .padding(14)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.cardBorder, lineWidth: 1))
        .padding(.horizontal)
    }

    private func masked(_ v: String) -> String { hideBalance ? "••••••" : v }
}
