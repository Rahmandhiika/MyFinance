import SwiftUI
import SwiftData
import Charts

struct NetWorthChartCard: View {
    @Environment(\.appTheme) private var theme
    @Query(sort: \NetWorthSnapshot.tahun, order: .forward) private var allSnapshots: [NetWorthSnapshot]

    // Current live values (passed from HomeView)
    let currentKekayaan: Decimal
    let currentCash: Decimal
    let currentAset: Decimal
    let currentHutang: Decimal
    let currentDanaTersimpan: Decimal

    @State private var showDetail = false

    // MARK: - Data

    /// Gabungin snapshot historis + titik "Sekarang" untuk chart
    private var chartPoints: [ChartPoint] {
        let cal = Calendar.current
        let nowMonth = cal.component(.month, from: Date())
        let nowYear  = cal.component(.year, from: Date())

        // Ambil snapshot, max 5 bulan lalu + bulan ini
        let sorted = allSnapshots
            .sorted { ($0.tahun, $0.bulan) < ($1.tahun, $1.bulan) }
            .suffix(5)
            .map { s in
                ChartPoint(bulan: s.bulan, tahun: s.tahun,
                           total: s.totalKekayaan,
                           cash: s.cash, aset: s.totalAset,
                           hutang: s.hutang, dana: s.danaTersimpan)
            }

        // Titik sekarang (live)
        let now = ChartPoint(bulan: nowMonth, tahun: nowYear,
                             total: currentKekayaan,
                             cash: currentCash, aset: currentAset,
                             hutang: currentHutang, dana: currentDanaTersimpan)

        // Filter duplikat (kalau snapshot bulan ini udah ada)
        var points = sorted.filter { !($0.bulan == nowMonth && $0.tahun == nowYear) }
        points.append(now)
        return points
    }

    private var delta: Decimal {
        guard chartPoints.count >= 2 else { return 0 }
        return chartPoints.last!.total - chartPoints[chartPoints.count - 2].total
    }

    private var deltaPct: Double {
        guard chartPoints.count >= 2 else { return 0 }
        let prev = chartPoints[chartPoints.count - 2].total
        guard prev > 0 else { return 0 }
        return Double(truncating: ((chartPoints.last!.total - prev) / prev * 100) as NSDecimalNumber)
    }

    private var deltaPositive: Bool { delta >= 0 }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(theme.accent)
                            .font(.caption)
                        Text("PERTUMBUHAN KEKAYAAN")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.textSecondary)
                    }

                    if chartPoints.count >= 2 {
                        HStack(spacing: 6) {
                            Image(systemName: deltaPositive ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(deltaPositive ? theme.pemasukan : theme.pengeluaran)
                            Text("\(deltaPositive ? "+" : "")\(delta.shortFormatted)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(deltaPositive ? theme.pemasukan : theme.pengeluaran)
                            Text("(\(deltaPositive ? "+" : "")\(String(format: "%.1f", deltaPct))%)")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    } else {
                        Text("Butuh 2 bulan data")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                Spacer()

                // Detail button
                Button {
                    showDetail = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(theme.separator)
                        .clipShape(Circle())
                }
            }

            // Chart
            if chartPoints.isEmpty {
                emptyState
            } else {
                lineChart
            }

            // Bottom legend
            if chartPoints.count >= 2 {
                bottomLegend
            }
        }
        .padding(16)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardBorder, lineWidth: 1))
        .padding(.horizontal)
        .sheet(isPresented: $showDetail) {
            NetWorthDetailSheet(
                chartPoints: chartPoints,
                currentKekayaan: currentKekayaan,
                currentCash: currentCash,
                currentAset: currentAset,
                currentHutang: currentHutang,
                currentDanaTersimpan: currentDanaTersimpan
            )
        }
    }

    // MARK: - Line Chart

    private var lineChart: some View {
        Chart(chartPoints) { point in
            // Area fill
            AreaMark(
                x: .value("Bulan", point.label),
                y: .value("Kekayaan", Double(truncating: point.total as NSDecimalNumber))
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [theme.accent.opacity(0.25), theme.accent.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            // Line
            LineMark(
                x: .value("Bulan", point.label),
                y: .value("Kekayaan", Double(truncating: point.total as NSDecimalNumber))
            )
            .foregroundStyle(theme.accent)
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .interpolationMethod(.catmullRom)

            // Dot titik terakhir saja
            if point.id == chartPoints.last?.id {
                PointMark(
                    x: .value("Bulan", point.label),
                    y: .value("Kekayaan", Double(truncating: point.total as NSDecimalNumber))
                )
                .foregroundStyle(theme.accent)
                .symbolSize(40)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(theme.separator)
                AxisValueLabel {
                    if let d = val.as(Double.self) {
                        Text(Decimal(d).shortFormatted)
                            .font(.system(size: 9))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { val in
                AxisValueLabel {
                    if let s = val.as(String.self) {
                        Text(s)
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
        .frame(height: 120)
    }

    // MARK: - Bottom Legend (breakdown terakhir)

    private var bottomLegend: some View {
        let last = chartPoints.last!
        return HStack(spacing: 0) {
            legendItem(label: "Cash", value: last.cash, color: theme.accent)
            legendItem(label: "Aset", value: last.aset, color: Color(hex: "#3B82F6"))
            legendItem(label: "Dana", value: last.dana, color: Color(hex: "#06B6D4"))
            legendItem(label: "Hutang", value: -last.hutang, color: theme.pengeluaran)
        }
    }

    private func legendItem(label: String, value: Decimal, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            Text(value.shortFormatted)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(value >= 0 ? color : theme.pengeluaran)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundStyle(theme.accent.opacity(0.4))
            Text("Chart akan muncul setelah bulan pertama")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
    }
}

// MARK: - Chart Point Model

struct ChartPoint: Identifiable {
    let id = UUID()
    let bulan: Int
    let tahun: Int
    let total: Decimal
    let cash: Decimal
    let aset: Decimal
    let hutang: Decimal
    let dana: Decimal

    var label: String {
        let months = ["Jan","Feb","Mar","Apr","Mei","Jun",
                      "Jul","Agu","Sep","Okt","Nov","Des"]
        let m = months[max(0, min(bulan - 1, 11))]
        let y = String(tahun).suffix(2)
        return "\(m) '\(y)"
    }
}

// MARK: - Detail Sheet

struct NetWorthDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NetWorthSnapshot.tahun, order: .forward) private var allSnapshots: [NetWorthSnapshot]

    let chartPoints: [ChartPoint]
    let currentKekayaan: Decimal
    let currentCash: Decimal
    let currentAset: Decimal
    let currentHutang: Decimal
    let currentDanaTersimpan: Decimal

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bgApp.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Big chart — lebih tall
                        bigChart
                            .padding(.horizontal)

                        // History table
                        historyTable

                        Spacer().frame(height: 40)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Riwayat Net Worth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.bgApp, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
    }

    private var bigChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOTAL KEKAYAAN")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
            Text(currentKekayaan.idrFormatted)
                .font(.title2.bold())
                .foregroundStyle(theme.textPrimary)

            Chart(chartPoints) { point in
                AreaMark(
                    x: .value("Bulan", point.label),
                    y: .value("Kekayaan", Double(truncating: point.total as NSDecimalNumber))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.accent.opacity(0.3), theme.accent.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Bulan", point.label),
                    y: .value("Kekayaan", Double(truncating: point.total as NSDecimalNumber))
                )
                .foregroundStyle(theme.accent)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Bulan", point.label),
                    y: .value("Kekayaan", Double(truncating: point.total as NSDecimalNumber))
                )
                .foregroundStyle(theme.accent)
                .symbolSize(30)
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(theme.separator)
                    AxisValueLabel {
                        if let d = val.as(Double.self) {
                            Text(Decimal(d).shortFormatted)
                                .font(.system(size: 9))
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { val in
                    AxisValueLabel {
                        if let s = val.as(String.self) {
                            Text(s).font(.system(size: 10)).foregroundStyle(theme.textSecondary)
                        }
                    }
                }
            }
            .frame(height: 200)
        }
        .padding(16)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardBorder, lineWidth: 1))
    }

    private var historyTable: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Bulan")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Cash")
                    .frame(width: 60, alignment: .trailing)
                Text("Aset")
                    .frame(width: 60, alignment: .trailing)
                Text("Total")
                    .frame(width: 70, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().background(theme.separator)

            ForEach(chartPoints.reversed()) { point in
                VStack(spacing: 0) {
                    HStack {
                        Text(point.label)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(point.cash.shortFormatted)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.accent)
                            .frame(width: 60, alignment: .trailing)
                        Text(point.aset.shortFormatted)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#3B82F6"))
                            .frame(width: 60, alignment: .trailing)
                        Text(point.total.shortFormatted)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(theme.textPrimary)
                            .frame(width: 70, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if point.id != chartPoints.first?.id {
                        Divider().background(theme.separator).padding(.horizontal, 16)
                    }
                }
            }
        }
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardBorder, lineWidth: 1))
        .padding(.horizontal)
    }
}
