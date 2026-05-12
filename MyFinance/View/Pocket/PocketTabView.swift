import SwiftUI
import SwiftData

struct PocketTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    @Query private var allPockets: [Pocket]

    @State private var showAddPocket = false
    @State private var selectedPocket: Pocket? = nil
    @State private var isReordering = false

    private var activePockets: [Pocket] {
        allPockets.filter { $0.isAktif }
    }

    private var biasaPockets: [Pocket] {
        activePockets.filter { $0.kelompokPocket == .biasa }
            .sorted { $0.urutan == $1.urutan ? $0.createdAt < $1.createdAt : $0.urutan < $1.urutan }
    }

    private var utangPockets: [Pocket] {
        activePockets.filter { $0.kelompokPocket == .utang }
            .sorted { $0.urutan == $1.urutan ? $0.createdAt < $1.createdAt : $0.urutan < $1.urutan }
    }

    private var totalSaldoBiasa: Decimal {
        biasaPockets.reduce(0) { $0 + $1.saldo }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bgApp.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // Total Saldo Header
                        totalSaldoCard

                        // Biasa Section
                        if !biasaPockets.isEmpty {
                            biasaSection
                        }

                        // Utang Section
                        if !utangPockets.isEmpty {
                            pocketSection(
                                title: "UTANG",
                                pockets: utangPockets,
                                accentColor: theme.danger
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
                                .foregroundStyle(theme.textOnColor)
                                .frame(width: 56, height: 56)
                                .background(theme.accent)
                                .clipShape(Circle())
                                .shadow(color: theme.accent.opacity(0.4), radius: 12, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Pocket")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(theme.bgApp, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .sheet(isPresented: $showAddPocket) {
                AddEditPocketView()
            }
            .sheet(item: $selectedPocket) { pocket in
                PocketDetailSheet(pocket: pocket)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !biasaPockets.isEmpty {
                        Button(isReordering ? "Selesai" : "Atur Urutan") {
                            isReordering.toggle()
                        }
                        .foregroundStyle(isReordering ? theme.accent : theme.textPrimary.opacity(0.7))
                        .font(.subheadline)
                    }
                }
            }
        }
    }

    // MARK: - Total Saldo Card

    private var totalSaldoCard: some View {
        let isCerah = theme.id == "cerah"
        return VStack(spacing: 6) {
            Text("Total Saldo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isCerah ? .white.opacity(0.85) : theme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(totalSaldoBiasa.idrFormatted)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(isCerah ? .white : theme.textPrimary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("\(biasaPockets.count) pocket aktif")
                .font(.caption)
                .foregroundStyle(isCerah ? .white.opacity(0.7) : theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            isCerah
            ? AnyView(
                LinearGradient(
                    colors: [Color(hex: "#00C4A6"), Color(hex: "#00927B")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            : AnyView(theme.bgCard)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: isCerah ? Color(hex: "#00C4A6").opacity(0.35) : .clear, radius: 12, x: 0, y: 6)
    }

    // MARK: - Biasa Section (with drag reorder)

    private var biasaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BIASA")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.textSecondary)
                    .tracking(1)
                Spacer()
                if isReordering {
                    Text("Seret untuk mengatur urutan")
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                } else {
                    Text("\(biasaPockets.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(theme.accent.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            // List for drag reorder; plain static list when not reordering
            List {
                ForEach(biasaPockets) { pocket in
                    PocketRow(pocket: pocket)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !isReordering { selectedPocket = pocket }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                }
                .onMove { source, destination in
                    var pockets = biasaPockets
                    pockets.move(fromOffsets: source, toOffset: destination)
                    for (index, pocket) in pockets.enumerated() {
                        pocket.urutan = index
                    }
                    try? modelContext.save()
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(biasaPockets.count) * 72)
            .background(theme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
            .environment(\.editMode, isReordering ? .constant(.active) : .constant(.inactive))
        }
    }

    // MARK: - Generic Section (utang, etc.)

    @ViewBuilder
    private func pocketSection(title: String, pockets: [Pocket], accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.textSecondary)
                    .tracking(1)
                Spacer()
                Text("\(pockets.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            VStack(spacing: 1) {
                ForEach(pockets) { pocket in
                    PocketRow(pocket: pocket)
                        .onTapGesture { selectedPocket = pocket }
                    if pocket.id != pockets.last?.id {
                        Divider()
                            .background(theme.separator)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .background(theme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 44))
                .foregroundStyle(theme.accent.opacity(0.5))
            Text("Belum ada pocket")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
            Text("Tambah pocket pertamamu dengan menekan tombol + di bawah")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 48)
        .padding(.horizontal, 32)
    }
}

// MARK: - Pocket Row

private struct PocketRow: View {
    let pocket: Pocket
    @Environment(\.appTheme) private var theme
    @Environment(\.modelContext) private var modelContext

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
                    .foregroundStyle(theme.textPrimary)

                if let kategori = pocket.kategoriPocket {
                    Text(kategori.nama)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }

                // Utang: limit + sisa + progress bar
                if isUtang, let limit = pocket.limit, let sisa = sisaLimit {
                    HStack(spacing: 8) {
                        Text("Limit \(limit.idrDecimalFormatted)")
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                        Text("Sisa \(sisa.idrDecimalFormatted)")
                            .font(.caption2)
                            .foregroundStyle(sisa < 0 ? theme.danger : theme.textSecondary)
                    }

                    ProgressBarView(
                        progress: utilizationRatio,
                        color: utilizationRatio > 0.8 ? theme.danger : .orange,
                        height: 3
                    )
                    .frame(maxWidth: 160)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(pocket.saldo.idrDecimalFormatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isUtang ? theme.danger : (pocket.ikutHitungSisa ? theme.textPrimary : theme.textSecondary.opacity(0.5)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if pocket.saldoUSD > 0 {
                    Text("$\(pocket.saldoUSD.unitFormatted(2))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: "#3B82F6"))
                        .lineLimit(1)
                }

                if isUtang {
                    Text("terpakai")
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                }
            }

            // Toggle ikut hitung sisa — hanya pocket biasa
            if !isUtang {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        pocket.ikutHitungSisa.toggle()
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: pocket.ikutHitungSisa ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(pocket.ikutHitungSisa ? theme.accent : theme.textSecondary.opacity(0.35))
                }
                .buttonStyle(.plain)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.textPrimary.opacity(0.25))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // Palette untuk avatar warna-warni di Cerah theme
    private static let cerahPalette: [Color] = [
        Color(hex: "#00C4A6"), Color(hex: "#FF5A78"), Color(hex: "#F59E0B"),
        Color(hex: "#6366F1"), Color(hex: "#06B6D4"), Color(hex: "#EC4899"),
        Color(hex: "#10B981"), Color(hex: "#F97316")
    ]
    private var avatarColor: Color {
        guard theme.id == "cerah", !isUtang else {
            return isUtang ? theme.danger : theme.accent
        }
        let idx = abs(pocket.nama.hashValue) % Self.cerahPalette.count
        return Self.cerahPalette[idx]
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
            let isCerah = theme.id == "cerah"
            ZStack {
                Circle()
                    .fill(isCerah ? avatarColor : avatarColor.opacity(0.18))
                    .frame(width: 42, height: 42)
                Text(String(pocket.nama.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isCerah ? .white : avatarColor)
            }
        }
    }
}
