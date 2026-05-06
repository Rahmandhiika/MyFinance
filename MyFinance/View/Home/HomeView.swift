import SwiftUI
import SwiftData

struct HomeView: View {
    // MARK: - Queries
    @Query(sort: \Transaksi.tanggal, order: .reverse) private var allTransaksi: [Transaksi]
    @Query private var allPockets: [Pocket]
    @Query private var allAset: [Aset]
    @Query private var allTargets: [Target]
    @Query private var allAnggaran: [Anggaran]
    @Query private var profiles: [UserProfile]

    // MARK: - State
    @State private var selectedMonth: Date = Date()
    @State private var showAddTransaksi = false
    @AppStorage("hideBalance") private var hideBalance: Bool = false

    // MARK: - Colors
    private let bgColor = Color(hex: "#0D0D0D")
    private let cardGreen1 = Color(hex: "#0A2A1A")
    private let cardGreen2 = Color(hex: "#0D1A12")
    private let accentGreen = Color(hex: "#22C55E")
    private let accentCyan = Color(hex: "#06B6D4")
    private let accentRed = Color(hex: "#F43F5E")

    // MARK: - Profile
    private var profile: UserProfile? { profiles.first }

    // MARK: - Month Stats (single-pass — computes all tx-derived values in one loop)

    private struct MonthStats {
        var pemasukan: Decimal = 0
        var pengeluaran: Decimal = 0
        var nabungBulanIni: Decimal = 0
        var kebutuhanPokok: Decimal = 0
        var gayaHidup: Decimal = 0
        var kategoriTeratas: [(Kategori, Decimal)] = []
        var semuaKategori: [(Kategori, Decimal)] = []   // untuk tampilan bulan lalu
        var terbaru: [Transaksi] = []
        var txList: [Transaksi] = []    // semua transaksi bulan ini, untuk terpakai(for:)

        var amanDibelanjakan: Decimal { pemasukan - pengeluaran - nabungBulanIni }

        var kebutuhanPokokPct: Double {
            guard pengeluaran > 0 else { return 0 }
            return Double(truncating: (kebutuhanPokok / pengeluaran * 100) as NSDecimalNumber)
        }
        var gayaHidupPct: Double {
            guard pengeluaran > 0 else { return 0 }
            return Double(truncating: (gayaHidup / pengeluaran * 100) as NSDecimalNumber)
        }
        var danaTersimpanPct: Double {
            guard pemasukan > 0 else { return 0 }
            return Double(truncating: (nabungBulanIni / pemasukan * 100) as NSDecimalNumber)
        }

        func terpakai(for anggaran: Anggaran) -> Decimal {
            txList.filter { t in
                t.tipe == .pengeluaran &&
                (anggaran.kategori == nil || t.kategori?.id == anggaran.kategori?.id)
            }.reduce(0) { $0 + $1.nominal }
        }
    }

    /// Single pass through allTransaksi — replaces 9+ individual filter/reduce calls
    private var monthStats: MonthStats {
        var s = MonthStats()
        var katMap: [UUID: (Kategori, Decimal)] = [:]

        for tx in allTransaksi where tx.tanggal.isSameMonth(as: selectedMonth) {
            s.txList.append(tx)
            switch tx.tipe {
            case .pemasukan:
                s.pemasukan += tx.nominal
            case .pengeluaran:
                s.pengeluaran += tx.nominal
                // nabung hanya dari transaksi berkategori isNabung (sinkron dengan filter kategori)
                if tx.kategori?.isNabung == true { s.nabungBulanIni += tx.nominal }
                switch tx.kategori?.klasifikasi {
                case .kebutuhanPokok: s.kebutuhanPokok += tx.nominal
                case .gayaHidup:      s.gayaHidup      += tx.nominal
                default: break
                }
                if let kat = tx.kategori {
                    if let e = katMap[kat.id] { katMap[kat.id] = (kat, e.1 + tx.nominal) }
                    else { katMap[kat.id] = (kat, tx.nominal) }
                }
            }
        }

        let sorted = katMap.values.sorted { $0.1 > $1.1 }
        s.kategoriTeratas = Array(sorted.prefix(3))
        s.semuaKategori   = sorted
        s.terbaru = Array(s.txList.prefix(5))
        return s
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    // MARK: - Kekayaan Computed (non-tx, kept as individual props)

    private var danaTersimpan: Decimal { allTargets.reduce(0) { $0 + $1.tersimpan } }
    /// Total saldo semua pocket biasa (tanpa pengurangan apapun — untuk total kekayaan)
    private var cash: Decimal {
        allPockets.filter { $0.kelompokPocket == .biasa }.reduce(0) { $0 + $1.saldo }
    }
    /// Dana yang sudah disisihkan ke target biasa (masih ada di pocket, tapi sudah "dipesan")
    private var danaTersisihkanTarget: Decimal {
        allTargets
            .filter { $0.jenisTarget == .biasa }
            .reduce(0) { $0 + $1.tersimpan }
    }
    /// Uang yang benar-benar bebas dipakai = saldo pocket - yang sudah ke target
    private var sisaPocket: Decimal { max(cash - danaTersisihkanTarget, 0) }

    private var hutang: Decimal { allPockets.filter { $0.kelompokPocket == .utang }.reduce(0) { $0 + $1.saldo } }
    private var totalAset: Decimal { allAset.filter { $0.linkedTarget == nil }.reduce(0) { $0 + $1.nilaiEfektif } }
    private var totalKekayaan: Decimal { cash + danaTersimpan + totalAset - hutang }

    // MARK: - Active Targets & Anggaran (non-tx)

    private var activeTargets: [Target] {
        allTargets
            .filter { !$0.isSelesai && $0.tampilDiHome }
            .sorted { $0.urutan == $1.urutan ? $0.createdAt < $1.createdAt : $0.urutan < $1.urutan }
    }

    private var anggaranBulanIni: [Anggaran] {
        let m = Calendar.current.component(.month, from: selectedMonth)
        let y = Calendar.current.component(.year, from: selectedMonth)
        return allAnggaran.filter { a in
            guard a.tipeAnggaran == .bulanan else { return false }
            return (a.bulan == m && a.tahun == y) || a.berulang
        }
    }

    // MARK: - Body
    var body: some View {
        // Compute once per render — all tx-derived values come from here
        let stats = monthStats
        let angg  = anggaranBulanIni
        let totalAngg   = angg.reduce(Decimal(0)) { $0 + $1.nominal }
        let totalTerp   = angg.reduce(Decimal(0)) { $0 + stats.terpakai(for: $1) }

        return NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                bgColor.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        topBar
                        MonthNavigator(selectedMonth: $selectedMonth)
                            .padding(.horizontal)
                        cashflowCard(stats)
                        shortcutRow
                        totalKekayaanCard
                        rincianBiayaCard(stats)
                        if !angg.isEmpty {
                            anggaranSection(angg, stats: stats, totalAnggaran: totalAngg, totalTerpakai: totalTerp)
                        }
                        if !activeTargets.isEmpty {
                            goalsSection
                        }
                        LanggananBulanIniCard()
                            .padding(.horizontal)
                        if isCurrentMonth {
                            if !stats.kategoriTeratas.isEmpty {
                                kategoriTeratSection(stats)
                            }
                            if !stats.terbaru.isEmpty {
                                terbarSection(stats)
                            }
                        } else {
                            if !stats.semuaKategori.isEmpty {
                                pastMonthKategoriSection(stats)
                            } else {
                                emptyPastMonthSection
                            }
                        }
                        Spacer().frame(height: 80)
                    }
                    .padding(.top, 8)
                }

                // Floating Add Button
                Button {
                    showAddTransaksi = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 56, height: 56)
                        .background(accentGreen)
                        .clipShape(Circle())
                        .shadow(color: accentGreen.opacity(0.4), radius: 10, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showAddTransaksi) {
            AddEditTransaksiSheet()
        }
    }

    // MARK: - Balance Mask Helper

    private func masked(_ value: String) -> String {
        hideBalance ? "••••••" : value
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            // Profile Photo
            ZStack {
                if let data = profile?.fotoProfil, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(accentGreen.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(profile?.nama.prefix(1).uppercased() ?? "U")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(accentGreen)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(profile?.greetingText ?? "Halo")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text(profile?.nama ?? "—")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            Spacer()

            // Hide balance toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    hideBalance.toggle()
                }
            } label: {
                Image(systemName: hideBalance ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(hideBalance ? .gray : .white.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Cashflow Card
    private func cashflowCard(_ stats: MonthStats) -> some View {
        let activePocketCount = allPockets.filter { $0.isAktif && $0.kelompokPocket == .biasa }.count
        return VStack(alignment: .leading, spacing: 12) {
            Text("SISA POCKET")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.gray)

            Text(masked(sisaPocket.idrFormatted))
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(accentGreen)

            Text("dari \(activePocketCount) pocket aktif · target sudah dikurangi")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))

            Divider().background(Color.white.opacity(0.1))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                cashflowGridItem(label: "PEMASUKAN", icon: "arrow.down.circle.fill", iconColor: accentGreen, amount: stats.pemasukan, amountColor: accentGreen)
                cashflowGridItem(label: "PENGELUARAN", icon: "arrow.up.circle.fill", iconColor: accentRed, amount: stats.pengeluaran, amountColor: accentRed)
                cashflowGridItem(label: "NABUNG BULAN INI", icon: "arrow.down.to.line.circle.fill", iconColor: accentCyan, amount: stats.nabungBulanIni, amountColor: accentCyan)
                cashflowGridItem(label: "TOTAL TABUNGAN", icon: "banknote.fill", iconColor: accentCyan, amount: danaTersimpan + totalAset, amountColor: accentCyan)
            }
        }
        .padding(16)
        .background(
            LinearGradient(colors: [cardGreen1, cardGreen2], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentGreen.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private func cashflowGridItem(label: String, icon: String, iconColor: Color, amount: Decimal, amountColor: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.gray)
                Text(masked(amount.idrFormatted))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(amountColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
        }
    }

    // MARK: - Shortcut Row
    private var shortcutRow: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: AnalitikView()) {
                shortcutCard(label: "Analitik", icon: "chart.bar.fill", color: Color(hex: "#A78BFA"))
            }
            NavigationLink(destination: TargetListView()) {
                shortcutCard(label: "Target", icon: "target", color: accentGreen)
            }
            NavigationLink(destination: AsetListView()) {
                shortcutCard(label: "Aset", icon: "briefcase.fill", color: Color(hex: "#F59E0B"))
            }
        }
        .padding(.horizontal)
    }

    private func shortcutCard(label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 18))
            }
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Total Kekayaan Card
    private var totalKekayaanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "building.columns.fill")
                    .foregroundStyle(accentGreen)
                    .font(.caption)
                Text("TOTAL KEKAYAAN")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.gray)
            }

            Text(masked(totalKekayaan.idrFormatted))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            Divider().background(Color.white.opacity(0.1))

            HStack(spacing: 0) {
                kekayaanColumn(label: "CASH", value: cash, color: accentGreen)
                Divider()
                    .frame(width: 1, height: 36)
                    .background(Color.white.opacity(0.15))
                kekayaanColumn(label: "DANA TERSIMPAN", value: danaTersimpan, color: accentCyan)
                Divider()
                    .frame(width: 1, height: 36)
                    .background(Color.white.opacity(0.15))
                kekayaanColumn(label: "ASET", value: totalAset, color: Color(hex: "#3B82F6"))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func kekayaanColumn(label: String, value: Decimal, color: Color) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            Text(masked(value.shortFormatted))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Rincian Biaya Card
    private func rincianBiayaCard(_ stats: MonthStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(accentGreen)
                    .font(.caption)
                Text("RINCIAN BIAYA")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.gray)
            }

            rincianRow(label: "Kebutuhan Pokok", pct: stats.kebutuhanPokokPct, color: Color(hex: "#F59E0B"))
            rincianRow(label: "Gaya Hidup", pct: stats.gayaHidupPct, color: Color(hex: "#A78BFA"))
            rincianRow(label: "Dana Tersimpan", pct: stats.danaTersimpanPct, color: accentCyan)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func rincianRow(label: String, pct: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(String(format: "%.0f%%", pct))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }
            ProgressBarView(progress: pct / 100, color: color, height: 5)
        }
    }

    // MARK: - Anggaran Section

    private func anggaranSection(
        _ angg: [Anggaran],
        stats: MonthStats,
        totalAnggaran: Decimal,
        totalTerpakai: Decimal
    ) -> some View {
        let sisa = totalAnggaran - totalTerpakai
        let overBudget = sisa < 0
        let progress = totalAnggaran > 0
            ? min(Double(truncating: (totalTerpakai / totalAnggaran) as NSDecimalNumber), 1.0)
            : 0.0
        let barColor = overBudget ? accentRed : (progress > 0.8 ? Color(hex: "#F59E0B") : Color(hex: "#FBBF24"))

        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader(label: "ANGGARAN BULAN INI", icon: "chart.bar.doc.horizontal.fill")

            VStack(spacing: 12) {
                // Summary row
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TERPAKAI")
                            .font(.caption2).foregroundStyle(.gray).tracking(0.5)
                        Text(masked(totalTerpakai.idrFormatted))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(overBudget ? accentRed : .white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("TOTAL")
                            .font(.caption2).foregroundStyle(.gray).tracking(0.5)
                        Text(masked(totalAnggaran.idrFormatted))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                // Progress bar
                VStack(spacing: 4) {
                    ProgressBarView(progress: progress, color: barColor, height: 8)
                    HStack {
                        Text(masked(overBudget ? "Over \(abs(sisa).idrFormatted)" : "Sisa \(sisa.idrFormatted)"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(overBudget ? accentRed : Color(hex: "#22C55E"))
                        Spacer()
                        Text(String(format: "%.0f%% terpakai", progress * 100))
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }

                // Per-kategori rows (max 4, sisanya lipat)
                if angg.count > 1 {
                    Divider().background(Color.white.opacity(0.06))
                    VStack(spacing: 8) {
                        ForEach(Array(angg.prefix(4))) { anggaran in
                            anggaranRow(anggaran, stats: stats)
                        }
                        if angg.count > 4 {
                            Text("+\(angg.count - 4) anggaran lainnya")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(overBudget ? accentRed.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }

    private func anggaranRow(_ anggaran: Anggaran, stats: MonthStats) -> some View {
        let pakai = stats.terpakai(for: anggaran)
        let prog = anggaran.nominal > 0
            ? min(Double(truncating: (pakai / anggaran.nominal) as NSDecimalNumber), 1.0)
            : 0.0
        let over = pakai > anggaran.nominal
        let rowColor = over ? accentRed : (prog > 0.8 ? Color(hex: "#F59E0B") : Color(hex: "#FBBF24"))

        return VStack(spacing: 4) {
            HStack {
                // Ikon kategori atau global
                ZStack {
                    Circle()
                        .fill(rowColor.opacity(0.15))
                        .frame(width: 26, height: 26)
                    if let kat = anggaran.kategori {
                        if let emoji = kat.ikonCustom, !emoji.isEmpty {
                            Text(emoji).font(.system(size: 12))
                        } else {
                            Image(systemName: kat.ikon)
                                .font(.system(size: 11))
                                .foregroundStyle(rowColor)
                        }
                    } else {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(rowColor)
                    }
                }

                Text(anggaran.kategori?.nama ?? "Semua Kategori")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Text(masked("\(pakai.shortFormatted) / \(anggaran.nominal.shortFormatted)"))
                    .font(.caption2)
                    .foregroundStyle(over ? accentRed : .gray)
            }

            ProgressBarView(progress: prog, color: rowColor, height: 4)
        }
    }

    // MARK: - Goals Section
    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(label: "TARGET AKTIF", icon: "target")

            ForEach(activeTargets) { target in
                goalCard(target: target)
            }
        }
        .padding(.horizontal)
    }

    private func goalCard(target: Target) -> some View {
        let targetColor = Color(hex: target.warna)
        let pct = target.progressPersen
        let hasFoto = target.fotoData != nil

        return ZStack(alignment: .bottom) {
            // Background foto atau solid
            if let data = target.fotoData, let uiImg = UIImage(data: data) {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 140)
                    .clipped()
            } else {
                Color.white.opacity(0.05)
            }

            // Gradient overlay kalau ada foto
            if hasFoto {
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black.opacity(0.55), Color.black.opacity(0.88)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            // Konten
            VStack(alignment: .leading, spacing: 10) {
                // Header: ikon + nama
                HStack {
                    ZStack {
                        Circle()
                            .fill(hasFoto ? Color.black.opacity(0.3) : targetColor.opacity(0.2))
                            .frame(width: 36, height: 36)
                        if let emoji = target.ikonCustom {
                            Text(emoji).font(.system(size: 16))
                        } else {
                            Image(systemName: target.ikon)
                                .foregroundStyle(hasFoto ? .white : targetColor)
                                .font(.system(size: 14))
                        }
                    }
                    HStack(alignment: .center, spacing: 6) {
                        Text(target.nama)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .shadow(color: hasFoto ? .black.opacity(0.6) : .clear, radius: 3)
                        if target.jenisTarget == .investasi {
                            HStack(spacing: 3) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(target.linkedAset?.tipe.displayName ?? "Investasi")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(hasFoto ? .white : accentGreen)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(hasFoto ? Color.white.opacity(0.2) : accentGreen.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        Spacer()
                    }
                }

                // Progress
                HStack {
                    Text(String(format: "%.0f%%", pct))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(hasFoto ? .white : targetColor)
                    Text("•").font(.caption).foregroundStyle(.white.opacity(0.4))
                    Text(masked("\(target.tersimpan.shortFormatted) / \(target.targetNominal.shortFormatted)"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(hasFoto ? 0.8 : 0.6))
                }

                ProgressBarView(
                    progress: pct / 100,
                    color: hasFoto ? .white : targetColor,
                    height: 6
                )
                .opacity(hasFoto ? 0.85 : 1)

                if let deadline = target.deadline {
                    let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
                    let deadlineStr: String = {
                        let f = DateFormatter()
                        f.locale = Locale(identifier: "id_ID")
                        f.dateFormat = "dd MMM yyyy"
                        return f.string(from: deadline)
                    }()

                    Text("Estimasi Kelar: \(deadlineStr) • \(daysLeft) hari")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(hasFoto ? 0.7 : 0.5))

                    if target.tersimpan < target.targetNominal && daysLeft > 0 {
                        let perBulan = (target.targetNominal - target.tersimpan) / Decimal(max(daysLeft / 30, 1))
                        Text("PERLU MENYISIHKAN: \(masked(perBulan.idrFormatted)) /bln")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(hasFoto ? .white : accentGreen)
                    }
                }
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Kategori Teratas
    private func kategoriTeratSection(_ stats: MonthStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(label: "KATEGORI TERATAS", icon: "list.bullet.clipboard.fill")

            let maxAmount = stats.kategoriTeratas.map { $0.1 }.max() ?? 1
            ForEach(Array(stats.kategoriTeratas.enumerated()), id: \.offset) { _, pair in
                let (kat, amount) = pair
                let progress = Double(truncating: (amount / maxAmount) as NSDecimalNumber)
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: kat.warna).opacity(0.2))
                            .frame(width: 36, height: 36)
                        if let emoji = kat.ikonCustom {
                            Text(emoji)
                                .font(.system(size: 16))
                        } else {
                            Image(systemName: kat.ikon)
                                .foregroundStyle(Color(hex: kat.warna))
                                .font(.system(size: 14))
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(kat.nama)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Spacer()
                            Text(masked(amount.idrFormatted))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(accentRed)
                        }
                        ProgressBarView(progress: progress, color: Color(hex: kat.warna), height: 4)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Terbaru Section
    private func terbarSection(_ stats: MonthStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(label: "TERBARU", icon: "clock.fill")

            ForEach(stats.terbaru) { tx in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill((tx.tipe == .pemasukan ? accentGreen : accentRed).opacity(0.15))
                            .frame(width: 36, height: 36)
                        if let emoji = tx.kategori?.ikonCustom {
                            Text(emoji)
                                .font(.system(size: 16))
                        } else {
                            Image(systemName: tx.kategori?.ikon ?? (tx.tipe == .pemasukan ? "arrow.down.circle.fill" : "arrow.up.circle.fill"))
                                .foregroundStyle(tx.tipe == .pemasukan ? accentGreen : accentRed)
                                .font(.system(size: 14))
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tx.kategori?.nama ?? (tx.tipe == .pemasukan ? "Pemasukan" : "Pengeluaran"))
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        HStack(spacing: 4) {
                            Text(tx.tipe == .pemasukan ? "Pemasukan" : "Pengeluaran")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(tx.tipe == .pemasukan ? accentGreen : accentRed)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background((tx.tipe == .pemasukan ? accentGreen : accentRed).opacity(0.15))
                                .clipShape(Capsule())
                            if tx.subTipe != .normal {
                                Text(tx.subTipe.displayName)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(accentCyan)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(accentCyan.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Spacer()

                    Text(masked((tx.tipe == .pemasukan ? "+" : "-") + tx.nominal.idrFormatted))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(tx.tipe == .pemasukan ? accentGreen : accentRed)
                }
                if tx.id != stats.terbaru.last?.id {
                    Divider().background(Color.white.opacity(0.08))
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Past Month: Category Analytics

    private func pastMonthKategoriSection(_ stats: MonthStats) -> some View {
        let totalPengeluaran = stats.pengeluaran
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(label: "PENGELUARAN PER KATEGORI", icon: "chart.pie.fill")

            // Ringkasan pemasukan / pengeluaran
            HStack(spacing: 0) {
                pastMonthStat(label: "PEMASUKAN", value: stats.pemasukan, color: accentGreen)
                Divider().frame(width: 1, height: 32).background(Color.white.opacity(0.1))
                pastMonthStat(label: "PENGELUARAN", value: stats.pengeluaran, color: accentRed)
                Divider().frame(width: 1, height: 32).background(Color.white.opacity(0.1))
                pastMonthStat(label: "NABUNG", value: stats.nabungBulanIni, color: accentCyan)
            }
            .padding(.vertical, 6)

            Divider().background(Color.white.opacity(0.08))

            // Semua kategori pengeluaran
            ForEach(Array(stats.semuaKategori.enumerated()), id: \.offset) { _, pair in
                let (kat, amount) = pair
                let pct = totalPengeluaran > 0
                    ? Double(truncating: (amount / totalPengeluaran) as NSDecimalNumber)
                    : 0
                VStack(spacing: 4) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: kat.warna).opacity(0.2))
                                .frame(width: 32, height: 32)
                            if let emoji = kat.ikonCustom {
                                Text(emoji).font(.system(size: 14))
                            } else {
                                Image(systemName: kat.ikon)
                                    .foregroundStyle(Color(hex: kat.warna))
                                    .font(.system(size: 12))
                            }
                        }
                        Text(kat.nama)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(masked(amount.idrFormatted))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(accentRed)
                            Text(String(format: "%.0f%%", pct * 100))
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }
                    }
                    ProgressBarView(progress: pct, color: Color(hex: kat.warna), height: 3)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func pastMonthStat(label: String, value: Decimal, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 8, weight: .semibold)).foregroundStyle(.gray)
            Text(masked(value.idrFormatted))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyPastMonthSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.gray)
            Text("Tidak ada transaksi di bulan ini")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Helpers
    private func sectionHeader(label: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(accentGreen)
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.gray)
        }
    }
}
