import SwiftUI

struct TransaksiGroupSheet: View {
    let title: String
    let transactions: [Transaksi]
    let total: Decimal
    let accent: Color

    private var dateString: (Date) -> String {
        { date in
            let f = DateFormatter()
            f.locale = Locale(identifier: "id_ID")
            f.dateFormat = "dd MMM yyyy · HH:mm"
            return f.string(from: date)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header summary
                    VStack(spacing: 6) {
                        HStack {
                            Text(title)
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(transactions.count) transaksi")
                                .font(.caption)
                                .foregroundStyle(.gray)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        HStack {
                            Text("Total")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                            Spacer()
                            Text(total.idrFormatted)
                                .font(.title3.bold())
                                .foregroundStyle(accent)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.05))

                    if transactions.isEmpty {
                        Spacer()
                        Text("Tidak ada transaksi")
                            .foregroundStyle(.gray)
                            .font(.subheadline)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(transactions) { t in
                                    GroupRowItem(transaksi: t, accent: accent, dateString: dateString)
                                    Divider()
                                        .background(Color.white.opacity(0.06))
                                        .padding(.leading, 74)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Row item

private struct GroupRowItem: View {
    let transaksi: Transaksi
    let accent: Color
    let dateString: (Date) -> String

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: transaksi.kategori?.warna ?? "#6B7280").opacity(0.2))
                    .frame(width: 44, height: 44)
                if let emoji = transaksi.kategori?.ikonCustom, !emoji.isEmpty {
                    Text(emoji).font(.title3)
                } else {
                    Image(systemName: transaksi.kategori?.ikon ?? "tag")
                        .foregroundStyle(Color(hex: transaksi.kategori?.warna ?? "#6B7280"))
                        .font(.system(size: 18))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaksi.kategori?.nama ?? "Tanpa Kategori")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Text(dateString(transaksi.tanggal))
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            Spacer()

            Text(transaksi.nominal.idrFormatted)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
