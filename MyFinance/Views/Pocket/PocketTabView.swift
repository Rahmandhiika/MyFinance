import SwiftUI
import SwiftData

struct PocketTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPockets: [Pocket]

    @State private var showAddPocket = false
    @State private var selectedPocket: Pocket? = nil

    private var activePockets: [Pocket] {
        allPockets.filter { $0.isAktif }
    }

    private var biasaPockets: [Pocket] {
        activePockets.filter { $0.kelompokPocket == .biasa }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var utangPockets: [Pocket] {
        activePockets.filter { $0.kelompokPocket == .utang }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var totalSaldoBiasa: Decimal {
        biasaPockets.reduce(0) { $0 + $1.saldo }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // Total Saldo Header
                        totalSaldoCard

                        // Biasa Section
                        if !biasaPockets.isEmpty {
                            pocketSection(
                                title: "BIASA",
                                pockets: biasaPockets,
                                accentColor: Color(hex: "#22C55E")
                            )
                        }

                        // Utang Section
                        if !utangPockets.isEmpty {
                            pocketSection(
                                title: "UTANG",
                                pockets: utangPockets,
                                accentColor: .red
                            )
                        }

                        if activePockets.isEmpty {
                            emptyState
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 16)
                }

                // FAB
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showAddPocket = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.black)
                                .frame(width: 56, height: 56)
                                .background(Color(hex: "#22C55E"))
                                .clipShape(Circle())
                                .shadow(color: Color(hex: "#22C55E").opacity(0.4), radius: 12, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Pocket")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showAddPocket) {
                AddEditPocketView()
            }
            .sheet(item: $selectedPocket) { pocket in
                PocketDetailSheet(pocket: pocket)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Total Saldo Card

    private var totalSaldoCard: some View {
        VStack(spacing: 6) {
            Text("Total Saldo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.gray)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(totalSaldoBiasa.idrFormatted)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("\(biasaPockets.count) pocket aktif")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Section

    @ViewBuilder
    private func pocketSection(title: String, pockets: [Pocket], accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.gray)
                    .tracking(1)
                Spacer()
                Text("\(pockets.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            VStack(spacing: 1) {
                ForEach(pockets) { pocket in
                    PocketRow(pocket: pocket)
                        .onTapGesture { selectedPocket = pocket }

                    if pocket.id != pockets.last?.id {
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

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 44))
                .foregroundStyle(Color(hex: "#22C55E").opacity(0.5))
            Text("Belum ada pocket")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Tambah pocket pertamamu dengan menekan tombol + di bawah")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 48)
        .padding(.horizontal, 32)
    }
}

// MARK: - Pocket Row

private struct PocketRow: View {
    let pocket: Pocket

    private var isUtang: Bool { pocket.kelompokPocket == .utang }
    private var sisaLimit: Decimal? {
        guard let limit = pocket.limit else { return nil }
        return limit - pocket.saldo
    }
    private var utilizationRatio: Double {
        guard let limit = pocket.limit, limit > 0 else { return 0 }
        return Double(truncating: (pocket.saldo / limit) as NSDecimalNumber)
    }

    var body: some View {
        HStack(spacing: 12) {
            pocketLogo

            VStack(alignment: .leading, spacing: 3) {
                Text(pocket.nama)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                if let kategori = pocket.kategoriPocket {
                    Text(kategori.nama)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                // Utang: limit + sisa + progress bar
                if isUtang, let limit = pocket.limit, let sisa = sisaLimit {
                    HStack(spacing: 8) {
                        Text("Limit \(limit.idrFormatted)")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                        Text("Sisa \(sisa.idrFormatted)")
                            .font(.caption2)
                            .foregroundStyle(sisa < 0 ? .red : .gray)
                    }

                    ProgressBarView(
                        progress: utilizationRatio,
                        color: utilizationRatio > 0.8 ? .red : .orange,
                        height: 3
                    )
                    .frame(maxWidth: 160)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(pocket.saldo.idrFormatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isUtang ? .red : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if isUtang {
                    Text("terpakai")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.25))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var pocketLogo: some View {
        if let logoData = pocket.logo, let uiImage = UIImage(data: logoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 42, height: 42)
                .clipShape(Circle())
        } else {
            let accentColor: Color = isUtang ? .red : Color(hex: "#22C55E")
            Circle()
                .fill(accentColor.opacity(0.18))
                .frame(width: 42, height: 42)
                .overlay(
                    Text(String(pocket.nama.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(accentColor)
                )
        }
    }
}
