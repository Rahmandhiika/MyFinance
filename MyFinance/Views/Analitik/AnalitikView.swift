import SwiftUI
import SwiftData
import Charts

// MARK: - Main View

struct AnalitikView: View {
    @Query(sort: \Transaksi.tanggal) var allTransaksi: [Transaksi]
    @State private var selectedMonth: Date = Date()

    // Chart toggle state
    @State private var showPengeluaran: Bool = true
    @State private var showPemasukan: Bool = true
    @State private var showBersih: Bool = true
    @State private var useBarchart: Bool = false

    private let bg = Color(hex: "#0D0D0D")
    private let cardBg = Color.white.opacity(0.05)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    // Month navigator
                    monthNavigator

                    // Summary 2x2
                    summaryGrid

                    // Highlight cards
                    pengeluaranTerbesarCard
                    hariBoroseCard

                    // Tren chart
                    trenSection

                    // Per Kategori
                    perKategoriSection

                    // Per Hari
                    perHariSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Analitik")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button {
                selectedMonth = selectedMonth.addingMonths(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(cardBg)
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(monthRangeLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }

            Spacer()

            Button {
                selectedMonth = selectedMonth.addingMonths(1)
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(cardBg)
                    .clipShape(Circle())
            }
        }
        .padding(.top, 8)
    }

    private var monthRangeLabel: String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: selectedMonth)
        guard let start = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: start) else {
            return selectedMonth.indonesianMonthYear
        }
        let lastDay = range.count
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "id_ID")
        formatter.dateFormat = "MMMM yyyy"
        return "1 - \(lastDay) \(formatter.string(from: start))"
    }

    // MARK: - Summary Grid

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SummaryCard(
                title: "Total Pengeluaran",
                value: totalPengeluaran.shortFormatted,
                fullValue: totalPengeluaran.idrFormatted,
                valueColor: Color(hex: "#FF6B6B"),
                icon: "arrow.down.circle.fill",
                iconColor: Color(hex: "#FF6B6B")
            )
            SummaryCard(
                title: "Total Pemasukan",
                value: totalPemasukan.shortFormatted,
                fullValue: totalPemasukan.idrFormatted,
                valueColor: Color(hex: "#4ADE80"),
                icon: "arrow.up.circle.fill",
                iconColor: Color(hex: "#4ADE80")
            )
            SummaryCard(
                title: "Rata-rata / Hari",
                value: rataRataPerHari.shortFormatted,
                fullValue: rataRataPerHari.idrFormatted,
                valueColor: .white,
                icon: "calendar.day.timeline.left",
                iconColor: Color(hex: "#A78BFA")
            )
            SummaryCard(
                title: "Jml Transaksi",
                value: "\(jumlahTransaksi)",
                fullValue: "\(jumlahTransaksi) transaksi",
                valueColor: .white,
                icon: "list.bullet.rectangle",
                iconColor: Color(hex: "#60A5FA")
            )
        }
    }

    // MARK: - Highlight Cards

    private var pengeluaranTerbesarCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PENGELUARAN TERBESAR")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "#FF6B6B"))
                .tracking(1)

            if let t = pengeluaranTerbesar {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t.nominal.idrFormatted)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        HStack(spacing: 6) {
                            if let kat = t.kategori {
                                Circle()
                                    .fill(Color(hex: kat.warna))
                                    .frame(width: 8, height: 8)
                                Text(kat.nama)
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            } else {
                                Text("Tanpa Kategori")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(dateLabel(t.tanggal))
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.5))
                        Text(dayName(t.tanggal))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            } else {
                Text("Tidak ada data bulan ini")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var hariBoroseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HARI PALING BOROS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "#FBBF24"))
                .tracking(1)

            if let hb = hariBoros {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(hb.total.idrFormatted)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text(dateLabel(hb.date))
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Text(dayName(hb.date))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(hex: "#FBBF24"))
                }
            } else {
                Text("Tidak ada data bulan ini")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Tren Chart Section

    private var trenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TREN")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(1)
                Spacer()
                // Toggle buttons
                HStack(spacing: 6) {
                    ChartToggleButton(label: "Out", isOn: $showPengeluaran, color: Color(hex: "#FF6B6B"))
                    ChartToggleButton(label: "In", isOn: $showPemasukan, color: Color(hex: "#4ADE80"))
                    ChartToggleButton(label: "Net", isOn: $showBersih, color: Color(hex: "#22D3EE"))
                    Button {
                        useBarchart.toggle()
                    } label: {
                        Image(systemName: useBarchart ? "chart.bar.fill" : "chart.line.uptrend.xyaxis")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(6)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            if dailyData.isEmpty {
                emptyChartPlaceholder
            } else {
                trenChart
                trenLegend
            }
        }
        .padding(16)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var trenChart: some View {
        Chart {
            ForEach(dailyData, id: \.date) { item in
                if showPengeluaran {
                    if useBarchart {
                        BarMark(
                            x: .value("Tanggal", item.date, unit: .day),
                            y: .value("Pengeluaran", item.pengeluaran)
                        )
                        .foregroundStyle(Color(hex: "#FF6B6B").opacity(0.8))
                    } else {
                        LineMark(
                            x: .value("Tanggal", item.date, unit: .day),
                            y: .value("Pengeluaran", item.pengeluaran)
                        )
                        .foregroundStyle(Color(hex: "#FF6B6B"))
                        .interpolationMethod(.catmullRom)
                        AreaMark(
                            x: .value("Tanggal", item.date, unit: .day),
                            y: .value("Pengeluaran", item.pengeluaran)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#FF6B6B").opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                if showPemasukan {
                    if useBarchart {
                        BarMark(
                            x: .value("Tanggal", item.date, unit: .day),
                            y: .value("Pemasukan", item.pemasukan)
                        )
                        .foregroundStyle(Color(hex: "#4ADE80").opacity(0.8))
                    } else {
                        LineMark(
                            x: .value("Tanggal", item.date, unit: .day),
                            y: .value("Pemasukan", item.pemasukan)
                        )
                        .foregroundStyle(Color(hex: "#4ADE80"))
                        .interpolationMethod(.catmullRom)
                    }
                }
                if showBersih {
                    if useBarchart {
                        BarMark(
                            x: .value("Tanggal", item.date, unit: .day),
                            y: .value("Bersih", item.bersih)
                        )
                        .foregroundStyle(Color(hex: "#22D3EE").opacity(0.8))
                    } else {
                        LineMark(
                            x: .value("Tanggal", item.date, unit: .day),
                            y: .value("Bersih", item.bersih)
                        )
                        .foregroundStyle(Color(hex: "#22D3EE"))
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(shortDayLabel(date))
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.1))
            }
        }
        .chartYAxis {
            AxisMarks { value in
                if let v = value.as(Double.self) {
                    AxisValueLabel {
                        Text(v.shortFormatted)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.1))
            }
        }
        .chartBackground { _ in
            Color.clear
        }
        .frame(height: 180)
    }

    private var trenLegend: some View {
        HStack(spacing: 16) {
            LegendDot(color: Color(hex: "#FF6B6B"), label: "Pengeluaran")
            LegendDot(color: Color(hex: "#4ADE80"), label: "Pemasukan")
            LegendDot(color: Color(hex: "#22D3EE"), label: "Bersih")
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Per Kategori Section

    private var perKategoriSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PER KATEGORI")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .tracking(1)

            if kategoriData.isEmpty {
                emptyChartPlaceholder
            } else {
                HStack(alignment: .center, spacing: 20) {
                    donutChart
                        .frame(width: 130, height: 130)
                    Spacer()
                }

                VStack(spacing: 8) {
                    ForEach(Array(kategoriData.enumerated()), id: \.offset) { _, item in
                        KategoriAnalitikRow(item: item, total: totalPengeluaran)
                    }
                }
            }
        }
        .padding(16)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var donutChart: some View {
        Chart(Array(kategoriData.enumerated()), id: \.offset) { _, item in
            SectorMark(
                angle: .value("Total", Double(truncating: item.total as NSDecimalNumber)),
                innerRadius: .ratio(0.6),
                angularInset: 1.5
            )
            .foregroundStyle(Color(hex: item.kategori?.warna ?? "#6B7280"))
            .cornerRadius(4)
        }
        .chartBackground { _ in Color.clear }
    }

    // MARK: - Per Hari Section

    private var perHariSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PER HARI")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .tracking(1)

            if weekdayData.allSatisfy({ $0.total == 0 }) {
                emptyChartPlaceholder
            } else {
                Chart(weekdayData, id: \.weekday) { item in
                    BarMark(
                        x: .value("Total", item.total),
                        y: .value("Hari", item.label)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF6B6B").opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks { value in
                        if let v = value.as(Double.self) {
                            AxisValueLabel {
                                Text(v.shortFormatted)
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.1))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        if let label = value.as(String.self) {
                            AxisValueLabel {
                                Text(label)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                }
                .chartBackground { _ in Color.clear }
                .frame(height: 220)
            }
        }
        .padding(16)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Empty Placeholder

    private var emptyChartPlaceholder: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.2))
                Text("Tidak ada data bulan ini")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 24)
            Spacer()
        }
    }

    // MARK: - Computed: Filtered Transaksi

    private var monthTransaksi: [Transaksi] {
        allTransaksi.filter { $0.tanggal.isSameMonth(as: selectedMonth) }
    }

    private var totalPengeluaran: Decimal {
        monthTransaksi
            .filter { $0.tipe == .pengeluaran }
            .reduce(Decimal(0)) { $0 + $1.nominal }
    }

    private var totalPemasukan: Decimal {
        monthTransaksi
            .filter { $0.tipe == .pemasukan }
            .reduce(Decimal(0)) { $0 + $1.nominal }
    }

    private var rataRataPerHari: Decimal {
        let days = daysInSelectedMonth()
        guard days > 0 else { return 0 }
        return totalPengeluaran / Decimal(days)
    }

    private var jumlahTransaksi: Int {
        monthTransaksi.count
    }

    private var pengeluaranTerbesar: Transaksi? {
        monthTransaksi
            .filter { $0.tipe == .pengeluaran }
            .max(by: { $0.nominal < $1.nominal })
    }

    private var hariBoros: (date: Date, total: Decimal)? {
        let pengeluaran = monthTransaksi.filter { $0.tipe == .pengeluaran }
        let cal = Calendar.current
        var dailyTotals: [Date: Decimal] = [:]
        for t in pengeluaran {
            let day = cal.startOfDay(for: t.tanggal)
            dailyTotals[day, default: 0] += t.nominal
        }
        guard let maxEntry = dailyTotals.max(by: { $0.value < $1.value }) else { return nil }
        return (date: maxEntry.key, total: maxEntry.value)
    }

    // MARK: - Computed: Chart Data

    private var dailyData: [(date: Date, pengeluaran: Double, pemasukan: Double, bersih: Double)] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: selectedMonth),
              let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: selectedMonth)) else {
            return []
        }

        var result: [(date: Date, pengeluaran: Double, pemasukan: Double, bersih: Double)] = []
        for day in 0 ..< range.count {
            guard let date = cal.date(byAdding: .day, value: day, to: startOfMonth) else { continue }
            let dayStart = cal.startOfDay(for: date)
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!

            let dayTransaksi = monthTransaksi.filter { $0.tanggal >= dayStart && $0.tanggal < dayEnd }
            let keluar = dayTransaksi.filter { $0.tipe == .pengeluaran }
                .reduce(Decimal(0)) { $0 + $1.nominal }
            let masuk = dayTransaksi.filter { $0.tipe == .pemasukan }
                .reduce(Decimal(0)) { $0 + $1.nominal }

            let keluarD = Double(truncating: keluar as NSDecimalNumber)
            let masukD = Double(truncating: masuk as NSDecimalNumber)

            result.append((
                date: dayStart,
                pengeluaran: keluarD,
                pemasukan: masukD,
                bersih: masukD - keluarD
            ))
        }
        return result
    }

    private var kategoriData: [(kategori: Kategori?, total: Decimal, pct: Double)] {
        let pengeluaran = monthTransaksi.filter { $0.tipe == .pengeluaran }
        var grouped: [UUID?: Decimal] = [:]
        var katMap: [UUID?: Kategori?] = [:]
        for t in pengeluaran {
            let key = t.kategori?.id
            grouped[key, default: 0] += t.nominal
            katMap[key] = t.kategori
        }
        let total = Double(truncating: totalPengeluaran as NSDecimalNumber)
        return grouped
            .map { key, sum in
                let pct = total > 0 ? Double(truncating: sum as NSDecimalNumber) / total * 100 : 0
                return (kategori: katMap[key] ?? nil, total: sum, pct: pct)
            }
            .sorted { $0.total > $1.total }
    }

    private var weekdayData: [(weekday: Int, label: String, total: Double)] {
        let labels = ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"]
        // Calendar weekday: 1=Sun, 2=Mon...7=Sat → map to Mon-Sun index 0-6
        var totals = [Int: Double]()
        for i in 0 ..< 7 { totals[i] = 0 }
        let pengeluaran = monthTransaksi.filter { $0.tipe == .pengeluaran }
        let cal = Calendar.current
        for t in pengeluaran {
            let weekday = cal.component(.weekday, from: t.tanggal) // 1=Sun
            let idx = (weekday + 5) % 7 // Mon=0 .. Sun=6
            totals[idx, default: 0] += Double(truncating: t.nominal as NSDecimalNumber)
        }
        return (0 ..< 7).map { i in (weekday: i, label: labels[i], total: totals[i] ?? 0) }
    }

    // MARK: - Helpers

    private func daysInSelectedMonth() -> Int {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: selectedMonth) else { return 30 }
        return range.count
    }

    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }

    private func dayName(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    private func shortDayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "d"
        return f.string(from: date)
    }
}

// MARK: - Sub-views

private struct SummaryCard: View {
    let title: String
    let value: String
    let fullValue: String
    let valueColor: Color
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
                Spacer()
            }
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct KategoriAnalitikRow: View {
    let item: (kategori: Kategori?, total: Decimal, pct: Double)
    let total: Decimal

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: item.kategori?.warna ?? "#6B7280"))
                    .frame(width: 10, height: 10)
                Text(item.kategori?.nama ?? "Lainnya")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text(String(format: "%.1f%%", item.pct))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                Text(item.total.shortFormatted)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 60, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 4)
                    Capsule()
                        .fill(Color(hex: item.kategori?.warna ?? "#6B7280"))
                        .frame(width: geo.size.width * CGFloat(item.pct / 100), height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
    }
}

private struct ChartToggleButton: View {
    let label: String
    @Binding var isOn: Bool
    let color: Color

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isOn ? color : .gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isOn ? color.opacity(0.15) : Color.white.opacity(0.05))
                .clipShape(Capsule())
        }
    }
}
