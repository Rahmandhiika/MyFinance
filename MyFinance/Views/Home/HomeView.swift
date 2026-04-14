import SwiftUI
import SwiftData

struct HomeView: View {
    // MARK: - Queries
    @Query(sort: \Transaksi.tanggal, order: .reverse) private var allTransaksi: [Transaksi]
    @Query private var allPockets: [Pocket]
    @Query private var allAset: [Aset]
    @Query(sort: \SimpanKeTarget.tanggal, order: .reverse) private var allSimpan: [SimpanKeTarget]
    @Query private var allTargets: [Target]
    @Query private var profiles: [UserProfile]

    // MARK: - State
    @State private var selectedMonth: Date = Date()
    @State private var showAddTransaksi = false

    // MARK: - Colors
    private let bgColor = Color(hex: "#0D0D0D")
    private let cardGreen1 = Color(hex: "#0A2A1A")
    private let cardGreen2 = Color(hex: "#0D1A12")
    private let accentGreen = Color(hex: "#22C55E")
    private let accentCyan = Color(hex: "#06B6D4")
    private let accentRed = Color(hex: "#F43F5E")

    // MARK: - Profile
    private var profile: UserProfile? { profiles.first }

    // MARK: - Filtered Transactions
    private var transaksiMonth: [Transaksi] {
        allTransaksi.filter { $0.tanggal.isSameMonth(as: selectedMonth) }
    }

    // MARK: - Cashflow Computed
    private var pemasukan: Decimal {
        transaksiMonth.filter { $0.tipe == .pemasukan }.reduce(0) { $0 + $1.nominal }
    }
    private var pengeluaran: Decimal {
        transaksiMonth.filter { $0.tipe == .pengeluaran }.reduce(0) { $0 + $1.nominal }
    }
    private var nabungBulanIni: Decimal {
        allSimpan.filter { $0.tanggal.isSameMonth(as: selectedMonth) }.reduce(0) { $0 + $1.nominal }
    }
    private var danaTersimpan: Decimal {
        allSimpan.reduce(0) { $0 + $1.nominal }
    }
    private var amanDibelanjakan: Decimal {
        pemasukan - pengeluaran - nabungBulanIni
    }

    // MARK: - Kekayaan Computed
    private var cash: Decimal {
        allPockets.filter { $0.kelompokPocket == .biasa }.reduce(0) { $0 + $1.saldo }
    }
    private var hutang: Decimal {
        allPockets.filter { $0.kelompokPocket == .utang }.reduce(0) { $0 + $1.saldo }
    }
    private var totalAset: Decimal {
        allAset.reduce(0) { $0 + $1.nilaiEfektif }
    }
    private var totalKekayaan: Decimal {
        cash + danaTersimpan + totalAset - hutang
    }

    // MARK: - Rincian Biaya
    private var kebutuhanPokokTotal: Decimal {
        transaksiMonth.filter {
            $0.tipe == .pengeluaran && $0.kategori?.klasifikasi == .kebutuhanPokok
        }.reduce(0) { $0 + $1.nominal }
    }
    private var gayaHidupTotal: Decimal {
        transaksiMonth.filter {
            $0.tipe == .pengeluaran && $0.kategori?.klasifikasi == .gayaHidup
        }.reduce(0) { $0 + $1.nominal }
    }
    private var kebutuhanPokokPct: Double {
        guard pengeluaran > 0 else { return 0 }
        return Double(truncating: (kebutuhanPokokTotal / pengeluaran * 100) as NSDecimalNumber)
    }
    private var gayaHidupPct: Double {
        guard pengeluaran > 0 else { return 0 }
        return Double(truncating: (gayaHidupTotal / pengeluaran * 100) as NSDecimalNumber)
    }
    private var danaTersimpanPct: Double {
        guard pemasukan > 0 else { return 0 }
        return Double(truncating: (nabungBulanIni / pemasukan * 100) as NSDecimalNumber)
    }

    // MARK: - Kategori Teratas
    private var kategoriTeratas: [(Kategori, Decimal)] {
        let pengeluaranTx = transaksiMonth.filter { $0.tipe == .pengeluaran && $0.kategori != nil }
        var grouped: [UUID: (Kategori, Decimal)] = [:]
        for tx in pengeluaranTx {
            guard let kat = tx.kategori else { continue }
            if let existing = grouped[kat.id] {
                grouped[kat.id] = (kat, existing.1 + tx.nominal)
            } else {
                grouped[kat.id] = (kat, tx.nominal)
            }
        }
        return grouped.values.sorted { $0.1 > $1.1 }.prefix(3).map { $0 }
    }

    // MARK: - Active Targets
    private var activeTargets: [Target] {
        allTargets.filter { !$0.isSelesai && $0.tersimpan < $0.targetNominal }
    }

    // MARK: - Terbaru
    private var terbaru: [Transaksi] {
        Array(transaksiMonth.prefix(5))
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                bgColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        topBar
                        MonthNavigator(selectedMonth: $selectedMonth)
                            .padding(.horizontal)
                        cashflowCard
                        shortcutRow
                        totalKekayaanCard
                        rincianBiayaCard
                        if !activeTargets.isEmpty {
                            goalsSection
                        }
                        if !kategoriTeratas.isEmpty {
                            kategoriTeratSection
                        }
                        if !terbaru.isEmpty {
                            terbarSection
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
        }
        .padding(.horizontal)
    }

    // MARK: - Cashflow Card
    private var cashflowCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            let isAman = amanDibelanjakan >= 0
            Text(isAman ? "AMAN DIBELANJAKAN" : "WAH, OVER BUDGET!")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(isAman ? accentGreen : accentRed)

            // Large Nominal
            Text((amanDibelanjakan < 0 ? "-" : "+") + abs(amanDibelanjakan).idrFormatted)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(isAman ? accentGreen : accentRed)

            Text("Tersisa: \(amanDibelanjakan.shortFormatted)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))

            Divider().background(Color.white.opacity(0.1))

            // 2x2 Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                cashflowGridItem(label: "PEMASUKAN", icon: "arrow.down.circle.fill", iconColor: accentGreen, amount: pemasukan, amountColor: accentGreen)
                cashflowGridItem(label: "PENGELUARAN", icon: "arrow.up.circle.fill", iconColor: accentRed, amount: pengeluaran, amountColor: accentRed)
                cashflowGridItem(label: "NABUNG BULAN INI", icon: "arrow.down.to.line.circle.fill", iconColor: accentCyan, amount: nabungBulanIni, amountColor: accentCyan)
                cashflowGridItem(label: "TOTAL TABUNGAN", icon: "banknote.fill", iconColor: accentCyan, amount: danaTersimpan, amountColor: accentCyan)
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
                Text(amount.idrFormatted)
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

            Text(totalKekayaan.idrFormatted)
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
            Text(value.shortFormatted)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Rincian Biaya Card
    private var rincianBiayaCard: some View {
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

            rincianRow(label: "Kebutuhan Pokok", pct: kebutuhanPokokPct, color: Color(hex: "#F59E0B"))
            rincianRow(label: "Gaya Hidup", pct: gayaHidupPct, color: Color(hex: "#A78BFA"))
            rincianRow(label: "Dana Tersimpan", pct: danaTersimpanPct, color: accentCyan)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: target.warna).opacity(0.2))
                        .frame(width: 36, height: 36)
                    if let emoji = target.ikonCustom {
                        Text(emoji)
                            .font(.system(size: 16))
                    } else {
                        Image(systemName: target.ikon)
                            .foregroundStyle(Color(hex: target.warna))
                            .font(.system(size: 14))
                    }
                }
                Text(target.nama)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    showAddTransaksi = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(accentGreen)
                }
            }

            let pct = target.progressPersen
            HStack {
                Text(String(format: "%.0f%%", pct))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(hex: target.warna))
                Text("•")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text("\(target.tersimpan.shortFormatted) / \(target.targetNominal.shortFormatted)")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            ProgressBarView(progress: pct / 100, color: Color(hex: target.warna), height: 6)

            if let deadline = target.deadline {
                let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
                let deadlineStr: String = {
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "id_ID")
                    formatter.dateFormat = "dd MMM yyyy"
                    return formatter.string(from: deadline)
                }()

                HStack {
                    Text("Estimasi Kelar: \(deadlineStr) • \(daysLeft) hari")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                if target.tersimpan < target.targetNominal && daysLeft > 0 {
                    let sisaNominal = target.targetNominal - target.tersimpan
                    let bulanSisa = max(daysLeft / 30, 1)
                    let perBulan = sisaNominal / Decimal(bulanSisa)
                    Text("PERLU MENYISIHKAN: \(perBulan.idrFormatted) /bln")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(accentGreen)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Kategori Teratas
    private var kategoriTeratSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(label: "KATEGORI TERATAS", icon: "list.bullet.clipboard.fill")

            let maxAmount = kategoriTeratas.map { $0.1 }.max() ?? 1
            ForEach(Array(kategoriTeratas.enumerated()), id: \.offset) { _, pair in
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
                            Text(amount.idrFormatted)
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
    private var terbarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(label: "TERBARU", icon: "clock.fill")

            ForEach(terbaru) { tx in
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

                    Text((tx.tipe == .pemasukan ? "+" : "-") + tx.nominal.idrFormatted)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(tx.tipe == .pemasukan ? accentGreen : accentRed)
                }
                if tx.id != terbaru.last?.id {
                    Divider().background(Color.white.opacity(0.08))
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
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
