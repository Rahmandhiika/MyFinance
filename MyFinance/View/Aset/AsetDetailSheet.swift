import SwiftUI
import SwiftData

struct AsetDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let aset: Aset

    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme

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
    @State private var showEditModalEmas = false
    @State private var modalEmasInput = ""
    @State private var showEditHargaBeliEmas = false
    @State private var hargaBeliEmasInput = ""
    @State private var showEditBeratEmas = false
    @State private var beratEmasInput = ""
    @State private var showEditSharesAS = false
    @State private var sharesASInput = ""
    @State private var showEditHargaBeliAS = false
    @State private var hargaBeliASInput = ""
    @State private var showBeliSaham = false
    @State private var showBeliSahamAS = false
    @State private var showBeliEmas = false
    @State private var showTambahReksadana = false
    @State private var showBeliValas = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bgApp.ignoresSafeArea()

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
            .toolbarBackground(theme.bgApp, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(aset.nama)
                            .font(.headline)
                            .foregroundStyle(theme.textPrimary)
                        if let kode = aset.kode, !kode.isEmpty {
                            Text(kode.uppercased())
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textSecondary)
                            .font(.title3)
                    }
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
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
        .sheet(isPresented: $showBeliSahamAS) {
            BeliSahamASSheet(aset: aset)
        }
        .sheet(isPresented: $showBeliEmas) {
            BeliEmasSheet(aset: aset)
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
        .alert("Edit Harga Beli/Gram", isPresented: $showEditHargaBeliEmas) {
            TextField("Harga beli per gram (Rp)", text: $hargaBeliEmasInput)
                .keyboardType(.numberPad)
            Button("Simpan") { saveHargaBeliEmas() }
            Button("Batal", role: .cancel) { hargaBeliEmasInput = "" }
        } message: {
            Text("Harga beli saat ini: \(aset.hargaBeliPerGram?.idrFormatted ?? "-")/gram\nBerat: \(aset.beratGram?.unitFormattedSmart ?? "-")g")
        }
        .alert("Edit Total Modal", isPresented: $showEditModalEmas) {
            TextField("Total modal (Rp)", text: $modalEmasInput)
                .keyboardType(.numberPad)
            Button("Simpan") { saveModalEmas() }
            Button("Batal", role: .cancel) { modalEmasInput = "" }
        } message: {
            Text("Modal saat ini: \(aset.modal.idrFormatted)\nBerat TIDAK berubah. Yang disesuaikan adalah harga beli/gram.")
        }
        .alert("Edit Gram Emas", isPresented: $showEditBeratEmas) {
            TextField("Jumlah gram (contoh: 0.190519)", text: $beratEmasInput)
                .keyboardType(.decimalPad)
            Button("Simpan") { saveBeratEmas() }
            Button("Batal", role: .cancel) { beratEmasInput = "" }
        } message: {
            Text("Gram saat ini: \(aset.beratGram?.unitFormattedSmart ?? "-")g\nMasukkan gram terbaru sesuai Pluang.")
        }
        .alert("Edit Jumlah Shares", isPresented: $showEditSharesAS) {
            TextField("Contoh: 0.084917399", text: $sharesASInput)
                .keyboardType(.decimalPad)
            Button("Simpan") { saveSharesAS() }
            Button("Batal", role: .cancel) { sharesASInput = "" }
        } message: {
            Text("Shares saat ini: \(aset.jumlahSharesAS.unitFormattedSmart)\nHanya mengubah jumlah shares — harga beli & modal tidak berubah.")
        }
        .alert("Edit Avg Buy Price", isPresented: $showEditHargaBeliAS) {
            TextField("Contoh: 362.77", text: $hargaBeliASInput)
                .keyboardType(.decimalPad)
            Button("Simpan") { saveHargaBeliAS() }
            Button("Batal", role: .cancel) { hargaBeliASInput = "" }
        } message: {
            Text("Harga beli saat ini: $\(aset.hargaBeliPerShareUSD?.unitFormatted(2) ?? "-")/share\nHanya mengubah avg buy price — jumlah shares tidak berubah.")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            // Tipe icon — deposito pakai logo pocket sumber jika ada
            let iconData: Data? = aset.logoData ?? (aset.tipe == .deposito ? aset.pocketSumber?.logo : nil)
            ZStack {
                Circle()
                    .fill(aset.tipe.color.opacity(0.15))
                    .frame(width: 56, height: 56)
                if let data = iconData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                } else {
                    Image(systemName: aset.tipe.iconName)
                        .font(.title2)
                        .foregroundStyle(aset.tipe.color)
                }
            }

            Text("NILAI PASAR")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .tracking(1)

            // Untuk sahamAS: tampilkan USD secara prominent, IDR di bawahnya
            if aset.tipe == .sahamAS, let hargaNow = aset.hargaSaatIniUSD {
                let sharesNow = aset.jumlahSharesAS
                let nilaiUSD = sharesNow * hargaNow
                Text("$\(nilaiUSD.unitFormatted(2))")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                if let kursNow = aset.kursSaatIniUSD, kursNow > 0 {
                    Text(aset.nilaiEfektif.idrDecimalFormatted)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.textSecondary)
                }
            } else {
                Text(aset.nilaiEfektif.idrDecimalFormatted)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
            }

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
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Detail Grid

    private var detailGridSection: some View {
        VStack(spacing: 0) {
            DetailRow(label: "Tipe Aset", value: aset.tipe.displayName)
            Divider().background(theme.separator)

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

            Divider().background(theme.separator)
            DetailRow(label: "Total Modal", value: aset.modal.idrDecimalFormatted)
            Divider().background(theme.separator)
            DetailRow(
                label: "Keuntungan / Rugi",
                value: "\(aset.pnl >= 0 ? "+" : "")\(aset.pnl.idrDecimalFormatted)",
                valueColor: aset.pnl >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444")
            )
            Divider().background(theme.separator)
            DetailRow(
                label: "Return",
                value: aset.returnPersen.percentFormatted,
                valueColor: aset.pnl >= 0 ? Color(hex: "#22C55E") : Color(hex: "#EF4444")
            )
        }
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var sahamDetails: some View {
        if let lot = aset.lot {
            DetailRow(label: "Jumlah Lot", value: "\(NSDecimalNumber(decimal: lot).intValue) lot")
            Divider().background(theme.separator)
        }
        // Harga beli/lembar — bisa di-edit (mempengaruhi Total Modal)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rata-rata Harga Beli/Lembar")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                Text(aset.hargaPerLembar?.idrDecimalFormatted ?? "–")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
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
        Divider().background(theme.separator)
        // Harga saat ini + refresh button
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Harga Saat Ini/Lembar")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                let hargaSaatIniPerLembar = (aset.lot ?? 0) > 0
                    ? aset.nilaiSaatIni / ((aset.lot ?? 1) * 100)
                    : Decimal(0)
                Text(hargaSaatIniPerLembar > 0 ? hargaSaatIniPerLembar.idrDecimalFormatted : "–")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
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
        Divider().background(theme.separator)
    }

    @ViewBuilder
    private var sahamASDetails: some View {
        if let kode = aset.kode, !kode.isEmpty {
            DetailRow(label: "Ticker", value: kode.uppercased())
            Divider().background(theme.separator)
        }
        // Amount (pre-fee) + fee breakdown
        if let totalUSD = aset.totalInvestasiUSD {
            let feeUSD = aset.biayaFeeUSD ?? 0
            let totalDibayar = totalUSD + feeUSD
            if feeUSD > 0 {
                DetailRow(label: "Total Dibayar (USD)", value: "$\(totalDibayar.unitFormatted(2))")
                Divider().background(theme.separator)
                DetailRow(label: "  · Amount", value: "$\(totalUSD.unitFormatted(2))")
                Divider().background(theme.separator)
                DetailRow(label: "  · Fee + Pajak", value: "$\(feeUSD.unitFormatted(2))")
            } else {
                DetailRow(label: "Total Investasi (USD)", value: "$\(totalUSD.unitFormatted(2))")
            }
            Divider().background(theme.separator)
        }
        let shares = aset.jumlahSharesAS
        if shares > 0 {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Jumlah Shares")
                        .font(.subheadline).foregroundStyle(theme.textSecondary)
                    Text("\(shares.unitFormattedSmart) shares")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(theme.textPrimary)
                }
                Spacer()
                Button {
                    sharesASInput = "\(shares)"
                    showEditSharesAS = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil").font(.caption.weight(.semibold))
                        Text("Edit").font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color(hex: "#2252BA"))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(hex: "#2252BA").opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            Divider().background(theme.separator)
        }
        if let hargaBeli = aset.hargaBeliPerShareUSD {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Avg Buy Price/Share")
                        .font(.subheadline).foregroundStyle(theme.textSecondary)
                    Text("$\(hargaBeli.unitFormatted(2))")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(theme.textPrimary)
                }
                Spacer()
                Button {
                    hargaBeliASInput = "\(hargaBeli)"
                    showEditHargaBeliAS = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil").font(.caption.weight(.semibold))
                        Text("Edit").font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color(hex: "#2252BA"))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(hex: "#2252BA").opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            Divider().background(theme.separator)
        }
        // Harga saat ini + refresh
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Harga Saat Ini/Share")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                if let hargaNow = aset.hargaSaatIniUSD {
                    Text("$\(hargaNow.unitFormatted(2))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                } else {
                    Text("–")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
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
        Divider().background(theme.separator)
        // P&L dalam USD
        if let hargaBeli = aset.hargaBeliPerShareUSD,
           let hargaNow = aset.hargaSaatIniUSD {
            let shares = aset.jumlahSharesAS
            let pnlUSD = shares * (hargaNow - hargaBeli)
            let pnlPositive = pnlUSD >= 0
            DetailRow(
                label: "P&L (USD)",
                value: "\(pnlPositive ? "+" : "")$\(pnlUSD.unitFormatted(2))",
                valueColor: pnlPositive ? Color(hex: "#22C55E") : Color(hex: "#EF4444")
            )
            Divider().background(theme.separator)
        }
    }

    @ViewBuilder
    private var reksadanaDetails: some View {
        if let jenis = aset.jenisReksadana, !jenis.isEmpty {
            DetailRow(label: "Jenis", value: jenis)
            Divider().background(theme.separator)
        }
        if let hargaBeli = aset.hargaBeliPerUnit {
            DetailRow(label: "NAV Saat Beli/Unit", value: hargaBeli.idrDecimalFormatted)
            Divider().background(theme.separator)
        }
        // NAV saat ini + Update button
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("NAV Saat Ini/Unit")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                if let navNow = aset.navSaatIni {
                    Text(navNow.idrDecimalFormatted)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                } else {
                    Text("–")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
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
        Divider().background(theme.separator)
        let unitCount = aset.estimasiUnitReksadana
        if unitCount > 0 {
            DetailRow(label: "Jumlah Unit (Est.)", value: unitCount.unitFormattedSmart)
            Divider().background(theme.separator)
        }
        if let totalInv = aset.totalInvestasiReksadana {
            DetailRow(label: "Total Investasi", value: totalInv.idrDecimalFormatted)
            Divider().background(theme.separator)
        }
    }

    @ViewBuilder
    private var valasDetails: some View {
        if let mata = aset.mataUangValas {
            DetailRow(label: "Mata Uang", value: "\(mata.flag) \(mata.rawValue)")
            Divider().background(theme.separator)
        }
        if let jumlah = aset.jumlahValas {
            let mata = aset.mataUangValas?.rawValue ?? ""
            DetailRow(label: "Jumlah", value: "\(jumlah.unitFormatted(2)) \(mata)")
            Divider().background(theme.separator)
        }
        if let kursBeli = aset.kursBeliPerUnit {
            DetailRow(label: "Kurs Beli", value: kursBeli.idrDecimalFormatted)
            Divider().background(theme.separator)
        }
        // Kurs saat ini + refresh button
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Kurs Saat Ini")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                if let kursNow = aset.kursSaatIni {
                    Text(kursNow.idrDecimalFormatted)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                } else {
                    Text("–")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
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
        Divider().background(theme.separator)
        // Selisih kurs
        if let kursBeli = aset.kursBeliPerUnit, let kursNow = aset.kursSaatIni {
            let selisih = kursNow - kursBeli
            let naik = selisih >= 0
            DetailRow(
                label: "Selisih Kurs/Unit",
                value: "\(naik ? "+" : "")\(selisih.idrDecimalFormatted)",
                valueColor: naik ? Color(hex: "#22C55E") : Color(hex: "#EF4444")
            )
            Divider().background(theme.separator)
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
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Text(hariLagi == 0 ? "Jatuh tempo!" : "\(hariLagi) hari lagi")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(hariLagi <= 7 ? Color(hex: "#EF4444") : Color(hex: "#A78BFA"))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.separator)
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
                    .font(.caption2).foregroundStyle(theme.textSecondary.opacity(0.7))
                Spacer()
                Text(aset.jatuhTempoDeposito.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "–")
                    .font(.caption2).foregroundStyle(theme.textSecondary.opacity(0.7))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        Divider().background(theme.separator)

        if let nominal = aset.nominalDeposito {
            DetailRow(label: "Nominal", value: nominal.idrDecimalFormatted)
            Divider().background(theme.separator)
        }
        if let bunga = aset.bungaPA {
            DetailRow(label: "Bunga p.a.", value: "\(bunga.unitFormatted(2))%")
            Divider().background(theme.separator)
        }
        if let pph = aset.pphFinal {
            DetailRow(label: "PPh Final", value: "\(pph.unitFormatted(0))%")
            Divider().background(theme.separator)
        }
        if let tenor = aset.tenorBulan {
            DetailRow(label: "Tenor", value: "\(tenor) bulan")
            Divider().background(theme.separator)
        }
        if let jatuhTempo = aset.jatuhTempoDeposito {
            DetailRow(label: "Jatuh Tempo", value: jatuhTempo.formatted(date: .abbreviated, time: .omitted))
            Divider().background(theme.separator)
        }
        if let pocket = aset.pocketSumber {
            DetailRow(label: "Bank / Pocket", value: pocket.nama)
            Divider().background(theme.separator)
        }
        let bungaBersih = aset.bungaBersihDeposito
        if bungaBersih > 0 {
            DetailRow(label: "Bunga Bersih (s/d hari ini)", value: "+ \(bungaBersih.idrDecimalFormatted)", valueColor: Color(hex: "#22C55E"))
            Divider().background(theme.separator)
            let totalEst = (aset.nominalDeposito ?? 0) + bungaBersih
            DetailRow(label: "Est. Total Pencairan", value: totalEst.idrDecimalFormatted, valueColor: Color(hex: "#A78BFA"))
            Divider().background(theme.separator)
        }
        if aset.autoRollOver {
            DetailRow(label: "Auto Roll Over", value: "Aktif")
            Divider().background(theme.separator)
        }
    }

    @ViewBuilder
    private var emasDetails: some View {
        if let jenis = aset.jenisEmas {
            DetailRow(label: "Jenis Emas", value: jenis.displayName)
            Divider().background(theme.separator)
        }
        if let tahun = aset.tahunCetak, aset.jenisEmas?.isDigital != true {
            DetailRow(label: "Tahun Cetak", value: "\(tahun)")
            Divider().background(theme.separator)
        }
        if let berat = aset.beratGram {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Berat")
                        .font(.subheadline).foregroundStyle(theme.textSecondary)
                    Text("\(berat.unitFormattedSmart) gram")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(theme.textPrimary)
                }
                Spacer()
                if aset.jenisEmas?.isDigital == true {
                    Button {
                        beratEmasInput = "\(berat)"
                        showEditBeratEmas = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil").font(.caption.weight(.semibold))
                            Text("Edit").font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color(hex: "#EAB308"))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color(hex: "#EAB308").opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            Divider().background(theme.separator)
        }

        // Harga Beli/Gram — editable
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Harga Beli/Gram")
                    .font(.subheadline).foregroundStyle(theme.textSecondary)
                Text(aset.hargaBeliPerGram?.idrDecimalFormatted ?? "–")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(theme.textPrimary)
            }
            Spacer()
            Button {
                hargaBeliEmasInput = aset.hargaBeliPerGram.map { "\(NSDecimalNumber(decimal: $0).intValue)" } ?? ""
                showEditHargaBeliEmas = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pencil").font(.caption.weight(.semibold))
                    Text("Edit").font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color(hex: "#EAB308"))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color(hex: "#EAB308").opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        Divider().background(theme.separator)

        // Total Modal — editable (untuk emas digital)
        if aset.jenisEmas?.isDigital == true {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Modal")
                        .font(.subheadline).foregroundStyle(theme.textSecondary)
                    Text(aset.modal.idrFormatted)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(theme.textPrimary)
                }
                Spacer()
                Button {
                    modalEmasInput = "\(NSDecimalNumber(decimal: aset.modal).intValue)"
                    showEditModalEmas = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil").font(.caption.weight(.semibold))
                        Text("Edit").font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color(hex: "#EAB308"))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(hex: "#EAB308").opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            Divider().background(theme.separator)
        }
        // Harga saat ini + Update button
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Harga Saat Ini/Gram")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                if let h = aset.hargaSaatIniEmasPerGram, h > 0 {
                    Text(h.idrDecimalFormatted)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                } else {
                    Text("Belum diset")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
                }
            }
            Spacer()
            Button {
                hargaEmasInput = aset.hargaSaatIniEmasPerGram.map { "\($0)" } ?? ""
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
        Divider().background(theme.separator)
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
                    .foregroundStyle(theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.cardBorder)
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
                    case .sahamAS:   showBeliSahamAS = true
                    case .emas:      showBeliEmas = true
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
        aset.hargaSaatIniEmasPerGram = harga
        aset.nilaiSaatIni = (aset.beratGram ?? 0) * harga
        try? modelContext.save()
        hargaEmasInput = ""
    }

    private func saveHargaBeliEmas() {
        guard let harga = Decimal(string: hargaBeliEmasInput.replacingOccurrences(of: ",", with: ".")),
              harga > 0 else { return }
        // Hanya ubah harga beli — berat TIDAK berubah
        aset.hargaBeliPerGram = harga
        try? modelContext.save()
        hargaBeliEmasInput = ""
    }

    private func saveModalEmas() {
        guard let modal = Decimal(string: modalEmasInput.replacingOccurrences(of: ",", with: ".")),
              modal > 0 else { return }
        // Modal = berat × harga_beli + pajak
        // Untuk set modal tanpa ubah berat → sesuaikan harga_beli
        // harga_beli = (modal - pajak) / berat
        let pajak = aset.pajakBeliEmas ?? 0
        let berat = aset.beratGram ?? 0
        if berat > 0 {
            aset.hargaBeliPerGram = (modal - pajak) / berat
        }
        // Berat TIDAK berubah
        try? modelContext.save()
        modalEmasInput = ""
    }

    private func saveSharesAS() {
        let cleaned = sharesASInput.replacingOccurrences(of: ",", with: ".")
        guard let newShares = Decimal(string: cleaned), newShares > 0 else { return }
        // Shares = totalInvestasiUSD / hargaBeliPerShare
        // Kalau kita ubah shares, yang paling bersih adalah update totalInvestasiUSD
        // supaya jumlahSharesAS computed property tetap akurat
        if let hargaBeli = aset.hargaBeliPerShareUSD, hargaBeli > 0 {
            aset.totalInvestasiUSD = newShares * hargaBeli
        } else {
            // Fallback: belum ada harga beli, set harga beli dari total / shares baru
            // Tidak ubah apapun selain nilaiSaatIni
        }
        // Update nilaiSaatIni (nilai pasar = shares × harga saat ini)
        if let hargaNow = aset.hargaSaatIniUSD, let kurs = aset.kursSaatIniUSD,
           hargaNow > 0, kurs > 0 {
            aset.nilaiSaatIni = newShares * hargaNow * kurs
        }
        try? modelContext.save()
        sharesASInput = ""
    }

    private func saveHargaBeliAS() {
        let cleaned = hargaBeliASInput.replacingOccurrences(of: ",", with: ".")
        guard let newHarga = Decimal(string: cleaned), newHarga > 0 else { return }
        // Hanya ubah avg buy price — totalInvestasiUSD & jumlah shares TIDAK berubah
        aset.hargaBeliPerShareUSD = newHarga
        try? modelContext.save()
        hargaBeliASInput = ""
    }

    private func saveBeratEmas() {
        let cleaned = beratEmasInput.replacingOccurrences(of: ",", with: ".")
        guard let berat = Decimal(string: cleaned), berat > 0 else { return }
        // Hanya ubah berat — harga beli & modal TIDAK dihitung ulang
        aset.beratGram = berat
        // Update nilaiSaatIni = gram baru × harga pasar saat ini (jika ada)
        let hargaNow = aset.hargaSaatIniEmasPerGram ?? aset.hargaBeliPerGram ?? 0
        if hargaNow > 0 {
            aset.nilaiSaatIni = berat * hargaNow
        }
        // Update nama supaya sesuai gram baru
        let jenisNama = aset.jenisEmas?.displayName ?? "Emas Digital"
        let gramStr = String(format: "%.7g", Double(truncating: berat as NSDecimalNumber))
        aset.nama = "\(jenisNama) \(gramStr)g"
        try? modelContext.save()
        beratEmasInput = ""
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
    @Environment(\.appTheme) private var theme
    let label: String
    let value: String
    var valueColor: Color = .white

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(valueColor == .white ? theme.textPrimary : valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Edit Mode

enum AsetEditMode {
    case edit, beli, jual
}
