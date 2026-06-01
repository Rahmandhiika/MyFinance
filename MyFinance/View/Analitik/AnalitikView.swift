import SwiftUI
import SwiftData
import Charts

// MARK: - Main View

struct AnalitikView: View {
    @Query(sort: \Transaksi.tanggal) var allTransaksi: [Transaksi]
    @Query private var allPockets: [Pocket]
    @Query private var profiles: [UserProfile]
    @Environment(\.appTheme) private var theme
    @State private var selectedMonth: Date = Date()

    // Chart toggle state
    @State private var showPengeluaran: Bool = true
    @State private var showPemasukan: Bool = true
    @State private var showBersih: Bool = true
    @State private var useBarchart: Bool = false

    // Per Kategori tab
    @State private var kategoriTab: TipeTransaksi = .pengeluaran

    // Multi-month trend
    @State private var trendPeriod: Int = 6

    // Siklus Gajian mode — persisted
    @AppStorage("useSiklusGajian") private var useSiklusGajian: Bool = false

    // CSV export — generated on-demand, not on every render
    @State private var cachedCSVURL: URL? = nil

    // MARK: - Static cached DateFormatters
    // DateFormatter creation is expensive (~0.3ms). Cache as static so they're shared
    // across all renders of this view without re-allocation.
    private static let dfMonthShort: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "id_ID"); f.dateFormat = "MMM"; return f
    }()
    private static let dfDMY: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "id_ID"); f.dateFormat = "d MMM yyyy"; return f
    }()
    private static let dfDM: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "id_ID"); f.dateFormat = "d MMM"; return f
    }()
    private static let dfMonthYear: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "id_ID"); f.dateFormat = "MMMM yyyy"; return f
    }()
    private static let dfCSV: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    // MARK: - User settings

    private var tanggalGajian: Int {
        profiles.first?.tanggalGajian ?? 25
    }

    // MARK: - Cycle Date Range

    /// Start of selected period (1st of month, or tanggalGajian of selectedMonth)
    private var cycleStartDate: Date {
        let cal = Calendar.current
        if useSiklusGajian {
            var comps = cal.dateComponents([.year, .month], from: selectedMonth)
            let maxDay = cal.range(of: .day, in: .month, for: selectedMonth)?.count ?? 28
            comps.day = min(tanggalGajian, maxDay)
            return cal.date(from: comps) ?? selectedMonth
        } else {
            var comps = cal.dateComponents([.year, .month], from: selectedMonth)
            comps.day = 1
            return cal.date(from: comps) ?? selectedMonth
        }
    }

    /// End of selected period (last day of month, or day before gajian of next month)
    private var cycleEndDate: Date {
        let cal = Calendar.current
        if useSiklusGajian {
            let nextMonth = selectedMonth.addingMonths(1)
            var comps = cal.dateComponents([.year, .month], from: nextMonth)
            let maxDay = cal.range(of: .day, in: .month, for: nextMonth)?.count ?? 28
            comps.day = min(tanggalGajian, maxDay)
            guard let nextStart = cal.date(from: comps),
                  let end = cal.date(byAdding: .day, value: -1, to: nextStart) else {
                return selectedMonth
            }
            return end
        } else {
            let nextMonth = selectedMonth.addingMonths(1)
            var comps = cal.dateComponents([.year, .month], from: nextMonth)
            comps.day = 1
            guard let firstOfNext = cal.date(from: comps),
                  let end = cal.date(byAdding: .day, value: -1, to: firstOfNext) else {
                return selectedMonth
            }
            return end
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            theme.bgApp.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    monthNavigator
                    cycleToggle


                    // Summary 2x2
                    summaryGrid

                    // Cash Flow (Saldo Awal → Akhir)
                    cashFlowCard

                    // Saving Rate + vs Bulan Lalu
                    savingRateCard
                    vsBulanLaluCard

                    // Auto Insights
                    if !insights.isEmpty { insightCard }

                    // Highlight cards
                    pengeluaranTerbesarCard
                    hariBoroseCard

                    // Tren chart
                    trenSection

                    // Per Kategori
                    perKategoriSection

                    // Per Hari
                    perHariSection

                    // Multi-bulan trend
                    multiMonthTrendSection

                    // Kategori trend lintas bulan
                    kategoriTrendSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .refreshable {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                // SwiftData @Query auto-refresh — cukup haptic trigger
            }
        }
        .navigationTitle("Analitik")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let url = cachedCSVURL {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(theme.textSecondary)
                    }
                } else {
                    // Belum generate — tap untuk generate & share
                    Button { cachedCSVURL = buildCSVFileURL() } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
        }
        // Regenerate CSV hanya saat bulan ganti atau jumlah transaksi berubah
        .onAppear { cachedCSVURL = buildCSVFileURL() }
        .onChange(of: selectedMonth) { cachedCSVURL = buildCSVFileURL() }
        .onChange(of: allTransaksi.count) { cachedCSVURL = nil }   // invalidate — akan re-gen saat tap
    }

    // MARK: - Month Navigator

    private var monthNavigator: some View {
        HStack {
            Button {
                selectedMonth = selectedMonth.addingMonths(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(theme.bgCard)
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(periodLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                selectedMonth = selectedMonth.addingMonths(1)
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(theme.bgCard)
                    .clipShape(Circle())
            }
        }
        .padding(.top, 8)
    }

    private var periodLabel: String {
        let cal = Calendar.current
        if useSiklusGajian {
            let startStr = Self.dfDM.string(from: cycleStartDate)
            let endStr   = Self.dfDMY.string(from: cycleEndDate)
            return "\(startStr) – \(endStr)"
        } else {
            let comps = cal.dateComponents([.year, .month], from: selectedMonth)
            guard let start = cal.date(from: comps),
                  let range = cal.range(of: .day, in: .month, for: start) else {
                return selectedMonth.indonesianMonthYear
            }
            return "1 – \(range.count) \(Self.dfMonthYear.string(from: start))"
        }
    }

    // MARK: - Cycle Toggle

    private var cycleToggle: some View {
        HStack(spacing: 0) {
            Button {
                // @AppStorage dipisah dari withAnimation — tidak boleh dicampur
                useSiklusGajian = false
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.caption.weight(.semibold))
                    Text("Kalender")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(!useSiklusGajian ? theme.textOnColor : theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(!useSiklusGajian ? theme.accent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button {
                // @AppStorage dipisah dari withAnimation — dicampur bisa corrupted render state
                useSiklusGajian = true
                // Auto-jump ke cycle yang lagi berjalan
                let todayDay = Calendar.current.component(.day, from: Date())
                let isCurrentMonth = Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
                if isCurrentMonth && todayDay < tanggalGajian {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMonth = selectedMonth.addingMonths(-1)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.caption.weight(.semibold))
                    Text("Siklus Gajian (Tgl \(tanggalGajian))")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(useSiklusGajian ? theme.textOnColor : theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(useSiklusGajian ? theme.accent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(3)
        .background(theme.separator.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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

    // MARK: - Cash Flow Card (NEW)

    private var cashFlowCard: some View {
        let net = totalPemasukan - totalPengeluaran
        let netPositive = net >= 0
        let saldoAkhir = saldoAwalBulan + net

        return VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.caption)
                    .foregroundStyle(theme.accent)
                Text("ARUS KAS PERIODE INI")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                    .tracking(0.5)
                Spacer()
                if useSiklusGajian {
                    Text("Siklus Tgl \(tanggalGajian)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(theme.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            // Flow rows
            VStack(spacing: 0) {
                // Saldo Awal
                cashFlowRow(
                    icon: "tray.full.fill",
                    label: "Saldo Awal Periode",
                    value: saldoAwalBulan,
                    valueColor: theme.textPrimary,
                    prefix: "",
                    isHighlight: false
                )

                flowDivider

                // Pemasukan
                cashFlowRow(
                    icon: "plus.circle.fill",
                    label: "Pemasukan",
                    value: totalPemasukan,
                    valueColor: Color(hex: "#4ADE80"),
                    prefix: "+",
                    isHighlight: false
                )

                flowDivider

                // Pengeluaran
                cashFlowRow(
                    icon: "minus.circle.fill",
                    label: "Pengeluaran",
                    value: totalPengeluaran,
                    valueColor: Color(hex: "#FF6B6B"),
                    prefix: "−",
                    isHighlight: false
                )

                // Total line
                Rectangle()
                    .fill(theme.separator)
                    .frame(height: 1)
                    .padding(.vertical, 4)

                // Saldo Akhir
                cashFlowRow(
                    icon: "equal.circle.fill",
                    label: "Saldo Saat Ini",
                    value: saldoAkhir,
                    valueColor: saldoAkhir >= 0 ? theme.textPrimary : Color(hex: "#FF6B6B"),
                    prefix: "",
                    isHighlight: true
                )
            }

            // Net change badge
            HStack(spacing: 6) {
                Image(systemName: netPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption.weight(.bold))
                Text("Perubahan bulan ini: \(netPositive ? "+" : "")\(net.shortFormatted)")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(netPositive ? Color(hex: "#4ADE80") : Color(hex: "#FF6B6B"))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background((netPositive ? Color(hex: "#4ADE80") : Color(hex: "#FF6B6B")).opacity(0.1))
            .clipShape(Capsule())
        }
        .padding(16)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.cardBorder, lineWidth: 1))
    }

    private func cashFlowRow(icon: String, label: String, value: Decimal, valueColor: Color, prefix: String, isHighlight: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(valueColor.opacity(0.8))
                .frame(width: 20)
            Text(label)
                .font(isHighlight ? .subheadline.weight(.bold) : .subheadline)
                .foregroundStyle(isHighlight ? theme.textPrimary : theme.textSecondary)
            Spacer()
            Text("\(prefix)\(value.shortFormatted)")
                .font(isHighlight ? .subheadline.weight(.bold) : .subheadline.weight(.semibold))
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, 8)
    }

    private var flowDivider: some View {
        HStack {
            Spacer().frame(width: 30)
            Rectangle().fill(theme.separator).frame(height: 0.5)
        }
    }

    // MARK: - Saving Rate Card

    private var savingRateCard: some View {
        // Saving rate based on income (traditional definition)
        // If no income this period but still have carryover, show carryover usage rate
        let rate = savingRate
        let rateColor: Color = rate >= 20 ? Color(hex: "#4ADE80")
                             : rate >= 0  ? Color(hex: "#FBBF24")
                             : Color(hex: "#FF6B6B")
        let rateLabel: String = rate >= 30 ? "Excellent! 🎉"
                              : rate >= 20 ? "Bagus 👍"
                              : rate >= 10 ? "Bisa Lebih Baik 💡"
                              : rate >= 0  ? "Perhatian ⚠️"
                              : "Defisit! 🚨"
        let netBalance = totalPemasukan - totalPengeluaran
        let noIncome = totalPemasukan == 0

        return HStack(spacing: 16) {
            // Gauge
            ZStack {
                Circle()
                    .stroke(rateColor.opacity(0.15), lineWidth: 7)
                    .frame(width: 72, height: 72)
                if !noIncome {
                    Circle()
                        .trim(from: 0, to: min(max(CGFloat(rate) / 100.0, 0), 1))
                        .stroke(rateColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 72, height: 72)
                        .animation(.easeOut(duration: 0.6), value: rate)
                }
                VStack(spacing: 1) {
                    if noIncome {
                        Image(systemName: "moon.zzz.fill")
                            .font(.title3)
                            .foregroundStyle(theme.textSecondary.opacity(0.5))
                    } else {
                        Text(rate < 0 ? "–" : "\(Int(rate))%")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(rateColor)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.pie.fill")
                        .font(.caption)
                        .foregroundStyle(noIncome ? theme.textSecondary : rateColor)
                    Text("SAVING RATE")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                        .tracking(0.5)
                }
                if noIncome {
                    Text("Belum ada pemasukan")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                    Text("(Saldo awal masih cukup)")
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
                } else {
                    Text(rateLabel)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(rateColor)
                    HStack(spacing: 4) {
                        Image(systemName: netBalance >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text("Net: \(netBalance >= 0 ? "+" : "")\(netBalance.shortFormatted)")
                            .font(.caption)
                    }
                    .foregroundStyle(netBalance >= 0 ? Color(hex: "#4ADE80") : Color(hex: "#FF6B6B"))
                }
            }

            Spacer()

            if !noIncome && rate < 20 {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Target 20%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                    let targetSaving = totalPemasukan * Decimal(0.2)
                    let selisih = targetSaving - (totalPemasukan - totalPengeluaran)
                    if selisih > 0 {
                        Text("Kurangi")
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                        Text(selisih.shortFormatted)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color(hex: "#FBBF24"))
                    }
                }
            }
        }
        .padding(16)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(
            (noIncome ? theme.cardBorder : rateColor.opacity(0.2)), lineWidth: 1
        ))
    }

    // MARK: - vs Bulan Lalu Card

    private var vsBulanLaluCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption)
                    .foregroundStyle(theme.accent)
                Text("VS PERIODE LALU")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                    .tracking(0.5)
                Spacer()
                Text(prevMonthDate.indonesianMonthYear)
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }

            if prevMonthTransaksi.isEmpty {
                Text("Tidak ada data periode lalu")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    comparisonRow(label: "Pengeluaran", current: totalPengeluaran, prev: prevTotalPengeluaran, isExpense: true)
                    Divider().background(theme.separator)
                    comparisonRow(label: "Pemasukan", current: totalPemasukan, prev: prevTotalPemasukan, isExpense: false)
                    Divider().background(theme.separator)
                    comparisonRow(
                        label: "Net Balance",
                        current: totalPemasukan - totalPengeluaran,
                        prev: prevTotalPemasukan - prevTotalPengeluaran,
                        isExpense: false
                    )
                }
            }
        }
        .padding(16)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.cardBorder, lineWidth: 1))
    }

    private func comparisonRow(label: String, current: Decimal, prev: Decimal, isExpense: Bool) -> some View {
        let pct = pctChange(current, prev)
        let pctColor: Color = {
            if pct == 0 { return theme.textSecondary }
            let up = pct > 0
            return (isExpense ? !up : up) ? Color(hex: "#4ADE80") : Color(hex: "#FF6B6B")
        }()
        let arrow = pct > 0 ? "arrow.up.right" : "arrow.down.right"

        return HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 90, alignment: .leading)
            Spacer()
            Text(prev.shortFormatted)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .frame(width: 72, alignment: .trailing)
            Image(systemName: "arrow.right")
                .font(.system(size: 9))
                .foregroundStyle(theme.textSecondary.opacity(0.4))
                .frame(width: 20)
            Text(current.shortFormatted)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 72, alignment: .trailing)
            if pct != 0 {
                HStack(spacing: 2) {
                    Image(systemName: arrow).font(.system(size: 9, weight: .bold))
                    Text("\(String(format: "%.0f", abs(pct)))%")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(pctColor)
                .frame(width: 44, alignment: .trailing)
            } else {
                Text("=")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 44, alignment: .trailing)
            }
        }
    }

    // MARK: - Auto Insight Card

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#FBBF24"))
                Text("INSIGHT")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                    .tracking(0.5)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(insights, id: \.self) { text in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(theme.accent.opacity(0.4))
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)
                        Text(text)
                            .font(.subheadline)
                            .foregroundStyle(theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(hex: "#FBBF24").opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#FBBF24").opacity(0.2), lineWidth: 1))
    }

    // MARK: - Highlight Cards

    private var pengeluaranTerbesarCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PENGELUARAN TERBESAR")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: "#FF6B6B"))
                .tracking(1)
            if let t = pengeluaranTerbesar {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t.nominal.idrFormatted)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(theme.textPrimary)
                        HStack(spacing: 6) {
                            if let kat = t.kategori {
                                Circle().fill(Color(hex: kat.warna)).frame(width: 8, height: 8)
                                Text(kat.nama).font(.system(size: 13)).foregroundStyle(theme.textSecondary)
                            } else {
                                Text("Tanpa Kategori").font(.system(size: 13)).foregroundStyle(theme.textSecondary)
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(dateLabel(t.tanggal)).font(.system(size: 12)).foregroundStyle(theme.textSecondary)
                        Text(dayName(t.tanggal)).font(.system(size: 12, weight: .medium)).foregroundStyle(theme.textSecondary)
                    }
                }
            } else {
                Text("Tidak ada data periode ini").font(.system(size: 14)).foregroundStyle(theme.textSecondary)
            }
        }
        .padding(16)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var hariBoroseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HARI PALING BOROS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: "#FBBF24"))
                .tracking(1)
            if let hb = hariBoros {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(hb.total.idrFormatted).font(.system(size: 20, weight: .bold)).foregroundStyle(theme.textPrimary)
                        Text(dateLabel(hb.date)).font(.system(size: 13)).foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    Text(dayName(hb.date)).font(.system(size: 22, weight: .bold)).foregroundStyle(Color(hex: "#FBBF24"))
                }
            } else {
                Text("Tidak ada data periode ini").font(.system(size: 14)).foregroundStyle(theme.textSecondary)
            }
        }
        .padding(16)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Tren Chart Section

    private var trenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TREN")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .tracking(1)
                Spacer()
                HStack(spacing: 6) {
                    ChartToggleButton(label: "Out", isOn: $showPengeluaran, color: Color(hex: "#FF6B6B"))
                    ChartToggleButton(label: "In", isOn: $showPemasukan, color: Color(hex: "#4ADE80"))
                    ChartToggleButton(label: "Net", isOn: $showBersih, color: Color(hex: "#22D3EE"))
                    Button {
                        useBarchart.toggle()
                    } label: {
                        Image(systemName: useBarchart ? "chart.bar.fill" : "chart.line.uptrend.xyaxis")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.textPrimary.opacity(0.8))
                            .padding(6)
                            .background(theme.separator)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            if dailyData.isEmpty { emptyChartPlaceholder }
            else { trenChart; trenLegend }
        }
        .padding(16)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var trenChart: some View {
        Chart {
            ForEach(dailyData, id: \.date) { item in
                if showPengeluaran {
                    if useBarchart {
                        BarMark(x: .value("Tanggal", item.date, unit: .day), y: .value("Pengeluaran", item.pengeluaran))
                            .foregroundStyle(Color(hex: "#FF6B6B").opacity(0.8))
                    } else {
                        LineMark(x: .value("Tanggal", item.date, unit: .day), y: .value("Pengeluaran", item.pengeluaran))
                            .foregroundStyle(Color(hex: "#FF6B6B")).interpolationMethod(.catmullRom)
                        AreaMark(x: .value("Tanggal", item.date, unit: .day), y: .value("Pengeluaran", item.pengeluaran))
                            .foregroundStyle(LinearGradient(colors: [Color(hex: "#FF6B6B").opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                    }
                }
                if showPemasukan {
                    if useBarchart {
                        BarMark(x: .value("Tanggal", item.date, unit: .day), y: .value("Pemasukan", item.pemasukan))
                            .foregroundStyle(Color(hex: "#4ADE80").opacity(0.8))
                    } else {
                        LineMark(x: .value("Tanggal", item.date, unit: .day), y: .value("Pemasukan", item.pemasukan))
                            .foregroundStyle(Color(hex: "#4ADE80")).interpolationMethod(.catmullRom)
                    }
                }
                if showBersih {
                    if useBarchart {
                        BarMark(x: .value("Tanggal", item.date, unit: .day), y: .value("Bersih", item.bersih))
                            .foregroundStyle(Color(hex: "#22D3EE").opacity(0.8))
                    } else {
                        LineMark(x: .value("Tanggal", item.date, unit: .day), y: .value("Bersih", item.bersih))
                            .foregroundStyle(Color(hex: "#22D3EE")).interpolationMethod(.catmullRom)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel { Text(shortDayLabel(date)).font(.system(size: 10)).foregroundStyle(theme.textSecondary) }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(theme.separator)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                if let v = value.as(Double.self) {
                    AxisValueLabel { Text(v.shortFormatted).font(.system(size: 10)).foregroundStyle(theme.textSecondary) }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(theme.separator)
            }
        }
        .chartBackground { _ in Color.clear }
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
            HStack {
                Text("PER KATEGORI").font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.textSecondary).tracking(1)
                Spacer()
            }
            HStack(spacing: 0) {
                ForEach([TipeTransaksi.pengeluaran, .pemasukan], id: \.self) { tipe in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { kategoriTab = tipe }
                    } label: {
                        Text(tipe == .pengeluaran ? "Pengeluaran" : "Pemasukan")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(kategoriTab == tipe ? .black : theme.textSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(kategoriTab == tipe ? (tipe == .pengeluaran ? Color(hex: "#FF6B6B") : Color(hex: "#4ADE80")) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(4).background(theme.separator).clipShape(RoundedRectangle(cornerRadius: 10))

            let rawData   = kategoriTab == .pengeluaran ? kategoriDataPengeluaran : kategoriDataPemasukan
            // Deduplicate by name — nama duplikat (mis. setelah restore backup) crash Swift Charts
            let activeData: [(kategori: Kategori?, total: Decimal, pct: Double)] = rawData.reduce(into: []) { out, item in
                let key = item.kategori?.nama ?? "Lainnya"
                if let idx = out.firstIndex(where: { ($0.kategori?.nama ?? "Lainnya") == key }) {
                    let merged = out[idx].total + item.total
                    let newPct = (item.kategori?.nama == nil) ? out[idx].pct : out[idx].pct + item.pct
                    out[idx] = (kategori: out[idx].kategori, total: merged, pct: newPct)
                } else {
                    out.append(item)
                }
            }

            if activeData.isEmpty { emptyChartPlaceholder }
            else {
                // Donut + mini legend
                HStack(alignment: .center, spacing: 16) {
                    donutChart(data: activeData).frame(width: 110, height: 110)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(activeData.prefix(5).enumerated()), id: \.offset) { _, item in
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color(hex: item.kategori?.warna ?? "#6B7280"))
                                    .frame(width: 8, height: 8)
                                Text(item.kategori?.nama ?? "Lainnya")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text(String(format: "%.0f%%", item.pct))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        if activeData.count > 5 {
                            Text("+\(activeData.count - 5) lainnya")
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textSecondary.opacity(0.6))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Horizontal BarMark — gunakan chartPlotStyle untuk tinggi agar tidak
                // menyebabkan infinite layout loop di LazyVStack (dynamic frame = feedback loop)
                Chart(Array(activeData.enumerated()), id: \.offset) { _, item in
                    BarMark(
                        x: .value("Jumlah", (item.total as NSDecimalNumber).doubleValue),
                        y: .value("Kategori", item.kategori?.nama ?? "Lainnya")
                    )
                    .foregroundStyle(Color(hex: item.kategori?.warna ?? "#6B7280"))
                    .cornerRadius(4)
                    .accessibilityLabel("\(item.kategori?.nama ?? "Lainnya"): \(item.total.shortFormatted) (\(String(format: "%.0f", item.pct))%)")
                }
                .chartPlotStyle { plot in
                    // Fixed plot area per bar — tidak bergantung pada GeometryReader luar
                    plot.frame(height: CGFloat(activeData.count) * 36)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(theme.separator)
                        AxisValueLabel {
                            if let v = val.as(Double.self) {
                                Text(v.shortFormatted)
                                    .font(.system(size: 9))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { val in
                        AxisValueLabel {
                            if let s = val.as(String.self) {
                                Text(s)
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.textPrimary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .chartBackground { _ in Color.clear }
            }
        }
        .padding(16).background(theme.bgCard).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func donutChart(data: [(kategori: Kategori?, total: Decimal, pct: Double)]) -> some View {
        Chart(Array(data.enumerated()), id: \.offset) { _, item in
            SectorMark(angle: .value("Total", Double(truncating: item.total as NSDecimalNumber)), innerRadius: .ratio(0.6), angularInset: 1.5)
                .foregroundStyle(Color(hex: item.kategori?.warna ?? "#6B7280")).cornerRadius(4)
        }
        .chartBackground { _ in Color.clear }
    }

    // MARK: - Per Hari Section

    private var perHariSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PER HARI").font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.textSecondary).tracking(1)
            if weekdayData.allSatisfy({ $0.total == 0 }) { emptyChartPlaceholder }
            else {
                Chart(weekdayData, id: \.weekday) { item in
                    BarMark(x: .value("Total", item.total), y: .value("Hari", item.label))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: "#FF6B6B"), Color(hex: "#FF6B6B").opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks { value in
                        if let v = value.as(Double.self) {
                            AxisValueLabel { Text(v.shortFormatted).font(.system(size: 10)).foregroundStyle(theme.textSecondary) }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(theme.separator)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        if let label = value.as(String.self) {
                            AxisValueLabel { Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(theme.textPrimary) }
                        }
                    }
                }
                .chartBackground { _ in Color.clear }
                .frame(height: 220)
            }
        }
        .padding(16).background(theme.bgCard).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Empty Placeholder

    private var emptyChartPlaceholder: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis").font(.system(size: 28)).foregroundStyle(theme.textSecondary.opacity(0.5))
                Text("Tidak ada data periode ini").font(.system(size: 13)).foregroundStyle(theme.textSecondary)
            }
            .padding(.vertical, 24)
            Spacer()
        }
    }

    // MARK: - Computed: Filtered Transaksi

    private var monthTransaksi: [Transaksi] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: cycleStartDate)
        let endInclusive = cal.startOfDay(for: cycleEndDate)
        guard let endExclusive = cal.date(byAdding: .day, value: 1, to: endInclusive) else { return [] }
        return allTransaksi.filter { $0.tanggal >= start && $0.tanggal < endExclusive }
    }

    private var prevMonthDate: Date { selectedMonth.addingMonths(-1) }

    private var prevMonthTransaksi: [Transaksi] {
        // Previous period uses same cycle logic shifted by 1 month
        let cal = Calendar.current
        let prevSelected = selectedMonth.addingMonths(-1)
        let prevCycleStart: Date
        let prevCycleEnd: Date

        if useSiklusGajian {
            var startComps = cal.dateComponents([.year, .month], from: prevSelected)
            startComps.day = min(tanggalGajian, cal.range(of: .day, in: .month, for: prevSelected)?.count ?? 28)
            prevCycleStart = cal.date(from: startComps) ?? prevSelected

            var endComps = cal.dateComponents([.year, .month], from: selectedMonth)
            endComps.day = min(tanggalGajian, cal.range(of: .day, in: .month, for: selectedMonth)?.count ?? 28)
            let thisStart = cal.date(from: endComps) ?? selectedMonth
            prevCycleEnd = cal.date(byAdding: .day, value: -1, to: thisStart) ?? selectedMonth
        } else {
            var startComps = cal.dateComponents([.year, .month], from: prevSelected)
            startComps.day = 1
            prevCycleStart = cal.date(from: startComps) ?? prevSelected

            var endComps = cal.dateComponents([.year, .month], from: selectedMonth)
            endComps.day = 1
            let thisStart = cal.date(from: endComps) ?? selectedMonth
            prevCycleEnd = cal.date(byAdding: .day, value: -1, to: thisStart) ?? selectedMonth
        }

        let start = cal.startOfDay(for: prevCycleStart)
        let endExclusive = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: prevCycleEnd))!
        return allTransaksi.filter { $0.tanggal >= start && $0.tanggal < endExclusive }
    }

    private var totalPengeluaran: Decimal {
        monthTransaksi.filter { $0.tipe == .pengeluaran }.reduce(Decimal(0)) { $0 + $1.nominal }
    }

    private var totalPemasukan: Decimal {
        monthTransaksi.filter { $0.tipe == .pemasukan }.reduce(Decimal(0)) { $0 + $1.nominal }
    }

    private var prevTotalPengeluaran: Decimal {
        prevMonthTransaksi.filter { $0.tipe == .pengeluaran }.reduce(Decimal(0)) { $0 + $1.nominal }
    }

    private var prevTotalPemasukan: Decimal {
        prevMonthTransaksi.filter { $0.tipe == .pemasukan }.reduce(Decimal(0)) { $0 + $1.nominal }
    }

    /// Saldo di semua pocket SEBELUM periode ini dimulai
    /// = totalPocketSekarang - net semua transaksi dari cycleStart sampai sekarang
    private var saldoAwalBulan: Decimal {
        let cal = Calendar.current
        let start = cal.startOfDay(for: cycleStartDate)
        let totalPocketNow = allPockets.reduce(Decimal(0)) { $0 + $1.saldo }

        let txFromStart = allTransaksi.filter { $0.tanggal >= start }
        let pemasukanFromStart = txFromStart.filter { $0.tipe == .pemasukan }.reduce(Decimal(0)) { $0 + $1.nominal }
        let pengeluaranFromStart = txFromStart.filter { $0.tipe == .pengeluaran }.reduce(Decimal(0)) { $0 + $1.nominal }

        return totalPocketNow - pemasukanFromStart + pengeluaranFromStart
    }

    private var savingRate: Double {
        guard totalPemasukan > 0 else { return 0 }
        let net = totalPemasukan - totalPengeluaran
        return Double(truncating: (net / totalPemasukan * 100) as NSDecimalNumber)
    }

    private func pctChange(_ current: Decimal, _ prev: Decimal) -> Double {
        guard prev != 0 else { return 0 }
        return Double(truncating: ((current - prev) / abs(prev) * 100) as NSDecimalNumber)
    }

    private var rataRataPerHari: Decimal {
        let cal = Calendar.current
        let components = cal.dateComponents([.day], from: cycleStartDate, to: cycleEndDate)
        let days = max(1, (components.day ?? 0) + 1)
        return totalPengeluaran / Decimal(days)
    }

    private var jumlahTransaksi: Int { monthTransaksi.count }

    private var pengeluaranTerbesar: Transaksi? {
        monthTransaksi.filter { $0.tipe == .pengeluaran }.max(by: { $0.nominal < $1.nominal })
    }

    private var hariBoros: (date: Date, total: Decimal)? {
        let pengeluaran = monthTransaksi.filter { $0.tipe == .pengeluaran }
        let cal = Calendar.current
        var dailyTotals: [Date: Decimal] = [:]
        for t in pengeluaran {
            dailyTotals[cal.startOfDay(for: t.tanggal), default: 0] += t.nominal
        }
        guard let maxEntry = dailyTotals.max(by: { $0.value < $1.value }) else { return nil }
        return (date: maxEntry.key, total: maxEntry.value)
    }

    // MARK: - Auto Insights

    private var insights: [String] {
        var list: [String] = []

        if totalPemasukan > 0 {
            let r = Int(savingRate)
            if savingRate >= 30 {
                list.append("Saving rate \(r)% periode ini — luar biasa! Tetap pertahankan 💪")
            } else if savingRate >= 20 {
                list.append("Saving rate \(r)% — sudah melewati target 20%. Kerja bagus! 👍")
            } else if savingRate >= 0 {
                list.append("Saving rate baru \(r)%. Kurangi pengeluaran untuk capai target 20% 💡")
            } else {
                list.append("Pengeluaran melebihi pemasukan periode ini. Tinjau kembali kebiasaan belanja ⚠️")
            }
        } else {
            // No income yet — show carryover context
            let saldoAkhirEstimasi = saldoAwalBulan - totalPengeluaran
            if saldoAwalBulan > 0 {
                list.append("Gaji belum masuk — saldo awal \(saldoAwalBulan.shortFormatted) masih cukup untuk sementara 💰")
                if saldoAkhirEstimasi > 0 {
                    list.append("Sisa saldo setelah pengeluaran: \(saldoAkhirEstimasi.shortFormatted)")
                }
            }
        }

        if prevTotalPengeluaran > 0 {
            let pct = pctChange(totalPengeluaran, prevTotalPengeluaran)
            if pct > 5 {
                list.append("Pengeluaran naik \(String(format: "%.0f", pct))% dibanding periode lalu. Kategori terbesar: \(kategoriDataPengeluaran.first?.kategori?.nama ?? "-")")
            } else if pct < -5 {
                list.append("Pengeluaran turun \(String(format: "%.0f", abs(pct)))% vs periode lalu — penghematan yang bagus! 📉")
            }
        }

        if let top = kategoriDataPengeluaran.first, let kat = top.kategori {
            list.append("\"\(kat.nama)\" menyumbang \(String(format: "%.0f", top.pct))% dari total pengeluaran periode ini")
        }

        if let hb = hariBoros {
            list.append("Hari \(dayName(hb.date)) adalah hari paling boros: \(hb.total.shortFormatted) dalam sehari")
        }

        return Array(list.prefix(3))
    }

    // MARK: - CSV Export

    private var csvString: String {
        // Gunakan cached static formatter — hindari alloc baru tiap kali
        var lines = ["Tanggal,Tipe,Kategori,Nominal,Catatan,Pocket"]
        for t in monthTransaksi.sorted(by: { $0.tanggal < $1.tanggal }) {
            let tanggal = Self.dfCSV.string(from: t.tanggal)
            let tipe    = t.tipe == .pengeluaran ? "Pengeluaran" : "Pemasukan"
            let kat     = t.kategori?.nama ?? "-"
            let nominal = "\(t.nominal)"
            let catatan = (t.catatan ?? "").replacingOccurrences(of: ",", with: ";")
            let pocket  = t.pocket?.nama ?? "-"
            lines.append("\(tanggal),\(tipe),\(kat),\(nominal),\(catatan),\(pocket)")
        }
        return lines.joined(separator: "\n")
    }

    /// Tulis CSV ke temp file dan return URL-nya.
    /// Dipanggil hanya saat month berubah atau user tap tombol share — bukan tiap render.
    private func buildCSVFileURL() -> URL {
        let dir   = FileManager.default.temporaryDirectory
        let label = useSiklusGajian
            ? "siklus_\(tanggalGajian)_\(selectedMonth.indonesianMonthYear)"
            : selectedMonth.indonesianMonthYear
        let name  = "transaksi_\(label.replacingOccurrences(of: " ", with: "_").lowercased()).csv"
        let url   = dir.appendingPathComponent(name)
        try? csvString.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Computed: Chart Data

    private var dailyData: [(date: Date, pengeluaran: Double, pemasukan: Double, bersih: Double)] {
        let cal = Calendar.current

        // O(n) — group transactions by day start once, avoid re-scanning per day
        var grouped: [Date: (pengeluaran: Double, pemasukan: Double)] = [:]
        for tx in monthTransaksi {
            let day    = cal.startOfDay(for: tx.tanggal)
            let amount = Double(truncating: tx.nominal as NSDecimalNumber)
            var entry  = grouped[day] ?? (0, 0)
            if tx.tipe == .pengeluaran { entry.pengeluaran += amount }
            else                       { entry.pemasukan   += amount }
            grouped[day] = entry
        }

        // O(days) — iterate calendar days and lookup
        var result: [(date: Date, pengeluaran: Double, pemasukan: Double, bersih: Double)] = []
        var current = cal.startOfDay(for: cycleStartDate)
        let end     = cal.startOfDay(for: cycleEndDate)
        while current <= end {
            let entry  = grouped[current] ?? (0, 0)
            result.append((date: current,
                           pengeluaran: entry.pengeluaran,
                           pemasukan:   entry.pemasukan,
                           bersih:      entry.pemasukan - entry.pengeluaran))
            guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    private var kategoriDataPengeluaran: [(kategori: Kategori?, total: Decimal, pct: Double)] {
        buildKategoriData(tipe: .pengeluaran, totalRef: totalPengeluaran)
    }
    private var kategoriDataPemasukan: [(kategori: Kategori?, total: Decimal, pct: Double)] {
        buildKategoriData(tipe: .pemasukan, totalRef: totalPemasukan)
    }
    private func buildKategoriData(tipe: TipeTransaksi, totalRef: Decimal) -> [(kategori: Kategori?, total: Decimal, pct: Double)] {
        let filtered = monthTransaksi.filter { $0.tipe == tipe }
        var grouped: [UUID?: Decimal] = [:]
        var katMap: [UUID?: Kategori?] = [:]
        for t in filtered {
            let key = t.kategori?.id
            grouped[key, default: 0] += t.nominal
            katMap[key] = t.kategori
        }
        let total = Double(truncating: totalRef as NSDecimalNumber)
        return grouped.map { key, sum in
            let pct = total > 0 ? Double(truncating: sum as NSDecimalNumber) / total * 100 : 0
            return (kategori: katMap[key] ?? nil, total: sum, pct: pct)
        }.sorted { $0.total > $1.total }
    }

    private var weekdayData: [(weekday: Int, label: String, total: Double)] {
        let labels = ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"]
        var totals = [Int: Double]()
        for i in 0..<7 { totals[i] = 0 }
        let cal = Calendar.current
        for t in monthTransaksi.filter({ $0.tipe == .pengeluaran }) {
            let idx = (cal.component(.weekday, from: t.tanggal) + 5) % 7
            totals[idx, default: 0] += Double(truncating: t.nominal as NSDecimalNumber)
        }
        return (0..<7).map { i in (weekday: i, label: labels[i], total: totals[i] ?? 0) }
    }

    // MARK: - Multi-Month Trend Data

    private struct MonthTrendPoint: Identifiable {
        let id = UUID()
        let month: Date
        let label: String         // "Jan", "Feb", dst
        let pengeluaran: Double
        let pemasukan: Double
        var savingRate: Double { pemasukan > 0 ? (pemasukan - pengeluaran) / pemasukan * 100 : 0 }
    }

    private var multiMonthData: [MonthTrendPoint] {
        let cal = Calendar.current

        // O(n) — pre-group all transactions by "yyyy-M" key (avoids N filter passes)
        var txByMonth: [String: (out: Double, inc: Double)] = [:]
        for tx in allTransaksi {
            let c   = cal.dateComponents([.year, .month], from: tx.tanggal)
            let key = "\(c.year!)-\(c.month!)"
            let amt = Double(truncating: tx.nominal as NSDecimalNumber)
            var entry = txByMonth[key] ?? (0, 0)
            if tx.tipe == .pengeluaran { entry.out += amt } else { entry.inc += amt }
            txByMonth[key] = entry
        }

        return (0..<trendPeriod).reversed().compactMap { offset in
            let monthDate = selectedMonth.addingMonths(-offset)
            let c   = cal.dateComponents([.year, .month], from: monthDate)
            let key = "\(c.year!)-\(c.month!)"
            let entry = txByMonth[key] ?? (0, 0)
            return MonthTrendPoint(month: monthDate,
                                   label: Self.dfMonthShort.string(from: monthDate),
                                   pengeluaran: entry.out,
                                   pemasukan: entry.inc)
        }
    }

    // Top 4 kategori pengeluaran selama periode tren, tiap bulan totalnya berapa
    private struct KategoriTrendPoint: Identifiable {
        let id = UUID()
        let monthLabel: String
        let kategoriNama: String
        let warna: String
        let total: Double
    }

    /// Top 4 kategori pengeluaran selama trendPeriod bulan terakhir.
    /// Menggunakan UUID sebagai key internal — rename kategori tidak pecah histori chart.
    private var topKategori: [(id: String, nama: String, warna: String)] {
        let cal = Calendar.current
        let oldestMonth = selectedMonth.addingMonths(-(trendPeriod - 1))
        var oldestComps = cal.dateComponents([.year, .month], from: oldestMonth)
        oldestComps.day = 1
        guard let oldest = cal.date(from: oldestComps) else { return [] }
        let txs = allTransaksi.filter { $0.tipe == .pengeluaran && $0.tanggal >= oldest }
        // Key = UUID string supaya rename tidak memecah seri
        var totals: [String: (nama: String, warna: String, total: Decimal)] = [:]
        for t in txs {
            let id    = t.kategori?.id.uuidString ?? "none"
            let nama  = t.kategori?.nama  ?? "Lainnya"
            let warna = t.kategori?.warna ?? "#6B7280"
            if let existing = totals[id] {
                totals[id] = (nama: nama, warna: warna, total: existing.total + t.nominal)
            } else {
                totals[id] = (nama: nama, warna: warna, total: t.nominal)
            }
        }
        return totals.sorted { $0.value.total > $1.value.total }
            .prefix(4)
            .map { (id: $0.key, nama: $0.value.nama, warna: $0.value.warna) }
    }

    private var kategoriTrendData: [KategoriTrendPoint] {
        let cal = Calendar.current
        let top = topKategori

        // O(n) — pre-group by "yyyy-M,kategoriUUID" (UUID-based: rename aman)
        var txByMonthKat: [String: Double] = [:]
        for tx in allTransaksi where tx.tipe == .pengeluaran {
            let c     = cal.dateComponents([.year, .month], from: tx.tanggal)
            let katID = tx.kategori?.id.uuidString ?? "none"
            let key   = "\(c.year!)-\(c.month!),\(katID)"
            txByMonthKat[key, default: 0] += (tx.nominal as NSDecimalNumber).doubleValue
        }

        var result: [KategoriTrendPoint] = []
        for offset in stride(from: trendPeriod - 1, through: 0, by: -1) {
            let monthDate   = selectedMonth.addingMonths(-offset)
            let c           = cal.dateComponents([.year, .month], from: monthDate)
            let monthPrefix = "\(c.year!)-\(c.month!)"
            let monthLabel  = Self.dfMonthShort.string(from: monthDate)
            for k in top {
                let total = txByMonthKat["\(monthPrefix),\(k.id)"] ?? 0
                result.append(KategoriTrendPoint(monthLabel: monthLabel, kategoriNama: k.nama, warna: k.warna, total: total))
            }
        }
        return result
    }

    // MARK: - Multi-Month Trend Section

    private var multiMonthTrendSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundStyle(theme.accent)
                    Text("TREN MULTI BULAN")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                        .tracking(1)
                }
                Spacer()
                // Period picker
                HStack(spacing: 4) {
                    ForEach([3, 6, 12], id: \.self) { p in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { trendPeriod = p }
                        } label: {
                            Text("\(p)B")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(trendPeriod == p ? .black : theme.textSecondary)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(trendPeriod == p ? theme.accent : theme.separator)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if selectedMonthIsCurrentMonth { partialMonthBanner }

            if multiMonthData.allSatisfy({ $0.pengeluaran == 0 && $0.pemasukan == 0 }) {
                emptyChartPlaceholder
            } else {
                // Grouped bar chart
                Chart {
                    ForEach(multiMonthData) { item in
                        let isCurrent = selectedMonthIsCurrentMonth && item.id == multiMonthData.last?.id
                        BarMark(x: .value("Bulan", item.label),
                                y: .value("Pengeluaran", item.pengeluaran))
                            .foregroundStyle(Color(hex: "#FF6B6B").opacity(isCurrent ? 0.45 : 0.85))
                            .position(by: .value("Tipe", "Keluar"))
                            .cornerRadius(3)

                        BarMark(x: .value("Bulan", item.label),
                                y: .value("Pemasukan", item.pemasukan))
                            .foregroundStyle(Color(hex: "#4ADE80").opacity(isCurrent ? 0.45 : 0.85))
                            .position(by: .value("Tipe", "Masuk"))
                            .cornerRadius(3)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        if let label = value.as(String.self) {
                            AxisValueLabel {
                                Text(label).font(.system(size: 10)).foregroundStyle(theme.textSecondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        if let v = value.as(Double.self) {
                            AxisValueLabel {
                                Text(v.shortFormatted).font(.system(size: 10)).foregroundStyle(theme.textSecondary)
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(theme.separator)
                        }
                    }
                }
                .chartLegend(.hidden)
                .chartBackground { _ in Color.clear }
                .frame(height: 200)

                // Legend
                HStack(spacing: 16) {
                    LegendDot(color: Color(hex: "#FF6B6B"), label: "Pengeluaran")
                    LegendDot(color: Color(hex: "#4ADE80"), label: "Pemasukan")
                    Spacer()
                }

                // Summary row: avg, best month, worst month
                // Kalau selectedMonth = bulan ini, exclude dari best/worst supaya data parsial tidak bias
                let completedData = selectedMonthIsCurrentMonth ? multiMonthData.dropLast() : ArraySlice(multiMonthData)
                let nonZeroVals = completedData.filter { $0.pengeluaran > 0 }.map { $0.pengeluaran }
                let avgOut: Double = nonZeroVals.isEmpty ? 0 : nonZeroVals.reduce(0, +) / Double(nonZeroVals.count)
                let best  = completedData.filter { $0.pengeluaran > 0 }.min(by: { $0.pengeluaran < $1.pengeluaran })
                let worst = completedData.filter { $0.pengeluaran > 0 }.max(by: { $0.pengeluaran < $1.pengeluaran })

                HStack(spacing: 0) {
                    trendStatBox(label: "Rata-rata", value: avgOut.shortFormatted, color: theme.textPrimary)
                    Divider().frame(height: 36).background(theme.separator)
                    trendStatBox(label: "Terbaik 🏆", value: best.map { "\($0.label) \($0.pengeluaran.shortFormatted)" } ?? "-", color: Color(hex: "#4ADE80"))
                    Divider().frame(height: 36).background(theme.separator)
                    trendStatBox(label: "Terburuk ⚠️", value: worst.map { "\($0.label) \($0.pengeluaran.shortFormatted)" } ?? "-", color: Color(hex: "#FF6B6B"))
                }
                .padding(.vertical, 4)
                .background(theme.separator.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func trendStatBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Kategori Trend Section

    private var kategoriTrendSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#A78BFA"))
                Text("TREN PER KATEGORI")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .tracking(1)
                Spacer()
                Text("Top 4 · \(trendPeriod) bln")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }

            if selectedMonthIsCurrentMonth { partialMonthBanner }

            let top = topKategori
            if top.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart(kategoriTrendData) { point in
                    LineMark(
                        x: .value("Bulan", point.monthLabel),
                        y: .value("Total", point.total)
                    )
                    .foregroundStyle(by: .value("Kategori", point.kategoriNama))
                    .interpolationMethod(.linear)
                    .symbol(by: .value("Kategori", point.kategoriNama))
                    .opacity(selectedMonthIsCurrentMonth && point.monthLabel == multiMonthData.last?.label ? 0.45 : 1.0)
                }
                .chartForegroundStyleScale(
                    domain: top.map { $0.nama },
                    range: top.map { Color(hex: $0.warna) }
                )
                .chartXAxis {
                    AxisMarks { value in
                        if let label = value.as(String.self) {
                            let isCurrent = selectedMonthIsCurrentMonth && label == multiMonthData.last?.label
                            AxisValueLabel {
                                Text(isCurrent ? "\(label)*" : label)
                                    .font(.system(size: 10))
                                    .foregroundStyle(isCurrent ? Color(hex: "#FBBF24") : theme.textSecondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        if let v = value.as(Double.self) {
                            AxisValueLabel {
                                Text(v.shortFormatted).font(.system(size: 10)).foregroundStyle(theme.textSecondary)
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(theme.separator)
                        }
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
                .chartBackground { _ in Color.clear }
                .frame(height: 200)

                // Change vs first month in period
                // Kalau bulan ini sedang berjalan, bandingkan last completed month vs first
                let completedPoints = selectedMonthIsCurrentMonth ? kategoriTrendData.filter { $0.monthLabel != multiMonthData.last?.label } : kategoriTrendData
                VStack(spacing: 8) {
                    ForEach(top, id: \.id) { k in
                        let points = completedPoints.filter { $0.kategoriNama == k.nama }
                        let allPoints = kategoriTrendData.filter { $0.kategoriNama == k.nama }
                        let first  = points.first?.total ?? 0
                        let last   = points.last?.total ?? 0
                        let currentVal = allPoints.last?.total ?? 0
                        let pct    = first > 0 ? (last - first) / first * 100 : 0

                        HStack(spacing: 10) {
                            Circle().fill(Color(hex: k.warna)).frame(width: 8, height: 8)
                            Text(k.nama)
                                .font(.system(size: 13))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            // Kalau bulan ini berjalan, tampilkan nilai sebagian dengan tanda *
                            if selectedMonthIsCurrentMonth {
                                Text("\(currentVal.shortFormatted)*")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(theme.textSecondary)
                            } else {
                                Text(last.shortFormatted)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(theme.textPrimary)
                            }
                            if first > 0 && last > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: pct > 0 ? "arrow.up.right" : (pct < 0 ? "arrow.down.right" : "equal"))
                                        .font(.system(size: 9, weight: .bold))
                                    Text(pct == 0 ? "=" : "\(String(format: "%.0f", abs(pct)))%")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundStyle(pct > 5 ? Color(hex: "#FF6B6B") : (pct < -5 ? Color(hex: "#4ADE80") : theme.textSecondary))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background((pct > 5 ? Color(hex: "#FF6B6B") : (pct < -5 ? Color(hex: "#4ADE80") : theme.separator)).opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Current month helper

    /// True kalau selectedMonth = bulan ini (data belum lengkap)
    private var selectedMonthIsCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    @ViewBuilder
    private var partialMonthBanner: some View {
        let df = DateFormatter()
        let _ = { df.locale = Locale(identifier: "id_ID"); df.dateFormat = "MMMM" }()
        HStack(spacing: 6) {
            Image(systemName: "clock.badge.exclamationmark.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: "#FBBF24"))
            Text("\(df.string(from: selectedMonth)) belum selesai — data bulan ini masih sebagian")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: "#FBBF24"))
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color(hex: "#FBBF24").opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "id_ID"); f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }
    private func dayName(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "id_ID"); f.dateFormat = "EEEE"
        return f.string(from: date)
    }
    private func shortDayLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "id_ID"); f.dateFormat = "d"
        return f.string(from: date)
    }
}

// MARK: - Sub-views

private struct SummaryCard: View {
    let title: String; let value: String; let fullValue: String
    let valueColor: Color; let icon: String; let iconColor: Color
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(iconColor)
                Spacer()
            }
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(valueColor == .white ? theme.textPrimary : valueColor)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(title).font(.system(size: 11)).foregroundStyle(theme.textSecondary).lineLimit(1)
        }
        .padding(14).background(theme.bgCard).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// KategoriAnalitikRow dihapus — digantikan SwiftCharts BarMark di perKategoriSection

private struct LegendDot: View {
    let color: Color; let label: String
    @Environment(\.appTheme) private var theme
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 11)).foregroundStyle(theme.textSecondary)
        }
    }
}

private struct ChartToggleButton: View {
    let label: String; @Binding var isOn: Bool; let color: Color
    @Environment(\.appTheme) private var theme
    var body: some View {
        Button { isOn.toggle() } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isOn ? color : theme.textSecondary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(isOn ? color.opacity(0.15) : theme.bgCard)
                .clipShape(Capsule())
        }
    }
}
