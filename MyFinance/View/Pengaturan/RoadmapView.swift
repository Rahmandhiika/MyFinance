import SwiftUI

// MARK: - Data Model

fileprivate enum RoadmapStatus {
    case levelUp
    case comingSoon
    case inDev

    var label: String {
        switch self {
        case .levelUp:    return "Level Up"
        case .comingSoon: return "Coming Soon"
        case .inDev:      return "In Dev"
        }
    }

    var icon: String {
        switch self {
        case .levelUp:    return "arrow.up.circle.fill"
        case .comingSoon: return "clock.fill"
        case .inDev:      return "wrench.and.screwdriver.fill"
        }
    }

    var color: Color {
        switch self {
        case .levelUp:    return Color(hex: "#22C55E")
        case .comingSoon: return Color(hex: "#A78BFA")
        case .inDev:      return Color(hex: "#F59E0B")
        }
    }
}

fileprivate struct RoadmapItem: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: String
    let title: String
    let description: String
    let feature: String       // nama fitur yang di-enhance / fitur baru
    let status: RoadmapStatus
}

// MARK: - Data

private let roadmapItems: [RoadmapItem] = [

    // MARK: Level Up — enhancement fitur existing

    RoadmapItem(
        icon: "camera.viewfinder",
        iconColor: "#F59E0B",
        title: "Scan Struk Otomatis",
        description: "Foto struk belanja → transaksi langsung tercatat. Pakai OCR untuk baca nominal dan toko.",
        feature: "Transaksi",
        status: .levelUp
    ),
    RoadmapItem(
        icon: "bell.badge.fill",
        iconColor: "#EF4444",
        title: "Notifikasi Anggaran",
        description: "Alert otomatis saat pengeluaran mendekati atau melewati limit anggaran bulan ini.",
        feature: "Anggaran",
        status: .levelUp
    ),
    RoadmapItem(
        icon: "chart.line.uptrend.xyaxis",
        iconColor: "#22C55E",
        title: "Grafik Spending Trend",
        description: "Visualisasi tren pengeluaran per kategori dari waktu ke waktu. Bisa lihat pola boros.",
        feature: "Analitik",
        status: .levelUp
    ),
    RoadmapItem(
        icon: "arrow.triangle.2.circlepath",
        iconColor: "#06B6D4",
        title: "Auto-Sweep Tabungan",
        description: "Sisa saldo pocket di akhir bulan otomatis disapu ke pocket tabungan atau target wishlist.",
        feature: "Pocket",
        status: .levelUp
    ),
    RoadmapItem(
        icon: "bell.and.waves.left.and.right.fill",
        iconColor: "#F59E0B",
        title: "Price Alert Saham",
        description: "Set target harga saham / aset, dapat notifikasi saat harga menyentuh target.",
        feature: "Aset",
        status: .levelUp
    ),
    RoadmapItem(
        icon: "heart.text.square.fill",
        iconColor: "#EC4899",
        title: "Kolaborasi Wishlist",
        description: "Bikin wishlist bareng pasangan atau teman — bisa share dan nabung bersama untuk satu tujuan.",
        feature: "Wishlist",
        status: .levelUp
    ),
    RoadmapItem(
        icon: "repeat.circle.fill",
        iconColor: "#8B5CF6",
        title: "Transaksi Berulang",
        description: "Set transaksi rutin (gaji, cicilan, langganan) agar otomatis tercatat tiap periode.",
        feature: "Transaksi",
        status: .levelUp
    ),
    RoadmapItem(
        icon: "chart.pie.fill",
        iconColor: "#A78BFA",
        title: "Breakdown Gaji",
        description: "Distribusi gaji otomatis ke pocket berdasarkan persentase (50/30/20 rule, dll).",
        feature: "Pocket",
        status: .levelUp
    ),

    // MARK: Coming Soon — fitur baru

    RoadmapItem(
        icon: "person.2.fill",
        iconColor: "#22C55E",
        title: "Shared Finance",
        description: "Kelola keuangan bersama pasangan atau keluarga. Transaksi, pocket, dan budget bisa dishare.",
        feature: "Fitur Baru",
        status: .comingSoon
    ),
    RoadmapItem(
        icon: "waveform.circle.fill",
        iconColor: "#06B6D4",
        title: "Input Suara",
        description: "Catat transaksi pakai suara. \"Tadi beli kopi 35 ribu\" → langsung masuk ke transaksi.",
        feature: "Fitur Baru",
        status: .comingSoon
    ),
    RoadmapItem(
        icon: "brain.head.profile",
        iconColor: "#A78BFA",
        title: "AI Financial Advisor",
        description: "Analisis kebiasaan keuangan kamu dan kasih saran yang personal. Kapan bisa nabung lebih, dst.",
        feature: "Fitur Baru",
        status: .comingSoon
    ),
    RoadmapItem(
        icon: "globe",
        iconColor: "#F59E0B",
        title: "Multi-Currency Pocket",
        description: "Pocket dalam mata uang asing (USD, SGD, JPY) dengan konversi real-time.",
        feature: "Fitur Baru",
        status: .comingSoon
    ),
    RoadmapItem(
        icon: "trophy.fill",
        iconColor: "#EF4444",
        title: "Achievement & Streak",
        description: "Reward visual untuk kebiasaan finansial bagus — nabung streak, budget taat, dan lainnya.",
        feature: "Fitur Baru",
        status: .comingSoon
    ),
    RoadmapItem(
        icon: "iphone.and.arrow.left.and.arrow.right",
        iconColor: "#22C55E",
        title: "Sinkronisasi Antar Device",
        description: "Data keuangan tersinkron otomatis di semua iPhone dan iPad kamu via iCloud.",
        feature: "Fitur Baru",
        status: .comingSoon
    ),
]

// MARK: - View

struct RoadmapView: View {
    @Environment(\.appTheme) private var theme
    @State private var selectedFilter: RoadmapFilter = .all

    enum RoadmapFilter: String, CaseIterable {
        case all      = "Semua"
        case levelUp  = "Level Up"
        case comingSoon = "Coming Soon"

        fileprivate var status: RoadmapStatus? {
            switch self {
            case .all:        return nil
            case .levelUp:    return .levelUp
            case .comingSoon: return .comingSoon
            }
        }
    }

    private var filteredItems: [RoadmapItem] {
        guard let status = selectedFilter.status else { return roadmapItems }
        return roadmapItems.filter { $0.status.label == status.label }
    }

    var body: some View {
        ZStack {
            theme.bgApp.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    heroCard
                    filterChips
                    itemsList
                    footerNote
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Roadmap")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(theme.bgApp, for: .navigationBar)
        .toolbarColorScheme(theme.colorScheme == .dark ? .dark : .light, for: .navigationBar)
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .leading) {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "#1D1040"), Color(hex: "#2D1B69")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative circles
            Circle()
                .fill(Color(hex: "#A78BFA").opacity(0.15))
                .frame(width: 120, height: 120)
                .offset(x: 240, y: -30)
            Circle()
                .fill(Color(hex: "#22C55E").opacity(0.1))
                .frame(width: 80, height: 80)
                .offset(x: 280, y: 40)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(hex: "#A78BFA"))
                    Text("WHAT'S NEXT")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(hex: "#A78BFA"))
                        .tracking(1)
                }

                Text("Roadmap\nMyFinance")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                    .lineSpacing(2)

                Text("Fitur yang mau dikembangin\ndan yang akan datang.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineSpacing(3)

                HStack(spacing: 12) {
                    statPill(
                        count: roadmapItems.filter { $0.status.label == RoadmapStatus.levelUp.label }.count,
                        label: "Level Up",
                        color: Color(hex: "#22C55E")
                    )
                    statPill(
                        count: roadmapItems.filter { $0.status.label == RoadmapStatus.comingSoon.label }.count,
                        label: "Coming Soon",
                        color: Color(hex: "#A78BFA")
                    )
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .frame(minHeight: 180)
    }

    private func statPill(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Text("\(count)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(RoadmapFilter.allCases, id: \.rawValue) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectedFilter == filter ? .black : theme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedFilter == filter ? Color(hex: "#22C55E") : theme.bgCard)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Items List

    private var itemsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredItems) { item in
                RoadmapItemCard(item: item)
            }
        }
    }

    // MARK: - Footer

    private var footerNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lightbulb.fill")
                .font(.caption)
                .foregroundStyle(Color(hex: "#F59E0B"))
            Text("Urutan bukan prioritas. Semua ini masih bisa berubah!")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#F59E0B").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.bottom, 8)
    }
}

// MARK: - Item Card

private struct RoadmapItemCard: View {
    let item: RoadmapItem
    @Environment(\.appTheme) private var theme
    @State private var isExpanded = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: item.iconColor).opacity(0.15))
                            .frame(width: 46, height: 46)
                        Image(systemName: item.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(Color(hex: item.iconColor))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 6) {
                            // Feature tag
                            Text(item.feature)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(theme.textSecondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(theme.separator)
                                .clipShape(Capsule())

                            // Status badge
                            HStack(spacing: 3) {
                                Image(systemName: item.status.icon)
                                    .font(.system(size: 8, weight: .bold))
                                Text(item.status.label)
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(item.status.color)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(item.status.color.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(14)

                // Expanded description
                if isExpanded {
                    Divider()
                        .background(theme.separator)
                        .padding(.horizontal, 14)

                    Text(item.description)
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .lineSpacing(4)
                        .padding(14)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(theme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
