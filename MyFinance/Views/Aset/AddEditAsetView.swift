import SwiftUI
import SwiftData

struct AddEditAsetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query var allPockets: [Pocket]

    // Pass existing aset for editing
    var existingAset: Aset? = nil
    var mode: AsetEditMode = .edit

    // MARK: - Form State

    @State private var selectedTipe: TipeAset = .saham

    // Saham
    @State private var sahamNama: String = ""
    @State private var sahamKode: String = ""
    @State private var sahamLot: String = ""
    @State private var sahamHargaPerLembar: Decimal = 0
    @State private var sahamHargaMarket: Decimal? = nil

    // Kripto
    @State private var kriptoMataUang: MataUangKripto = .idr
    @State private var kriptoNama: String = ""
    @State private var kriptoKode: String = ""
    @State private var kriptoTotalInvestasi: Decimal = 0
    @State private var kriptoHargaPerUnit: Decimal = 0

    // Reksadana
    @State private var rdNama: String = ""
    @State private var rdKode: String = ""
    @State private var rdJenis: String = ""
    @State private var rdTotalInvestasi: Decimal = 0
    @State private var rdNav: Decimal = 0

    // Emas
    @State private var emasJenis: JenisEmas = .lmAntam
    @State private var emasTahunCetak: Int = Calendar.current.component(.year, from: Date())
    @State private var emasBeratGram: String = ""
    @State private var emasHargaBeliPerGram: Decimal = 0

    // Common
    @State private var catatSbgPengeluaran: Bool = false
    @State private var selectedPocket: Pocket? = nil

    // Fetch state
    @State private var isFetchingPrice = false

    private let rdJenisList = ["Campuran", "Saham", "Index ETF", "Pasar Uang", "Pendapatan Tetap", "Syariah", "Terproteksi"]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Type Selector
                        tipeSelectorSection

                        // Type-specific form
                        Group {
                            switch selectedTipe {
                            case .saham:   sahamFormSection
                            case .kripto:  kriptoFormSection
                            case .reksadana: reksadanaFormSection
                            case .emas:    emasFormSection
                            }
                        }

                        // Common: Catat sbg Pengeluaran
                        catatPengeluaranSection

                        // CTA
                        ctaButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(navigationTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        if let existing = existingAset {
            switch mode {
            case .edit: return "Edit \(existing.tipe.displayName)"
            case .beli: return "Beli \(existing.tipe.displayName)"
            case .jual: return "Jual \(existing.tipe.displayName)"
            }
        }
        return "Tambah Aset"
    }

    // MARK: - Tipe Selector

    private var tipeSelectorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TIPE ASET")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1)

            HStack(spacing: 10) {
                ForEach(TipeAset.allCases) { tipe in
                    TipeAsetButton(
                        tipe: tipe,
                        isSelected: selectedTipe == tipe
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTipe = tipe
                        }
                    }
                    .disabled(existingAset != nil)
                }
            }
        }
    }

    // MARK: - Saham Form

    private var sahamFormSection: some View {
        VStack(spacing: 16) {
            FormCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("DETAIL SAHAM")
                        .formSectionLabel()

                    FormField(label: "NAMA PERUSAHAAN") {
                        TextField("Contoh: Bank Central Asia", text: $sahamNama)
                            .styledInput()
                    }

                    FormField(label: "KODE SAHAM") {
                        HStack {
                            TextField("Contoh: BBCA", text: $sahamKode)
                                .textInputAutocapitalization(.characters)
                                .styledInput()
                            if isFetchingPrice {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.trailing, 4)
                            }
                        }
                        if let hargaMarket = sahamHargaMarket {
                            Text("Harga pasar: \(hargaMarket.idrFormatted)/lembar")
                                .font(.caption)
                                .foregroundStyle(Color(hex: "#22C55E"))
                        }
                    }
                    .onChange(of: sahamKode) { _, kode in
                        if kode.count >= 4 {
                            Task { await fetchSahamMarketPrice(kode: kode) }
                        }
                    }

                    FormField(label: "JUMLAH LOT") {
                        TextField("Contoh: 10", text: $sahamLot)
                            .keyboardType(.numberPad)
                            .styledInput()
                    }

                    FormField(label: "HARGA BELI/LEMBAR") {
                        HStack(spacing: 8) {
                            Text("Rp")
                                .foregroundStyle(.white.opacity(0.5))
                                .font(.subheadline)
                            CurrencyInputField(value: $sahamHargaPerLembar)
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private func fetchSahamMarketPrice(kode: String) async {
        isFetchingPrice = true
        defer { isFetchingPrice = false }
        if let price = await AsetPriceService.shared.fetchSahamPrice(kode: kode) {
            await MainActor.run { sahamHargaMarket = price }
        }
    }

    // MARK: - Kripto Form

    private var kriptoFormSection: some View {
        VStack(spacing: 16) {
            FormCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("DETAIL KRIPTO")
                        .formSectionLabel()

                    // Mata Uang segmented
                    FormField(label: "MATA UANG") {
                        HStack(spacing: 0) {
                            ForEach(MataUangKripto.allCases) { mu in
                                Button {
                                    kriptoMataUang = mu
                                } label: {
                                    Text(mu.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(kriptoMataUang == mu ? .black : .white.opacity(0.6))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(kriptoMataUang == mu ? Color(hex: "#F97316") : Color.clear)
                                }
                            }
                        }
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    FormField(label: "NAMA KOIN") {
                        TextField("Contoh: Bitcoin", text: $kriptoNama)
                            .styledInput()
                    }

                    FormField(label: "KODE / TICKER") {
                        TextField("Contoh: BTC", text: $kriptoKode)
                            .textInputAutocapitalization(.characters)
                            .styledInput()
                    }

                    FormField(label: "TOTAL INVESTASI") {
                        HStack(spacing: 8) {
                            Text("Rp")
                                .foregroundStyle(.white.opacity(0.5))
                                .font(.subheadline)
                            CurrencyInputField(value: $kriptoTotalInvestasi)
                        }
                    }

                    FormField(label: "HARGA BELI/UNIT (IDR)") {
                        HStack(spacing: 8) {
                            Text("Rp")
                                .foregroundStyle(.white.opacity(0.5))
                                .font(.subheadline)
                            CurrencyInputField(value: $kriptoHargaPerUnit)
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Reksadana Form

    private var reksadanaFormSection: some View {
        VStack(spacing: 16) {
            FormCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("DETAIL REKSADANA")
                        .formSectionLabel()

                    FormField(label: "JENIS REKSADANA") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(rdJenisList, id: \.self) { jenis in
                                    ChipButton(
                                        label: jenis,
                                        isSelected: rdJenis == jenis,
                                        color: Color(hex: "#3B82F6")
                                    ) {
                                        rdJenis = rdJenis == jenis ? "" : jenis
                                    }
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }

                    FormField(label: "NAMA PRODUK") {
                        TextField("Contoh: Bibit Equity Fund", text: $rdNama)
                            .styledInput()
                    }

                    FormField(label: "KODE / ID") {
                        TextField("Opsional", text: $rdKode)
                            .styledInput()
                    }

                    FormField(label: "TOTAL INVESTASI") {
                        HStack(spacing: 8) {
                            Text("Rp")
                                .foregroundStyle(.white.opacity(0.5))
                                .font(.subheadline)
                            CurrencyInputField(value: $rdTotalInvestasi)
                        }
                    }

                    FormField(label: "NAV / HARGA PER UNIT") {
                        HStack(spacing: 8) {
                            Text("Rp")
                                .foregroundStyle(.white.opacity(0.5))
                                .font(.subheadline)
                            CurrencyInputField(value: $rdNav)
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Emas Form

    private var emasFormSection: some View {
        VStack(spacing: 16) {
            FormCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("DETAIL EMAS")
                        .formSectionLabel()

                    FormField(label: "JENIS EMAS") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(JenisEmas.allCases) { jenis in
                                    ChipButton(
                                        label: jenis.displayName,
                                        isSelected: emasJenis == jenis,
                                        color: Color(hex: "#EAB308")
                                    ) {
                                        emasJenis = jenis
                                    }
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }

                    FormField(label: "TAHUN CETAK") {
                        let years = Array(2010...Calendar.current.component(.year, from: Date()))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(years.reversed(), id: \.self) { year in
                                    ChipButton(
                                        label: "\(year)",
                                        isSelected: emasTahunCetak == year,
                                        color: Color(hex: "#EAB308")
                                    ) {
                                        emasTahunCetak = year
                                    }
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }

                    FormField(label: "BERAT (GRAM)") {
                        TextField("Contoh: 1.5", text: $emasBeratGram)
                            .keyboardType(.decimalPad)
                            .styledInput()
                    }

                    FormField(label: "HARGA BELI/GRAM") {
                        HStack(spacing: 8) {
                            Text("Rp")
                                .foregroundStyle(.white.opacity(0.5))
                                .font(.subheadline)
                            CurrencyInputField(value: $emasHargaBeliPerGram)
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Catat Pengeluaran Section

    private var catatPengeluaranSection: some View {
        FormCard {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $catatSbgPengeluaran) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Catat sbg Pengeluaran")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Otomatis memotong saldo kas kamu")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .tint(selectedTipe.color)

                if catatSbgPengeluaran {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PILIH POCKET SUMBER")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .tracking(1)
                        PocketChipPicker(
                            pockets: allPockets.filter { $0.isAktif && $0.kelompokPocket == .biasa },
                            selected: $selectedPocket
                        )
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button(action: saveAset) {
            Text(existingAset == nil ? "Tambah Aset" : "Simpan Perubahan")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(selectedTipe.color)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!isFormValid)
        .opacity(isFormValid ? 1 : 0.5)
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        switch selectedTipe {
        case .saham:
            return !sahamNama.isEmpty && !sahamLot.isEmpty && sahamHargaPerLembar > 0
        case .kripto:
            return !kriptoNama.isEmpty && kriptoTotalInvestasi > 0 && kriptoHargaPerUnit > 0
        case .reksadana:
            return !rdNama.isEmpty && rdTotalInvestasi > 0
        case .emas:
            return !emasBeratGram.isEmpty && emasHargaBeliPerGram > 0
        }
    }

    // MARK: - Save

    private func saveAset() {
        let aset: Aset
        if let existing = existingAset {
            aset = existing
        } else {
            aset = Aset(tipe: selectedTipe, nama: currentNama, kode: currentKode)
            modelContext.insert(aset)
        }

        // Populate fields
        aset.tipe = selectedTipe

        switch selectedTipe {
        case .saham:
            aset.nama = sahamNama
            aset.kode = sahamKode.uppercased()
            aset.lot = Decimal(string: sahamLot) ?? 0
            aset.hargaPerLembar = sahamHargaPerLembar
            aset.nilaiSaatIni = (Decimal(string: sahamLot) ?? 0) * sahamHargaPerLembar * 100

        case .kripto:
            aset.nama = kriptoNama
            aset.kode = kriptoKode.uppercased()
            aset.mataUang = kriptoMataUang
            aset.totalInvestasiKripto = kriptoTotalInvestasi
            aset.hargaPerUnit = kriptoHargaPerUnit
            aset.nilaiSaatIni = kriptoTotalInvestasi

        case .reksadana:
            aset.nama = rdNama
            aset.kode = rdKode.isEmpty ? nil : rdKode
            aset.jenisReksadana = rdJenis.isEmpty ? nil : rdJenis
            aset.totalInvestasiReksadana = rdTotalInvestasi
            aset.nav = rdNav > 0 ? rdNav : nil
            aset.nilaiSaatIni = rdTotalInvestasi

        case .emas:
            aset.nama = "\(emasJenis.displayName) \(emasBeratGram)g"
            aset.jenisEmas = emasJenis
            aset.tahunCetak = emasTahunCetak
            aset.beratGram = Decimal(string: emasBeratGram.replacingOccurrences(of: ",", with: ".")) ?? 0
            aset.hargaBeliPerGram = emasHargaBeliPerGram
            aset.nilaiSaatIni = (Decimal(string: emasBeratGram.replacingOccurrences(of: ",", with: ".")) ?? 0) * emasHargaBeliPerGram
        }

        aset.catatSbgPengeluaran = catatSbgPengeluaran
        aset.pocketSumber = catatSbgPengeluaran ? selectedPocket : nil

        // Deduct from pocket and create transaction if needed
        if catatSbgPengeluaran, let pocket = selectedPocket, existingAset == nil {
            let modalValue = aset.modal
            pocket.saldo -= modalValue

            let transaksi = Transaksi(
                tanggal: Date(),
                nominal: modalValue,
                tipe: .pengeluaran,
                subTipe: .normal,
                pocket: pocket,
                catatan: "Investasi: \(aset.nama)"
            )
            modelContext.insert(transaksi)
        }

        try? modelContext.save()
        dismiss()
    }

    // MARK: - Populate for editing

    private func populateIfEditing() {
        guard let a = existingAset else { return }
        selectedTipe = a.tipe

        switch a.tipe {
        case .saham:
            sahamNama = a.nama
            sahamKode = a.kode ?? ""
            sahamLot = a.lot.map { "\(NSDecimalNumber(decimal: $0).intValue)" } ?? ""
            sahamHargaPerLembar = a.hargaPerLembar ?? 0
        case .kripto:
            kriptoNama = a.nama
            kriptoKode = a.kode ?? ""
            kriptoMataUang = a.mataUang ?? .idr
            kriptoTotalInvestasi = a.totalInvestasiKripto ?? 0
            kriptoHargaPerUnit = a.hargaPerUnit ?? 0
        case .reksadana:
            rdNama = a.nama
            rdKode = a.kode ?? ""
            rdJenis = a.jenisReksadana ?? ""
            rdTotalInvestasi = a.totalInvestasiReksadana ?? 0
            rdNav = a.nav ?? 0
        case .emas:
            emasJenis = a.jenisEmas ?? .lmAntam
            emasTahunCetak = a.tahunCetak ?? Calendar.current.component(.year, from: Date())
            emasBeratGram = a.beratGram.map { "\(Double(truncating: $0 as NSDecimalNumber))" } ?? ""
            emasHargaBeliPerGram = a.hargaBeliPerGram ?? 0
        }

        catatSbgPengeluaran = a.catatSbgPengeluaran
        selectedPocket = a.pocketSumber
    }

    // MARK: - Helpers

    private var currentNama: String {
        switch selectedTipe {
        case .saham: return sahamNama
        case .kripto: return kriptoNama
        case .reksadana: return rdNama
        case .emas: return "\(emasJenis.displayName) \(emasBeratGram)g"
        }
    }

    private var currentKode: String? {
        switch selectedTipe {
        case .saham: return sahamKode.isEmpty ? nil : sahamKode.uppercased()
        case .kripto: return kriptoKode.isEmpty ? nil : kriptoKode.uppercased()
        case .reksadana: return rdKode.isEmpty ? nil : rdKode
        case .emas: return nil
        }
    }
}

// MARK: - TipeAset Button

private struct TipeAsetButton: View {
    let tipe: TipeAset
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isSelected ? tipe.color : Color.white.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: tipe.iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? .black : .white.opacity(0.5))
            }
            Text(tipe.displayName)
                .font(.caption2.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? tipe.color : .white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(isSelected ? tipe.color.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? tipe.color.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Chip Button

struct ChipButton: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? color : Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Form Helpers

struct FormCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .tracking(0.8)
            content
        }
    }
}

// MARK: - Text Style Helpers

extension View {
    func styledInput() -> some View {
        self
            .foregroundStyle(.white)
            .padding(12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

extension Text {
    func formSectionLabel() -> some View {
        self
            .font(.caption)
            .foregroundStyle(.white.opacity(0.5))
            .tracking(1)
    }
}

