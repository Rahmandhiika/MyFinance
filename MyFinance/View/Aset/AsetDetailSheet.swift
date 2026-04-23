import SwiftUI
import SwiftData

struct AsetDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let aset: Aset

    @Environment(\.modelContext) private var modelContext

    @State private var showEdit = false
    @State private var editMode: AsetEditMode = .edit
    @State private var isRefreshingKurs = false
    @State private var showCairkan = false
    @State private var showJual = false
    @State private var showHapusAlert = false
    @State private var showUpdateNAV = false
    @State private var navInput = ""
    @State private var showUpdateHargaEmas = false
    @State private var hargaEmasInput = ""
    @State private var showEditHargaBeli = false
    @State private var hargaBeliInput = ""
    @State private var showBeliSaham = false
    @State private var showTambahReksadana = false
    @State private var showBeliValas = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // MARK: Header
                        headerSection

                        // MARK: Detail Grid
                        detailGridSection

                        // MARK: Action Buttons
                        actionButtonsSection

                        // MARK: Hapus
                        hapusButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(aset.nama)
                            .font(.headline)
                            .foregroundStyle(.white)
                        if let kode = aset.kode, !kode.isEmpty {
                            Text(kode.uppercased())
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.title3)
                    }
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            AddEditAsetView(existingAset: aset, mode: editMode)
        }
        .sheet(isPresented: $showCairkan) {
            CairkanDepositoSheet(aset: aset) { dismiss() }
        }
        .sheet(isPresented: $showJual) {
            JualAsetSheet(aset: aset) { dismiss() }
        }
        .sheet(isPresented: $showBeliSaham) {
            BeliSahamSheet(aset: aset)
        }
        .sheet(isPresented: $showTambahReksadana) {
            TambahReksadanaSheet(aset: aset)
        }
        .sheet(isPresented: $showBeliValas) {
            BeliValasSheet(aset: aset)
        }
        .alert("Hapus \(aset.nama)?", isPresented: $showHapusAlert) {
            Button("Hapus", role: .destructive) {
                modelContext.delete(aset)
                try? modelContext.save()
                dismiss()
            }
            Button("Batal", role: .cancel) {}
        } message: {
            if aset.linkedTarget != nil {
                Text("Data aset ini akan dihapus permanen. Target investasi yang terhubung (\(aset.linkedTarget?.nama ?? "")) juga akan ikut terhapus.")
            } else {
                Text("Data aset ini akan dihapus permanen dan tidak bisa dipulihkan.")
            }
        }
        .alert("Update NAV Reksadana", isPresented: $showUpdateNAV) {
            TextField("NAV per unit (Rp)", text: $navInput)
                .keyboardType(.decimalPad)
            Button("Simpan") { saveNAV() }
            Button("Batal", role: .cancel) { navInput = "" }
        } message: {
            Text("NAV saat ini: \(aset.navSaatIni?.idrFormatted ?? "-")\nMasukkan NAV terbaru per unit.")
        }
        .alert("Edit Rata-rata Harga Beli", isPresented: $showEditHargaBeli) {
            TextField("Harga per lembar (Rp)", text: $hargaBeliInput)
                .keyboardType(.numberPad)
            Button("Simpan") { saveHargaBeli() }
            Button("Batal", role: .cancel) { hargaBeliInput = "" }
        } message: {
            let modal = aset.modal
            Text("Harga saat ini: \(aset.hargaPerLembar?.idrFormatted ?? "-")/lembar\nTotal modal saat ini: \(modal.idrDecimalFormatted)\n\nMengubah harga beli akan memperbarui total modal.")
        }
        .alert("Update Harga Emas", isPresented: $showUpdateHargaEmas) {
            TextField("Harga per gram (Rp)", text: $hargaEmasInput)
                .keyboardType(.decimalPad)
            Button("Simpan") { saveHargaEmas() }
            Button("Batal", role: .cancel) { hargaEmasInput = "" }
        } message: {
            Text("Harga/gram saat ini: \(aset.hargaBeliPerGram?.idrFormatted ?? "-")\nMasukkan harga buyback terkini per gram.")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            // Tipe icon
            ZStack {
                Circle()
                    .fill(aset.tipe.color.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: aset.tipe.iconName)
                    .font(.title2)
                    .foregroundStyle(aset.tipe.color)
            }

            Text("NILAI PASAR")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1)

            Text(aset.nilaiEfektif.idrDecimalFormatted)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)

            // P&L badge
            HStack(spacing: 6) {
                Image(systemName: aset.pnl >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
                Text("\(aset.pnl.idrDecimalFormatted) (\(aset.returnPersen.percentFormatted))")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(aset.pnl >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444"))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background((aset.pnl >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444")).opacity(0.15))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Detail Grid

    private var detailGridSection: some View {
        VStack(spacing: 0) {
            DetailRow(label: "Tipe Aset", value: aset.tipe.displayName)
            Divider().background(Color.white.opacity(0.08))

            switch aset.tipe {
            case .saham:
                sahamDetails
            case .sahamAS:
                sahamASDetails
            case .reksadana:
                reksadanaDetails
            case .valas:
                valasDetails
            case .emas:
                emasDetails
            case .deposito:
                depositoDetails
            }

            Divider().background(Color.white.opacity(0.08))
            DetailRow(label: "Total Modal", value: aset.modal.idrDecimalFormatted)
            Divider().background(Color.white.opacity(0.08))
            DetailRow(
                label: "Keuntungan / Rugi",
                value: "\(aset.pnl >= 0 ? "+" : "")\(aset.pnl.idrDecimalFormatted)",
                valueColor: aset.pnl >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444")
            )
            Divider().background(Color.white.opacity(0.08))
            DetailRow(
                label: "Return",
                value: aset.returnPersen.percentFormatted,
                valueColor: aset.pnl >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444")
            )
        }
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var sahamDetails: some View {
        if let lot = aset.lot {
            DetailRow(label: "Jumlah Lot", value: "\(NSDecimalNumber(decimal: lot).intValue) lot")
            Divider().background(Color.white.opacity(0.08))
        }
        // Harga beli/lembar — bisa di-edit (mempengaruhi Total Modal)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rata-rata Harga Beli/Lembar")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                Text(aset.hargaPerLembar?.idrDecimalFormatted ?? "–")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button {
                hargaBeliInput = aset.hargaPerLembar.map { "\(NSDecimalNumber(decimal: $0).intValue)" } ?? ""
                showEditHargaBeli = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                        .font(.caption.weight(.semibold))
                    Text("Edit")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color(hex: "#3B82F6"))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(hex: "#3B82F6").opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        Divider().background(Color.white.opacity(0.08))
        // Harga saat ini + refresh button
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Harga Saat Ini/Lembar")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                let hargaSaatIniPerLembar = (aset.lot ?? 0) > 0
                    ? aset.nilaiSaatIni / ((aset.lot ?? 1) * 100)
                    : Decimal(0)
                Text(hargaSaatIniPerLembar > 0 ? hargaSaatIniPerLembar.idrDecimalFormatted : "–")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button {
                guard let kode = aset.kode else { return }
                isRefreshingKurs = true
                Task {
                    if let harga = await AsetPriceService.shared.fetchSahamPrice(kode: kode) {
                        aset.nilaiSaatIni = (aset.lot ?? 0) * 100 * harga
                        try? modelContext.save()
                    }
                    isRefreshingKurs = false
                }
            } label: {
                HStack(spacing: 4) {
                    if isRefreshingKurs {
                        ProgressView().tint(Color(hex: "#3B82F6")).scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                    }
                    Text("Update")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color(hex: "#3B82F6"))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(hex: "#3B82F6").opacity(0.12))
                .clipShape(Capsule())
            }
            .disabled(isRefreshingKurs || aset.kode == nil)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        Divider().background(Color.white.opacity(0.08))
    }

    @ViewBuilder
    private var sahamASDetails: some View {
        if let kode = aset.kode, !kode.isEmpty {
            DetailRow(label: "Ticker", value: kode.uppercased())
            Divider().background(Color.white.opacity(0.08))
        }
        if let totalUSD = aset.totalInvestasiUSD {
            DetailRow(label: "Total Investasi (USD)", value: "$\(totalUSD.unitFormatted(2))")
            Divider().background(Color.white.opacity(0.08))
        }
        let shares = aset.jumlahSharesAS
        if shares > 0 {
            DetailRow(label: "Jumlah Shares", value: "\(shares.unitFormatted(4)) share")
            Divider().background(Color.white.opacity(0.08))
        }
        if let hargaBeli = aset.hargaBeliPerShareUSD {
            DetailRow(label: "Harga Beli/Share", value: "$\(hargaBeli.unitFormatted(2))")
            Divider().background(Color.white.opacity(0.08))
        }
        // Harga saat ini + refresh
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Harga Saat Ini/Share")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                if let hargaNow = aset.hargaSaatIniUSD {
                    Text("$\(hargaNow.unitFormatted(2))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                } else {
                    Text("–")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            Spacer()
            Button {
                guard let kode = aset.kode else { return }
                isRefreshingKurs = true
                Task {
                    async let hargaTask = AsetPriceService.shared.fetchUSStockPrice(ticker: kode)
                    async let kursTask = AsetPriceService.shared.fetchKursValas(.usd)
                    let (harga, kurs) = await (hargaTask, kursTask)
                    if let h = harga { aset.hargaSaatIniUSD = h }
                    if let k = kurs { aset.kursSaatIniUSD = k }
                    if let h = harga ?? aset.hargaSaatIniUSD,
                       let k = kurs ?? aset.kursSaatIniUSD {
                        aset.nilaiSaatIni = aset.jumlahSharesAS * h * k
                    }
                    isRefreshingKurs = false
                }
            } label: {
                HStack(spacing: 4) {
                    if isRefreshingKurs {
                        ProgressView().tint(Color(hex: "#F97316")).scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                    }
                    Text("Update")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color(hex: "#F97316"))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(hex: "#F97316").opacity(0.12))
                .clipShape(Capsule())
            }
            .disabled(isRefreshingKurs || aset.kode == nil)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        Divider().background(Color.white.opacity(0.08))
        if let kursBeliUSD = aset.kursBeliUSD {
            DetailRow(label: "Kurs Beli (IDR/USD)", value: kursBeliUSD.idrDecimalFormatted)
            Divider().background(Color.white.opacity(0.08))
        }
        if let kursNow = aset.kursSaatIniUSD {
            DetailRow(label: "Kurs Saat Ini (IDR/USD)", value: kursNow.idrDecimalFormatted)
            Divider().background(Color.white.opacity(0.08))
        }
    }

    @ViewBuilder
    private var reksadanaDetails: some View {
        if let jenis = aset.jenisReksadana, !jenis.isEmpty {
            DetailRow(label: "Jenis", value: jenis)
            Divider().background(Color.white.opacity(0.08))
        }
        if let hargaBeli = aset.hargaBeliPerUnit {
            DetailRow(label: "NAV Saat Beli/Unit", value: hargaBeli.idrDecimalFormatted)
            Divider().background(Color.white.opacity(0.08))
        }
        // NAV saat ini + Update button
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("NAV Saat Ini/Unit")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                if let navNow = aset.navSaatIni {
                    Text(navNow.idrDecimalFormatted)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                } else {
                    Text("–")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            Spacer()
            Button {
                navInput = aset.navSaatIni.map { "\($0)" } ?? ""
                showUpdateNAV = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                        .font(.caption.weight(.semibold))
                    Text("Update NAV")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color(hex: "#22C55E"))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(hex: "#22C55E").opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        Divider().background(Color.white.opacity(0.08))
        let unitCount = aset.estimasiUnitReksadana
        if unitCount > 0 {
            DetailRow(label: "Jumlah Unit (Est.)", value: unitCount.unitFormatted(4))
            Divider().background(Color.white.opacity(0.08))
        }
        if let totalInv = aset.totalInvestasiReksadana {
            DetailRow(label: "Total Investasi", value: totalInv.idrDecimalFormatted)
            Divider().background(Color.white.opacity(0.08))
        }
    }

    @ViewBuilder
    private var valasDetails: some View {
        if let mata = aset.mataUangValas {
            DetailRow(label: "Mata Uang", value: "\(mata.flag) \(mata.rawValue)")
            Divider().background(Color.white.opacity(0.08))
        }
        if let jumlah = aset.jumlahValas {
            let mata = aset.mataUangValas?.rawValue ?? ""
            DetailRow(label: "Jumlah", value: "\(jumlah.unitFormatted(2)) \(mata)")
            Divider().background(Color.white.opacity(0.08))
        }
        if let kursBeli = aset.kursBeliPerUnit {
            DetailRow(label: "Kurs Beli", value: kursBeli.idrDecimalFormatted)
            Divider().background(Color.white.opacity(0.08))
        }
        // Kurs saat ini + refresh button
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Kurs Saat Ini")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                if let kursNow = aset.kursSaatIni {
                    Text(kursNow.idrDecimalFormatted)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                } else {
                    Text("–")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            Spacer()
            Button {
                guard let mata = aset.mataUangValas else { return }
                isRefreshingKurs = true
                Task {
                    if let kurs = await AsetPriceService.shared.fetchKursValas(mata) {
                        aset.kursSaatIni = kurs
                        aset.nilaiSaatIni = (aset.jumlahValas ?? 0) * kurs
                    }
                    isRefreshingKurs = false
                }
            } label: {
                HStack(spacing: 4) {
                    if isRefreshingKurs {
                        ProgressView().tint(Color(hex: "#06B6D4")).scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                    }
                    Text("Update")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color(hex: "#06B6D4"))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(hex: "#06B6D4").opacity(0.12))
                .clipShape(Capsule())
            }
            .disabled(isRefreshingKurs || aset.mataUangValas == nil)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        Divider().background(Color.white.opacity(0.08))
        // Selisih kurs
        if let kursBeli = aset.kursBeliPerUnit, let kursNow = aset.kursSaatIni {
            let selisih = kursNow - kursBeli
            let naik = selisih >= 0
            DetailRow(
                label: "Selisih Kurs/Unit",
                value: "\(naik ? "+" : "")\(selisih.idrDecimalFormatted)",
                valueColor: naik ? Color(hex: "#22C55E") : Color(hex: "#EF4444")
            )
            Divider().background(Color.white.opacity(0.08))
        }
    }

    @ViewBuilder
    private var depositoDetails: some View {
        // Progress bar — tenor berjalan
        let progress = aset.progressDeposito
        let hariLagi = aset.hariLagiDeposito
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progres Tenor")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(hariLagi == 0 ? "Jatuh tempo!" : "\(hariLagi) hari lagi")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(hariLagi <= 7 ? Color(hex: "#EF4444") : Color(hex: "#A78BFA"))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#A78BFA"), Color(hex: "#7C3AED")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(progress), height: 8)
                }
            }
            .frame(height: 8)
            HStack {
                Text(aset.tanggalMulaiDeposito.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "–")
                    .font(.caption2).foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text(aset.jatuhTempoDeposito.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "–")
                    .font(.caption2).foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        Divider().background(Color.white.opacity(0.08))

        if let nominal = aset.nominalDeposito {
            DetailRow(label: "Nominal", value: nominal.idrDecimalFormatted)
            Divider().background(Color.white.opacity(0.08))
        }
        if let bunga = aset.bungaPA {
            DetailRow(label: "Bunga p.a.", value: "\(bunga.unitFormatted(2))%")
            Divider().background(Color.white.opacity(0.08))
        }
        if let pph = aset.pphFinal {
            DetailRow(label: "PPh Final", value: "\(pph.unitFormatted(0))%")
            Divider().background(Color.white.opacity(0.08))
        }
        if let tenor = aset.tenorBulan {
            DetailRow(label: "Tenor", value: "\(tenor) bulan")
            Divider().background(Color.white.opacity(0.08))
        }
        if let jatuhTempo = aset.jatuhTempoDeposito {
            DetailRow(label: "Jatuh Tempo", value: jatuhTempo.formatted(date: .abbreviated, time: .omitted))
            Divider().background(Color.white.opacity(0.08))
        }
        if let pocket = aset.pocketSumber {
            DetailRow(label: "Bank / Pocket", value: pocket.nama)
            Divider().background(Color.white.opacity(0.08))
        }
        let bungaBersih = aset.bungaBersihDeposito
        if bungaBersih > 0 {
            DetailRow(label: "Bunga Bersih (s/d hari ini)", value: "+ \(bungaBersih.idrDecimalFormatted)", valueColor: Color(hex: "#22C55E"))
            Divider().background(Color.white.opacity(0.08))
            let totalEst = (aset.nominalDeposito ?? 0) + bungaBersih
            DetailRow(label: "Est. Total Pencairan", value: totalEst.idrDecimalFormatted, valueColor: Color(hex: "#A78BFA"))
            Divider().background(Color.white.opacity(0.08))
        }
        if aset.autoRollOver {
            DetailRow(label: "Auto Roll Over", value: "Aktif")
            Divider().background(Color.white.opacity(0.08))
        }
    }

    @ViewBuilder
    private var emasDetails: some View {
        if let jenis = aset.jenisEmas {
            DetailRow(label: "Jenis Emas", value: jenis.displayName)
            Divider().background(Color.white.opacity(0.08))
        }
        if let tahun = aset.tahunCetak, aset.jenisEmas?.isDigital != true {
            DetailRow(label: "Tahun Cetak", value: "\(tahun)")
            Divider().background(Color.white.opacity(0.08))
        }
        if let berat = aset.beratGram {
            DetailRow(label: "Berat", value: "\(berat.unitFormatted(2)) gram")
            Divider().background(Color.white.opacity(0.08))
        }
        if let harga = aset.hargaBeliPerGram {
            DetailRow(label: "Harga Beli/Gram", value: harga.idrDecimalFormatted)
            Divider().background(Color.white.opacity(0.08))
        }
        // Harga saat ini + Update button
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Harga Buyback Saat Ini/Gram")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                let hargaSaatIni = aset.beratGram.map { aset.nilaiSaatIni / $0 }
                if let h = hargaSaatIni, h > 0 {
                    Text(h.idrDecimalFormatted)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                } else {
                    Text("–")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            Spacer()
            Button {
                let hargaSaatIni = aset.beratGram.map { aset.nilaiSaatIni / $0 }
                hargaEmasInput = hargaSaatIni.map { "\($0)" } ?? ""
                showUpdateHargaEmas = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                        .font(.caption.weight(.semibold))
                    Text("Update Harga")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color(hex: "#F59E0B"))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(hex: "#F59E0B").opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        Divider().background(Color.white.opacity(0.08))
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            // Edit
            Button {
                editMode = .edit
                showEdit = true
            } label: {
                Label("Edit", systemImage: "pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if aset.tipe == .deposito {
                // Cairkan
                Button {
                    showCairkan = true
                } label: {
                    Label("Cairkan", systemImage: "banknote.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: "#A78BFA"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "#A78BFA").opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                // Jual
                Button {
                    showJual = true
                } label: {
                    Label("Jual", systemImage: "arrow.up.right.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: "#EF4444"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "#EF4444").opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Beli
                Button {
                    switch aset.tipe {
                    case .saham:     showBeliSaham = true
                    case .reksadana: showTambahReksadana = true
                    case .valas:     showBeliValas = true
                    default:
                        editMode = .beli
                        showEdit = true
                    }
                } label: {
                    Label("Beli", systemImage: "arrow.down.left.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: "#22C55E"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "#22C55E").opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Update Helpers

    private func saveNAV() {
        guard let nav = Decimal(string: navInput.replacingOccurrences(of: ",", with: ".")) else { return }
        aset.navSaatIni = nav
        aset.nilaiSaatIni = aset.estimasiUnitReksadana * nav
        try? modelContext.save()
        navInput = ""
    }

    private func saveHargaBeli() {
        guard let harga = Decimal(string: hargaBeliInput.replacingOccurrences(of: ",", with: "."), locale: .current),
              harga > 0 else { return }
        aset.hargaPerLembar = harga
        // Nilai saat ini tidak diubah (tetap harga pasar), hanya modal yang berubah
        try? modelContext.save()
        hargaBeliInput = ""
    }

    private func saveHargaEmas() {
        guard let harga = Decimal(string: hargaEmasInput.replacingOccurrences(of: ",", with: ".")) else { return }
        aset.nilaiSaatIni = (aset.beratGram ?? 0) * harga
        try? modelContext.save()
        hargaEmasInput = ""
    }

    // MARK: - Hapus Button

    private var hapusButton: some View {
        Button {
            showHapusAlert = true
        } label: {
            Label("Hapus Aset", systemImage: "trash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hex: "#EF4444").opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hex: "#EF4444").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#EF4444").opacity(0.2), lineWidth: 1)
                )
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .white

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Edit Mode

enum AsetEditMode {
    case edit, beli, jual
}
