import SwiftUI
import SwiftData

// MARK: - UpcomingItem

struct UpcomingItem: Identifiable {
    enum Kind {
        case tagihan(Langganan, isPaid: Bool)
        case gajian
    }
    let id = UUID()
    let kind: Kind
    let date: Date

    var nama: String {
        switch kind {
        case .tagihan(let l, _): return l.nama
        case .gajian: return "Gajian 🎉"
        }
    }
    var nominal: Decimal? {
        if case .tagihan(let l, _) = kind { return l.nominal }
        return nil
    }
    var isPaid: Bool {
        if case .tagihan(_, let paid) = kind { return paid }
        return false
    }
    var logoData: Data? {
        if case .tagihan(let l, _) = kind { return l.logo }
        return nil
    }
    var accentColor: Color {
        switch kind {
        case .tagihan: return Color(hex: "#F97316")
        case .gajian:  return Color(hex: "#22C55E")
        }
    }
    var iconName: String {
        switch kind {
        case .tagihan: return "creditcard.fill"
        case .gajian:  return "banknote.fill"
        }
    }
}

// MARK: - UpcomingCard (mini, untuk Home)

struct UpcomingCard: View {
    @Environment(\.appTheme) private var theme
    @Query(sort: \Langganan.urutan) private var allLangganan: [Langganan]
    @Query private var allPembayaran: [PembayaranLangganan]
    @Query private var profiles: [UserProfile]

    @State private var showKalender = false

    private var tanggalGajian: Int? { profiles.first?.tanggalGajian }

    private var upcomingItems: [UpcomingItem] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let window = cal.date(byAdding: .day, value: 30, to: today)!
        let bulanIni = cal.component(.month, from: Date())
        let tahunIni = cal.component(.year, from: Date())
        var items: [UpcomingItem] = []

        for l in allLangganan where l.isAktif {
            let due = nextDueDate(tgl: l.tanggalTagih, from: today)
            guard due <= window else { continue }
            let paid = allPembayaran.contains {
                $0.langganan?.id == l.id && $0.bulan == bulanIni && $0.tahun == tahunIni
            }
            items.append(UpcomingItem(kind: .tagihan(l, isPaid: paid), date: due))
        }

        if let tgl = tanggalGajian {
            let gajianDate = nextDueDate(tgl: tgl, from: today)
            if gajianDate <= window {
                items.append(UpcomingItem(kind: .gajian, date: gajianDate))
            }
        }

        return items.sorted { $0.date < $1.date }
    }

    var body: some View {
        if upcomingItems.isEmpty { EmptyView() }
        else {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption)
                            .foregroundStyle(theme.accent)
                        Text("YANG AKAN DATANG")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.textSecondary)
                            .tracking(0.5)
                    }
                    Spacer()
                    Button { showKalender = true } label: {
                        HStack(spacing: 3) {
                            Text("Kalender")
                            Image(systemName: "arrow.up.right.square")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.accent)
                    }
                }

                // Rows
                VStack(spacing: 0) {
                    ForEach(Array(upcomingItems.prefix(5).enumerated()), id: \.element.id) { idx, item in
                        upcomingRow(item)
                        if idx < min(4, upcomingItems.count - 1) {
                            Divider().background(theme.separator).padding(.leading, 44)
                        }
                    }
                }

                if upcomingItems.count > 5 {
                    Button { showKalender = true } label: {
                        Text("Lihat \(upcomingItems.count - 5) lainnya di kalender")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(theme.accent.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(16)
            .background(theme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardBorder, lineWidth: 1))
            .sheet(isPresented: $showKalender) {
                KalenderKeuanganSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private func upcomingRow(_ item: UpcomingItem) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(item.accentColor.opacity(item.isPaid ? 0.06 : 0.13))
                    .frame(width: 32, height: 32)
                if let data = item.logoData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 32, height: 32).clipShape(Circle())
                        .opacity(item.isPaid ? 0.4 : 1)
                } else {
                    Image(systemName: item.isPaid ? "checkmark" : item.iconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(item.isPaid ? Color(hex: "#22C55E") : item.accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.nama)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(item.isPaid ? theme.textSecondary : theme.textPrimary)
                    .strikethrough(item.isPaid, color: theme.textSecondary)
                    .lineLimit(1)
                Text(dayLabel(item.date))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(urgencyColor(item.date, isPaid: item.isPaid))
            }

            Spacer()

            if let nominal = item.nominal {
                Text("\(item.isPaid ? "" : "−")\(nominal.shortFormatted)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(item.isPaid ? theme.textSecondary.opacity(0.5) : item.accentColor)
                    .strikethrough(item.isPaid, color: theme.textSecondary.opacity(0.5))
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .bold))
                    Text("Gaji masuk").font(.caption.weight(.semibold))
                }
                .foregroundStyle(item.accentColor)
            }
        }
        .padding(.vertical, 10)
        .opacity(item.isPaid ? 0.65 : 1)
    }

    // MARK: - Helpers

    func nextDueDate(tgl: Int, from today: Date) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: today)
        let daysInMonth = cal.range(of: .day, in: .month, for: today)?.count ?? 28
        comps.day = min(tgl, daysInMonth)
        let thisMonth = cal.date(from: comps)!
        if cal.startOfDay(for: thisMonth) >= today { return thisMonth }
        let next = today.addingMonths(1)
        var nc = cal.dateComponents([.year, .month], from: next)
        nc.day = min(tgl, cal.range(of: .day, in: .month, for: next)?.count ?? 28)
        return cal.date(from: nc)!
    }

    private func dayLabel(_ date: Date) -> String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: date)
        ).day ?? 0
        switch days {
        case 0:    return "Hari ini"
        case 1:    return "Besok"
        case 2...6: return "\(days) hari lagi"
        default:
            let df = DateFormatter()
            df.locale = Locale(identifier: "id_ID")
            df.dateFormat = "d MMM"
            return df.string(from: date)
        }
    }

    private func urgencyColor(_ date: Date, isPaid: Bool) -> Color {
        if isPaid { return Color(hex: "#22C55E") }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: date)
        ).day ?? 0
        switch days {
        case 0...2: return Color(hex: "#FF6B6B")
        case 3...6: return Color(hex: "#FBBF24")
        default:    return theme.textSecondary
        }
    }
}

// MARK: - KalenderKeuanganSheet (full calendar)

struct KalenderKeuanganSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Query(sort: \Transaksi.tanggal) private var allTransaksi: [Transaksi]
    @Query(sort: \Langganan.urutan) private var allLangganan: [Langganan]
    @Query private var allPembayaran: [PembayaranLangganan]
    @Query private var profiles: [UserProfile]

    @State private var shownMonth: Date = Date()
    @State private var selectedDay: Int? = {
        Calendar.current.component(.day, from: Date())
    }()

    private let weekdayLabels = ["Sen", "Sel", "Rab", "Kam", "Jum", "Sab", "Min"]
    private var tanggalGajian: Int? { profiles.first?.tanggalGajian }

    // MARK: - Calendar Data

    private var cal: Calendar { Calendar.current }

    private var daysInMonth: Int {
        cal.range(of: .day, in: .month, for: shownMonth)?.count ?? 30
    }

    private var firstWeekdayOffset: Int {
        guard let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: shownMonth)) else { return 0 }
        let weekday = cal.component(.weekday, from: firstDay) // 1=Sun, 2=Mon...
        return (weekday + 5) % 7 // Mon=0..Sun=6
    }

    private var shownYear: Int  { cal.component(.year, from: shownMonth) }
    private var shownMonthNum: Int { cal.component(.month, from: shownMonth) }

    // Transactions grouped by day
    private var txByDay: [Int: [Transaksi]] {
        var map: [Int: [Transaksi]] = [:]
        for tx in allTransaksi {
            guard tx.tanggal.isSameMonth(as: shownMonth) else { continue }
            let d = cal.component(.day, from: tx.tanggal)
            map[d, default: []].append(tx)
        }
        return map
    }

    // Bills due this month keyed by day
    private var billsByDay: [Int: [Langganan]] {
        var map: [Int: [Langganan]] = [:]
        for l in allLangganan where l.isAktif {
            let day = min(l.tanggalTagih, daysInMonth)
            map[day, default: []].append(l)
        }
        return map
    }

    private func isPaid(_ l: Langganan) -> Bool {
        allPembayaran.contains { $0.langganan?.id == l.id && $0.bulan == shownMonthNum && $0.tahun == shownYear }
    }

    private var isCurrentMonth: Bool {
        cal.isDate(shownMonth, equalTo: Date(), toGranularity: .month)
    }
    private var todayDay: Int { cal.component(.day, from: Date()) }

    // Monthly summary
    private var totalPengeluaran: Decimal {
        allTransaksi.filter { $0.tanggal.isSameMonth(as: shownMonth) && $0.tipe == .pengeluaran }
            .reduce(0) { $0 + $1.nominal }
    }
    private var totalPemasukan: Decimal {
        allTransaksi.filter { $0.tanggal.isSameMonth(as: shownMonth) && $0.tipe == .pemasukan }
            .reduce(0) { $0 + $1.nominal }
    }
    private var totalBills: Decimal {
        allLangganan.filter { $0.isAktif }.reduce(0) { $0 + $1.nominal }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bgApp.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        monthlySummary
                        calendarGrid
                        if let day = selectedDay {
                            dayDetailPanel(day: day)
                        }
                        Spacer().frame(height: 32)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Kalender Keuangan")
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

    // MARK: - Monthly Summary Strip

    private var monthlySummary: some View {
        HStack(spacing: 0) {
            summaryPill(label: "Pemasukan", value: totalPemasukan.shortFormatted, color: Color(hex: "#22C55E"), icon: "arrow.up.circle.fill")
            Rectangle().fill(theme.separator).frame(width: 1, height: 36)
            summaryPill(label: "Pengeluaran", value: totalPengeluaran.shortFormatted, color: Color(hex: "#FF6B6B"), icon: "arrow.down.circle.fill")
            Rectangle().fill(theme.separator).frame(width: 1, height: 36)
            summaryPill(label: "Bills", value: totalBills.shortFormatted, color: Color(hex: "#F97316"), icon: "creditcard.fill")
        }
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.cardBorder, lineWidth: 1))
        .padding(.horizontal)
    }

    private func summaryPill(label: String, value: String, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.caption).foregroundStyle(color)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 9)).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: 0) {
            // Month navigator
            HStack {
                Button { shownMonth = shownMonth.addingMonths(-1); selectedDay = nil } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(theme.separator.opacity(0.6))
                        .clipShape(Circle())
                }
                Spacer()
                Text(monthYearLabel)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button { shownMonth = shownMonth.addingMonths(1); selectedDay = nil } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(theme.separator.opacity(0.6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // Weekday header
            HStack(spacing: 0) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            // Day grid
            let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: cols, spacing: 4) {
                // Empty cells before first day
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Color.clear.frame(height: 52)
                }
                // Day cells
                ForEach(1...daysInMonth, id: \.self) { day in
                    dayCell(day: day)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedDay = selectedDay == day ? nil : day
                            }
                        }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            // Legend
            HStack(spacing: 16) {
                legendDot(color: Color(hex: "#FF6B6B"), label: "Pengeluaran")
                legendDot(color: Color(hex: "#22C55E"), label: "Pemasukan / Gajian")
                legendDot(color: Color(hex: "#F97316"), label: "Bill")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardBorder, lineWidth: 1))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func dayCell(day: Int) -> some View {
        let txList = txByDay[day] ?? []
        let bills = billsByDay[day] ?? []
        let isGajian = tanggalGajian.map { min($0, daysInMonth) == day } ?? false
        let isToday = isCurrentMonth && day == todayDay
        let isSelected = selectedDay == day
        let hasPengeluaran = txList.contains { $0.tipe == .pengeluaran }
        let hasPemasukan = txList.contains { $0.tipe == .pemasukan }
        let hasBill = !bills.isEmpty
        let isPast = isCurrentMonth ? day < todayDay : !cal.isDate(shownMonth, equalTo: Date(), toGranularity: .month) && shownMonth < Date()

        VStack(spacing: 3) {
            Text("\(day)")
                .font(.system(size: 13, weight: isToday || isSelected ? .bold : .regular))
                .foregroundStyle(
                    isSelected ? theme.textOnColor
                    : isToday  ? theme.accent
                    : isPast   ? theme.textSecondary
                    : theme.textPrimary
                )
                .frame(width: 28, height: 28)
                .background(
                    Group {
                        if isSelected {
                            Circle().fill(theme.accent)
                        } else if isToday {
                            Circle().stroke(theme.accent, lineWidth: 1.5)
                        } else {
                            Color.clear
                        }
                    }
                )

            // Dots
            HStack(spacing: 3) {
                if hasPengeluaran {
                    Circle().fill(Color(hex: "#FF6B6B")).frame(width: 4, height: 4)
                }
                if hasPemasukan || isGajian {
                    Circle().fill(Color(hex: "#22C55E")).frame(width: 4, height: 4)
                }
                if hasBill {
                    Circle().fill(Color(hex: "#F97316")).frame(width: 4, height: 4)
                }
            }
            .frame(height: 5)
        }
        .frame(height: 52)
    }

    // MARK: - Day Detail Panel

    @ViewBuilder
    private func dayDetailPanel(day: Int) -> some View {
        let txList = txByDay[day] ?? []
        let bills = billsByDay[day] ?? []
        let isGajian = tanggalGajian.map { min($0, daysInMonth) == day } ?? false

        let hasAnything = !txList.isEmpty || !bills.isEmpty || isGajian
        if !hasAnything { EmptyView() }
        else {
            VStack(alignment: .leading, spacing: 12) {
                // Date header
                HStack(spacing: 8) {
                    Text(fullDateLabel(day: day))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    if !txList.isEmpty {
                        let net = txList.filter { $0.tipe == .pemasukan }.reduce(Decimal(0)) { $0 + $1.nominal }
                                - txList.filter { $0.tipe == .pengeluaran }.reduce(Decimal(0)) { $0 + $1.nominal }
                        Text("\(net >= 0 ? "+" : "")\(net.shortFormatted)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(net >= 0 ? Color(hex: "#22C55E") : Color(hex: "#FF6B6B"))
                    }
                }

                // Gajian badge
                if isGajian {
                    HStack(spacing: 8) {
                        Image(systemName: "banknote.fill").font(.system(size: 14)).foregroundStyle(Color(hex: "#22C55E"))
                        Text("Gajian Hari Ini 🎉")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(hex: "#22C55E"))
                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(hex: "#22C55E").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Bills
                ForEach(bills) { l in
                    let paid = isPaid(l)
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(Color(hex: "#F97316").opacity(paid ? 0.07 : 0.13)).frame(width: 30, height: 30)
                            if let data = l.logo, let img = UIImage(data: data) {
                                Image(uiImage: img).resizable().scaledToFill().frame(width: 30, height: 30).clipShape(Circle()).opacity(paid ? 0.5 : 1)
                            } else {
                                Image(systemName: paid ? "checkmark" : "creditcard.fill")
                                    .font(.system(size: 12)).foregroundStyle(paid ? Color(hex: "#22C55E") : Color(hex: "#F97316"))
                            }
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(l.nama).font(.subheadline.weight(.medium)).foregroundStyle(paid ? theme.textSecondary : theme.textPrimary).strikethrough(paid)
                            Text(paid ? "Sudah dibayar" : "Belum dibayar").font(.caption2).foregroundStyle(paid ? Color(hex: "#22C55E") : Color(hex: "#F97316"))
                        }
                        Spacer()
                        Text("−\(l.nominal.shortFormatted)").font(.subheadline.weight(.semibold)).foregroundStyle(paid ? theme.textSecondary.opacity(0.5) : Color(hex: "#F97316")).strikethrough(paid)
                    }
                    .opacity(paid ? 0.7 : 1)
                }

                // Transactions
                if !txList.isEmpty {
                    Divider().background(theme.separator)
                    ForEach(txList.sorted(by: { $0.tanggal > $1.tanggal })) { tx in
                        HStack(spacing: 10) {
                            Circle()
                                .fill((tx.tipe == .pemasukan ? Color(hex: "#22C55E") : Color(hex: "#FF6B6B")).opacity(0.13))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Image(systemName: tx.tipe == .pemasukan ? "arrow.up" : "arrow.down")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(tx.tipe == .pemasukan ? Color(hex: "#22C55E") : Color(hex: "#FF6B6B"))
                                )
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tx.catatan ?? tx.kategori?.nama ?? "Transaksi")
                                    .font(.subheadline.weight(.medium)).foregroundStyle(theme.textPrimary).lineLimit(1)
                                Text(tx.pocket?.nama ?? "").font(.caption2).foregroundStyle(theme.textSecondary)
                            }
                            Spacer()
                            Text("\(tx.tipe == .pemasukan ? "+" : "−")\(tx.nominal.shortFormatted)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(tx.tipe == .pemasukan ? Color(hex: "#22C55E") : Color(hex: "#FF6B6B"))
                        }
                    }
                }
            }
            .padding(16)
            .background(theme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.accent.opacity(0.25), lineWidth: 1))
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Helpers

    private var monthYearLabel: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "id_ID")
        df.dateFormat = "MMMM yyyy"
        return df.string(from: shownMonth)
    }

    private func fullDateLabel(day: Int) -> String {
        var comps = cal.dateComponents([.year, .month], from: shownMonth)
        comps.day = day
        guard let date = cal.date(from: comps) else { return "\(day)" }
        let df = DateFormatter()
        df.locale = Locale(identifier: "id_ID")
        df.dateFormat = "EEEE, d MMMM yyyy"
        return df.string(from: date)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.system(size: 9)).foregroundStyle(theme.textSecondary)
        }
    }
}
