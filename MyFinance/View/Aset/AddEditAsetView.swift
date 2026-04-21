import SwiftUI
import SwiftData

struct AddEditAsetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Pocket.urutan) var allPockets: [Pocket]

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
    @State private var isFetchingPrice = false

    // Reksadana
    @State private var rdNama: String = ""
    @State private var rdJenis: String = ""
    @State private var rdTotalInvestasi: Decimal = 0
    @State private var rdHargaBeliPerUnit: Decimal = 0
    @State private var rdNavSaatIni: Decimal = 0
    @State private var rdSearchQuery: String = ""
    @State private var rdSearchResults: [ReksadanaItem] = []
    @State private var rdShowResults: Bool = false

    // Saham AS
    @State private var asNama: String = ""
    @State private var asKode: String = ""
    @State private var asTotalInvestasiUSD: Decimal = 0
    @State private var asHargaBeliPerShareUSD: Decimal = 0
    @State private var asHargaSaatIniUSD: Decimal? = nil
    @State private var asKursBeliUSD: Decimal = 0
    @State private var asKursSaatIniUSD: Decimal = 0
    @State private var isFetchingUSPrice = false

    // Valas — diisi Phase 3
    @State private var valasMataUang: MataUangValas = .usd
    @State private var valasJumlah: Decimal = 0
    @State private var valasKursBeli: Decimal = 0
    @State private var valasKursSaatIni: Decimal = 0
    @State private var isFetchingKurs = false

    // Emas
    @State private var emasJenis: JenisEmas = .lmAntam
    @State private var emasTahunCetak: Int = Calendar.current.component(.year, from: Date())
    @State private var emasBeratGram: String = ""
    @State private var emasHargaBeliPerGram: Decimal = 0

    // Deposito — diisi Phase 4
    @State private var depoPocketSumber: Pocket? = nil
    @State private var depoNominal: Decimal = 0
    @State private var depoBungaPA: Decimal = 0
    @State private var depoPPH: Decimal = 20
    @State private var depoTenor: Int = 12
    @State private var depoTanggalMulai: Date = Date()
    @State private var depoARO: Bool = false

    // Common
    @State private var catatSbgPengeluaran: Bool = false
    @State private var selectedPocket: Pocket? = nil
    @State private var portofolio: String = ""
    @State private var showPortofolioSuggestions: Bool = false

    @Query private var allAset: [Aset]

    /// Nama portofolio unik dari aset yang sudah ada
    private var existingPortofolioNames: [String] {
        let names = allAset.compactMap { $0.portofolio }.filter { !$0.isEmpty }
        return Array(Set(names)).sorted()
    }

    /// Suggestions filtered by current input
    private var portofolioSuggestions: [String] {
        guard !portofolio.isEmpty else { return existingPortofolioNames }
        return existingPortofolioNames.filter { $0.localizedCaseInsensitiveContains(portofolio) }
    }

    private let rdJenisList = ["Pasar Uang", "Obligasi", "Saham", "Campuran"]
    private let tenorOptions = [1, 3, 6, 12, 24, 36]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        tipeSelectorSection

                        Group {
                            switch selectedTipe {
                            case .saham:     sahamFormSection
                            case .sahamAS:   sahamASFormSection
                            case .reksadana: reksadanaFormSection
                            case .valas:     valasFormSection
                            case .emas:      emasFormSection
                            case .deposito:  depositoFormSection
                            }
                        }

                        if selectedTipe != .deposito {
                            catatPengeluaranSection
                        }

                        portofolioSection

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

    // MARK: - Tipe Selector (2-row grid)

    private var tipeSelectorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TIPE ASET")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(TipeAset.allCases) { tipe in
                    TipeAsetButton(tipe: tipe, isSelected: selectedTipe == tipe)
                        .onTapGesture {
                            guard existingAset == nil else { return }
                            withAnimation(.easeInOut(duration: 0.2)) { selectedTipe = tipe }
                        }
                }
            }
        }
    }

    // MARK: - Saham Form

    private var sahamFormSection: some View {
        FormCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("DETAIL SAHAM").formSectionLabel()

                FormField(label: "NAMA PERUSAHAAN") {
                    TextField("Contoh: Bank Central Asia", text: $sahamNama).styledInput()
                }

                FormField(label: "KODE SAHAM") {
                    HStack {
                        TextField("Contoh: BBCA", text: $sahamKode)
                            .textInputAutocapitalization(.characters)
                            .styledInput()
                        if isFetchingPrice {
                            ProgressView().tint(.white).padding(.trailing, 4)
                        }
                    }
                    if let harga = sahamHargaMarket {
                        Text("Harga pasar: \(harga.idrDecimalFormatted)/lembar")
                            .font(.caption).foregroundStyle(Color(hex: "#22C55E"))
                    }
                }
                .onChange(of: sahamKode) { _, kode in
                    if kode.count >= 4 { Task { await fetchSahamMarketPrice(kode: kode) } }
                }

                FormField(label: "JUMLAH LOT") {
                    TextField("Contoh: 10", text: $sahamLot).keyboardType(.numberPad).styledInput()
                }

                FormField(label: "HARGA BELI/LEMBAR") {
                    HStack(spacing: 8) {
                        Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.subheadline)
                        CurrencyInputField(value: $sahamHargaPerLembar, allowsDecimal: true)
                    }
                }
            }
            .padding(16)
        }
    }

    private func fetchSahamMarketPrice(kode: String) async {
        isFetchingPrice = true
        defer { isFetchingPrice = false }
        if let price = await AsetPriceService.shared.fetchSahamPrice(kode: kode) {
            await MainActor.run { sahamHargaMarket = price }
        }
    }

    // MARK: - Saham AS Form

    private var sahamASFormSection: some View {
        FormCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("DETAIL SAHAM AS").formSectionLabel()

                FormField(label: "NAMA PERUSAHAAN") {
                    TextField("Contoh: NVIDIA Corporation", text: $asNama).styledInput()
                }

                FormField(label: "TICKER") {
                    HStack {
                        TextField("Contoh: NVDA, SPY, SLV", text: $asKode)
                            .textInputAutocapitalization(.characters)
                            .styledInput()
                        if isFetchingUSPrice {
                            ProgressView().tint(.white).padding(.trailing, 4)
                        }
                    }
                    if let harga = asHargaSaatIniUSD {
                        Text("Harga pasar: $\(harga.unitFormatted(2))/share")
                            .font(.caption).foregroundStyle(Color(hex: "#F97316"))
                    }
                }
                .onChange(of: asKode) { _, kode in
                    if kode.count >= 2 { Task { await fetchUSMarketPrice(kode: kode) } }
                }

                FormField(label: "TOTAL INVESTASI (USD)") {
                    HStack(spacing: 8) {
                        Text("$").foregroundStyle(.white.opacity(0.5)).font(.subheadline)
                        CurrencyInputField(value: $asTotalInvestasiUSD, allowsDecimal: true)
                    }
                }

                FormField(label: "HARGA BELI/SHARE (USD)") {
                    HStack(spacing: 8) {
                        Text("$").foregroundStyle(.white.opacity(0.5)).font(.subheadline)
                        CurrencyInputField(value: $asHargaBeliPerShareUSD, allowsDecimal: true)
                    }
                }

                HStack(spacing: 12) {
                    FormField(label: "KURS BELI (IDR/USD)") {
                        HStack(spacing: 4) {
                            Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.caption)
                            CurrencyInputField(value: $asKursBeliUSD, allowsDecimal: true)
                        }
                    }
                    FormField(label: "KURS SAAT INI") {
                        HStack(spacing: 4) {
                            Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.caption)
                            CurrencyInputField(value: $asKursSaatIniUSD, allowsDecimal: true)
                        }
                    }
                }

                // Estimated shares
                if asTotalInvestasiUSD > 0 && asHargaBeliPerShareUSD > 0 {
                    let shares = asTotalInvestasiUSD / asHargaBeliPerShareUSD
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ESTIMASI SHARES").font(.caption).foregroundStyle(.white.opacity(0.4)).tracking(0.8)
                        Text("\(shares.unitFormatted(4)) share")
                            .font(.title3.weight(.bold)).foregroundStyle(.white)
                        if asKursBeliUSD > 0 {
                            Text("≈ \((asTotalInvestasiUSD * asKursBeliUSD).idrDecimalFormatted)")
                                .font(.caption).foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#F97316").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(16)
        }
        .task { await fetchUSKursSaatIni() }
    }

    private func fetchUSMarketPrice(kode: String) async {
        isFetchingUSPrice = true
        defer { isFetchingUSPrice = false }
        if let price = await AsetPriceService.shared.fetchUSStockPrice(ticker: kode) {
            await MainActor.run {
                asHargaSaatIniUSD = price
                asHargaBeliPerShareUSD = price
            }
        }
    }

    private func fetchUSKursSaatIni() async {
        if let kurs = await AsetPriceService.shared.fetchKursValas(.usd) {
            await MainActor.run {
                asKursSaatIniUSD = kurs
                if asKursBeliUSD == 0 { asKursBeliUSD = kurs }
            }
        }
    }

    // MARK: - Reksadana Form

    private var reksadanaFormSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // --- Search card (jenis chips + search input) ---
            FormCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("DETAIL REKSADANA").formSectionLabel()

                    // Jenis filter chips
                    FormField(label: "JENIS") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(rdJenisList, id: \.self) { jenis in
                                    ChipButton(label: jenis, isSelected: rdJenis == jenis, color: Color(hex: "#3B82F6")) {
                                        rdJenis = rdJenis == jenis ? "" : jenis
                                        rdSearchResults = ReksadanaSearchService.shared.search(rdSearchQuery, jenis: rdJenis.isEmpty ? nil : rdJenis)
                                        rdShowResults = !rdSearchResults.isEmpty && !rdSearchQuery.isEmpty
                                    }
                                }
                            }
                        }
                    }

                    // Search field
                    FormField(label: "CARI PRODUK") {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.white.opacity(0.4))
                                .font(.subheadline)
                            TextField("Ketik nama atau manajer investasi...", text: $rdSearchQuery)
                                .foregroundStyle(.white)
                                .autocorrectionDisabled()
                            if !rdSearchQuery.isEmpty {
                                Button {
                                    rdSearchQuery = ""
                                    rdNama = ""
                                    rdJenis = ""
                                    rdShowResults = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onChange(of: rdSearchQuery) { _, query in
                            rdNama = query.trimmingCharacters(in: .whitespaces)
                            rdSearchResults = ReksadanaSearchService.shared.search(query, jenis: rdJenis.isEmpty ? nil : rdJenis)
                            rdShowResults = !rdSearchResults.isEmpty && !query.isEmpty
                        }
                    }

                    // Selected fund display (when nama filled but not searching)
                    if !rdNama.isEmpty && !rdShowResults {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(hex: "#3B82F6"))
                                .font(.caption)
                            Text(rdNama)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                            Spacer()
                            if !rdJenis.isEmpty {
                                Text(rdJenis)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(jenisColor(rdJenis))
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(jenisColor(rdJenis).opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(10)
                        .background(Color(hex: "#3B82F6").opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(16)
            }

            // --- Featured / Search results (OUTSIDE FormCard agar tidak ter-clip) ---
            if rdShowResults {
                // Search results
                rdSearchResultsList
            } else if rdSearchQuery.isEmpty && rdNama.isEmpty {
                // Featured suggestions
                let featured = ReksadanaSearchService.shared.featuredFunds
                if !featured.isEmpty {
                    rdFeaturedList(featured)
                }
            }

            // --- Investasi detail card ---
            FormCard {
                VStack(alignment: .leading, spacing: 14) {
                    FormField(label: "TOTAL INVESTASI") {
                        HStack(spacing: 8) {
                            Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.subheadline)
                            CurrencyInputField(value: $rdTotalInvestasi, allowsDecimal: true)
                        }
                    }

                    FormField(label: "NAV SAAT BELI/UNIT") {
                        HStack(spacing: 8) {
                            Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.subheadline)
                            CurrencyInputField(value: $rdHargaBeliPerUnit, allowsDecimal: true)
                        }
                    }

                    FormField(label: "NAV SAAT INI/UNIT") {
                        HStack(spacing: 8) {
                            Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.subheadline)
                            CurrencyInputField(value: $rdNavSaatIni, allowsDecimal: true)
                        }
                    }

                    // Estimated units
                    if rdTotalInvestasi > 0 && rdHargaBeliPerUnit > 0 {
                        let units = rdTotalInvestasi / rdHargaBeliPerUnit
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ESTIMASI UNIT").font(.caption).foregroundStyle(.white.opacity(0.4)).tracking(0.8)
                            Text("\(units.unitFormatted(4)) unit")
                                .font(.title3.weight(.bold)).foregroundStyle(.white)
                            Text("Total investasi / NAV beli per unit")
                                .font(.caption).foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "#3B82F6").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Reksadana Search Results List

    @ViewBuilder
    private var rdSearchResultsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HASIL PENCARIAN (\(rdSearchResults.count))")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(1)
            VStack(spacing: 0) {
                ForEach(rdSearchResults) { item in
                    Button {
                        rdNama = item.nama
                        rdJenis = item.jenis
                        rdSearchQuery = item.nama
                        rdShowResults = false
                    } label: {
                        rdFundRow(item)
                    }
                    if item.id != rdSearchResults.last?.id {
                        Divider().background(Color.white.opacity(0.06))
                    }
                }
            }
            .background(Color(hex: "#1A1A1A"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    @ViewBuilder
    private func rdFeaturedList(_ featured: [ReksadanaItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("POPULER")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(1)
            VStack(spacing: 0) {
                ForEach(featured) { item in
                    Button {
                        rdJenis = item.jenis
                        rdSearchQuery = item.nama
                        Task { @MainActor in rdShowResults = false }
                    } label: {
                        rdFundRow(item)
                    }
                    if item.id != featured.last?.id {
                        Divider().background(Color.white.opacity(0.06))
                    }
                }
            }
            .background(Color(hex: "#1A1A1A"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    @ViewBuilder
    private func rdFundRow(_ item: ReksadanaItem) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.nama)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Text(item.manajer)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Text(item.jenis)
                .font(.caption2.weight(.bold))
                .foregroundStyle(jenisColor(item.jenis))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(jenisColor(item.jenis).opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func jenisColor(_ jenis: String) -> Color {
        switch jenis {
        case "Pasar Uang": return Color(hex: "#22C55E")
        case "Obligasi":   return Color(hex: "#F59E0B")
        case "Saham":      return Color(hex: "#3B82F6")
        case "Campuran":   return Color(hex: "#A78BFA")
        default:           return Color.white.opacity(0.5)
        }
    }

    // MARK: - Valas Form (stub — Phase 3 akan flesh out)

    private var valasFormSection: some View {
        FormCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("DETAIL VALAS").formSectionLabel()

                FormField(label: "MATA UANG") {
                    HStack(spacing: 0) {
                        ForEach(MataUangValas.allCases) { mu in
                            Button {
                                valasMataUang = mu
                                Task { await fetchKursSaatIni(mu) }
                            } label: {
                                VStack(spacing: 2) {
                                    Text(mu.flag).font(.title3)
                                    Text(mu.rawValue).font(.caption2.weight(.bold))
                                        .foregroundStyle(valasMataUang == mu ? .black : .white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(valasMataUang == mu ? Color(hex: "#06B6D4") : Color.clear)
                            }
                        }
                    }
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                HStack(spacing: 12) {
                    FormField(label: "KURS SAAT INI") {
                        HStack(spacing: 4) {
                            Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.caption)
                            CurrencyInputField(value: $valasKursSaatIni, allowsDecimal: true)
                            if isFetchingKurs {
                                ProgressView().tint(.white).scaleEffect(0.7)
                            }
                        }
                    }
                    FormField(label: "KURS BELI") {
                        HStack(spacing: 4) {
                            Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.caption)
                            CurrencyInputField(value: $valasKursBeli, allowsDecimal: true)
                        }
                    }
                }

                FormField(label: "JUMLAH \(valasMataUang.rawValue)") {
                    CurrencyInputField(value: $valasJumlah, allowsDecimal: true)
                }

                if valasJumlah > 0 && valasKursBeli > 0 {
                    let totalIDR = valasJumlah * valasKursBeli
                    Text("Total IDR: \(totalIDR.idrDecimalFormatted)")
                        .font(.caption).foregroundStyle(Color(hex: "#06B6D4"))
                }
            }
            .padding(16)
        }
        .task { await fetchKursSaatIni(valasMataUang) }
    }

    private func fetchKursSaatIni(_ mata: MataUangValas) async {
        isFetchingKurs = true
        defer { isFetchingKurs = false }
        if let kurs = await AsetPriceService.shared.fetchKursValas(mata) {
            await MainActor.run {
                valasKursSaatIni = kurs
                if valasKursBeli == 0 { valasKursBeli = kurs }
            }
        }
    }

    // MARK: - Emas Form

    private var emasFormSection: some View {
        FormCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("DETAIL EMAS").formSectionLabel()

                FormField(label: "JENIS EMAS") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(JenisEmas.allCases) { jenis in
                                ChipButton(label: jenis.displayName, isSelected: emasJenis == jenis, color: Color(hex: "#EAB308")) {
                                    emasJenis = jenis
                                }
                            }
                        }.padding(.horizontal, 1)
                    }
                }

                // Tahun cetak hanya untuk emas fisik
                if !emasJenis.isDigital {
                    FormField(label: "TAHUN CETAK") {
                        let years = Array(2010...Calendar.current.component(.year, from: Date()))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(years.reversed(), id: \.self) { year in
                                    ChipButton(label: "\(year)", isSelected: emasTahunCetak == year, color: Color(hex: "#EAB308")) {
                                        emasTahunCetak = year
                                    }
                                }
                            }.padding(.horizontal, 1)
                        }
                    }
                }

                FormField(label: "BERAT (GRAM)") {
                    TextField("Contoh: 1,5", text: $emasBeratGram).keyboardType(.decimalPad).styledInput()
                }

                FormField(label: "HARGA BELI/GRAM") {
                    HStack(spacing: 8) {
                        Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.subheadline)
                        CurrencyInputField(value: $emasHargaBeliPerGram, allowsDecimal: true)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Deposito Form

    private var depositoFormSection: some View {
        VStack(spacing: 16) {
            FormCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("DETAIL DEPOSITO").formSectionLabel()

                    FormField(label: "POCKET SUMBER") {
                        PocketChipPicker(
                            pockets: allPockets.filter { $0.isAktif && $0.kelompokPocket == .biasa },
                            selected: $depoPocketSumber
                        )
                    }

                    FormField(label: "NOMINAL / POKOK") {
                        HStack(spacing: 8) {
                            Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.subheadline)
                            CurrencyInputField(value: $depoNominal)
                        }
                    }

                    HStack(spacing: 12) {
                        FormField(label: "BUNGA P.A. (%)") {
                            CurrencyInputField(value: $depoBungaPA, allowsDecimal: true)
                        }
                        FormField(label: "PPH FINAL (%)") {
                            CurrencyInputField(value: $depoPPH, allowsDecimal: true)
                        }
                    }

                    FormField(label: "TENOR") {
                        Picker("Tenor", selection: $depoTenor) {
                            ForEach(tenorOptions, id: \.self) { bulan in
                                Text("\(bulan) Bulan").tag(bulan)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .tint(.white)
                    }

                    FormField(label: "TANGGAL MULAI") {
                        DatePicker("", selection: $depoTanggalMulai, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .colorScheme(.dark)
                            .labelsHidden()
                    }

                    // Jatuh tempo (read-only)
                    let jatuhTempo = Calendar.current.date(byAdding: .month, value: depoTenor, to: depoTanggalMulai) ?? depoTanggalMulai
                    HStack {
                        Text("Jatuh Tempo").font(.subheadline).foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Text(jatuhTempo.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Toggle(isOn: $depoARO) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto Roll Over (ARO)")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text("Perpanjang otomatis saat jatuh tempo")
                                .font(.caption).foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .tint(Color(hex: "#A78BFA"))
                }
                .padding(16)
            }

            // Catat Sebagai Pengeluaran untuk deposito
            FormCard {
                Toggle(isOn: $catatSbgPengeluaran) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Catat Sebagai Pengeluaran")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Text("Otomatis memotong saldo pocket sumber")
                            .font(.caption).foregroundStyle(.white.opacity(0.5))
                    }
                }
                .tint(Color(hex: "#A78BFA"))
                .padding(16)
            }
        }
    }

    // MARK: - Catat Pengeluaran (non-deposito)

    private var catatPengeluaranSection: some View {
        FormCard {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $catatSbgPengeluaran) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Catat Sebagai Pengeluaran")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Text("Otomatis memotong saldo kas kamu")
                            .font(.caption).foregroundStyle(.white.opacity(0.5))
                    }
                }
                .tint(selectedTipe.color)

                if catatSbgPengeluaran {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PILIH POCKET SUMBER")
                            .font(.caption).foregroundStyle(.white.opacity(0.5)).tracking(1)
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

    // MARK: - Portfolio / Bucket Section

    private var portofolioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FormCard {
                VStack(alignment: .leading, spacing: 10) {
                    FormField(label: "PORTOFOLIO / BUCKET (OPSIONAL)") {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(Color(hex: "#A78BFA").opacity(0.7))
                                .font(.subheadline)
                            TextField("Contoh: Dana Pensiun, Nabung Nikah...", text: $portofolio)
                                .foregroundStyle(.white)
                                .autocorrectionDisabled()
                                .onChange(of: portofolio) { _, _ in
                                    showPortofolioSuggestions = true
                                }
                            if !portofolio.isEmpty {
                                Button {
                                    portofolio = ""
                                    showPortofolioSuggestions = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    Text("Kelompokkan beberapa aset ke dalam satu tujuan investasi (mis. Dana Pensiun).")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(16)
            }

            // Suggestions — outside FormCard so they aren't clipped
            if showPortofolioSuggestions && !portofolioSuggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(portofolioSuggestions, id: \.self) { name in
                        Button {
                            portofolio = name
                            showPortofolioSuggestions = false
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "folder.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color(hex: "#A78BFA"))
                                Text(name)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "arrow.up.left")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        if name != portofolioSuggestions.last {
                            Divider().background(Color.white.opacity(0.06))
                        }
                    }
                }
                .background(Color(hex: "#1A1A1A"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button(action: saveAset) {
            Text(existingAset == nil ? "Tambah Aset" : "Simpan Perubahan")
                .font(.headline).foregroundStyle(.black)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(selectedTipe.color)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!isFormValid)
        .opacity(isFormValid ? 1 : 0.5)
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        switch selectedTipe {
        case .saham:     return !sahamNama.isEmpty && !sahamLot.isEmpty && sahamHargaPerLembar > 0
        case .sahamAS:   return !asKode.isEmpty && asTotalInvestasiUSD > 0 && asHargaBeliPerShareUSD > 0 && asKursBeliUSD > 0
        case .reksadana: return !rdNama.isEmpty && rdTotalInvestasi > 0 && rdHargaBeliPerUnit > 0
        case .valas:     return valasJumlah > 0 && valasKursBeli > 0
        case .emas:      return !emasBeratGram.isEmpty && emasHargaBeliPerGram > 0
        case .deposito:  return depoNominal > 0 && depoBungaPA > 0
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

        aset.tipe = selectedTipe

        switch selectedTipe {
        case .saham:
            aset.nama = sahamNama
            aset.kode = sahamKode.uppercased()
            aset.lot = Decimal(string: sahamLot) ?? 0
            aset.hargaPerLembar = sahamHargaPerLembar
            aset.nilaiSaatIni = (Decimal(string: sahamLot) ?? 0) * sahamHargaPerLembar * 100

        case .sahamAS:
            aset.nama = asNama.isEmpty ? asKode.uppercased() : asNama
            aset.kode = asKode.uppercased()
            aset.totalInvestasiUSD = asTotalInvestasiUSD
            aset.hargaBeliPerShareUSD = asHargaBeliPerShareUSD
            aset.hargaSaatIniUSD = asHargaSaatIniUSD ?? asHargaBeliPerShareUSD
            aset.kursBeliUSD = asKursBeliUSD
            aset.kursSaatIniUSD = asKursSaatIniUSD > 0 ? asKursSaatIniUSD : asKursBeliUSD
            // Initial nilai = total investasi * kurs (price service will update with live price)
            let kursInit = asKursSaatIniUSD > 0 ? asKursSaatIniUSD : asKursBeliUSD
            aset.nilaiSaatIni = asTotalInvestasiUSD * kursInit

        case .reksadana:
            aset.nama = rdNama
            aset.kode = nil
            aset.jenisReksadana = rdJenis.isEmpty ? nil : rdJenis
            aset.totalInvestasiReksadana = rdTotalInvestasi
            aset.hargaBeliPerUnit = rdHargaBeliPerUnit > 0 ? rdHargaBeliPerUnit : nil
            aset.navSaatIni = rdNavSaatIni > 0 ? rdNavSaatIni : nil
            let units = rdHargaBeliPerUnit > 0 ? rdTotalInvestasi / rdHargaBeliPerUnit : 0
            aset.nilaiSaatIni = rdNavSaatIni > 0 ? units * rdNavSaatIni : rdTotalInvestasi

        case .valas:
            aset.nama = "\(valasMataUang.flag) \(valasMataUang.rawValue)"
            aset.mataUangValas = valasMataUang
            aset.jumlahValas = valasJumlah
            aset.kursBeliPerUnit = valasKursBeli
            aset.kursSaatIni = valasKursSaatIni > 0 ? valasKursSaatIni : valasKursBeli
            aset.nilaiSaatIni = valasJumlah * (valasKursSaatIni > 0 ? valasKursSaatIni : valasKursBeli)

        case .emas:
            let berat = Decimal(string: emasBeratGram.replacingOccurrences(of: ",", with: ".")) ?? 0
            aset.nama = "\(emasJenis.displayName) \(emasBeratGram)g"
            aset.jenisEmas = emasJenis
            aset.tahunCetak = emasJenis.isDigital ? nil : emasTahunCetak
            aset.beratGram = berat
            aset.hargaBeliPerGram = emasHargaBeliPerGram
            aset.nilaiSaatIni = berat * emasHargaBeliPerGram

        case .deposito:
            let bungaInt = NSDecimalNumber(decimal: depoBungaPA).intValue
            aset.nama = depoPocketSumber.map { "\($0.nama) \(bungaInt)%" } ?? "Deposito \(bungaInt)%"
            aset.nominalDeposito = depoNominal
            aset.bungaPA = depoBungaPA
            aset.pphFinal = depoPPH
            aset.tenorBulan = depoTenor
            aset.tanggalMulaiDeposito = depoTanggalMulai
            aset.autoRollOver = depoARO
            aset.nilaiSaatIni = depoNominal
            aset.pocketSumber = depoPocketSumber
        }

        // Portofolio / bucket
        let portofolioTrimmed = portofolio.trimmingCharacters(in: .whitespaces)
        aset.portofolio = portofolioTrimmed.isEmpty ? nil : portofolioTrimmed

        // Catat pengeluaran untuk non-deposito
        if selectedTipe != .deposito {
            aset.catatSbgPengeluaran = catatSbgPengeluaran
            aset.pocketSumber = catatSbgPengeluaran ? selectedPocket : nil
        } else {
            aset.catatSbgPengeluaran = catatSbgPengeluaran
        }

        if catatSbgPengeluaran, existingAset == nil {
            let pocket = selectedTipe == .deposito ? depoPocketSumber : selectedPocket
            if let pocket {
                let modalValue = aset.modal
                pocket.saldo -= modalValue
                let transaksi = Transaksi(
                    tanggal: depoTanggalMulai,
                    nominal: modalValue,
                    tipe: .pengeluaran,
                    subTipe: .normal,
                    pocket: pocket,
                    catatan: "Aset: \(aset.nama)"
                )
                modelContext.insert(transaksi)
            }
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

        case .sahamAS:
            asNama = a.nama
            asKode = a.kode ?? ""
            asTotalInvestasiUSD = a.totalInvestasiUSD ?? 0
            asHargaBeliPerShareUSD = a.hargaBeliPerShareUSD ?? 0
            asHargaSaatIniUSD = a.hargaSaatIniUSD
            asKursBeliUSD = a.kursBeliUSD ?? 0
            asKursSaatIniUSD = a.kursSaatIniUSD ?? 0

        case .reksadana:
            rdNama = a.nama
            rdJenis = a.jenisReksadana ?? ""
            rdTotalInvestasi = a.totalInvestasiReksadana ?? 0
            rdHargaBeliPerUnit = a.hargaBeliPerUnit ?? 0
            rdNavSaatIni = a.navSaatIni ?? 0
            rdSearchQuery = a.nama

        case .valas:
            valasMataUang = a.mataUangValas ?? .usd
            valasJumlah = a.jumlahValas ?? 0
            valasKursBeli = a.kursBeliPerUnit ?? 0
            valasKursSaatIni = a.kursSaatIni ?? 0

        case .emas:
            emasJenis = a.jenisEmas ?? .lmAntam
            emasTahunCetak = a.tahunCetak ?? Calendar.current.component(.year, from: Date())
            emasBeratGram = a.beratGram.map { String(format: "%.2f", Double(truncating: $0 as NSDecimalNumber)) } ?? ""
            emasHargaBeliPerGram = a.hargaBeliPerGram ?? 0

        case .deposito:
            depoNominal = a.nominalDeposito ?? 0
            depoBungaPA = a.bungaPA ?? 0
            depoPPH = a.pphFinal ?? 20
            depoTenor = a.tenorBulan ?? 12
            depoTanggalMulai = a.tanggalMulaiDeposito ?? Date()
            depoARO = a.autoRollOver
            depoPocketSumber = a.pocketSumber
        }

        catatSbgPengeluaran = a.catatSbgPengeluaran
        selectedPocket = a.pocketSumber
        portofolio = a.portofolio ?? ""
    }

    // MARK: - Helpers

    private var currentNama: String {
        switch selectedTipe {
        case .saham:     return sahamNama
        case .sahamAS:   return asNama.isEmpty ? asKode.uppercased() : asNama
        case .reksadana: return rdNama
        case .valas:     return "\(valasMataUang.flag) \(valasMataUang.rawValue)"
        case .emas:      return "\(emasJenis.displayName) \(emasBeratGram)g"
        case .deposito:  return "Deposito"
        }
    }

    private var currentKode: String? {
        switch selectedTipe {
        case .saham:   return sahamKode.isEmpty ? nil : sahamKode.uppercased()
        case .sahamAS: return asKode.isEmpty ? nil : asKode.uppercased()
        default:       return nil
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
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? tipe.color.opacity(0.2) : Color.white.opacity(0.06))
                    .frame(height: 44)
                Image(systemName: tipe.iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? tipe.color : .white.opacity(0.4))
            }
            Text(tipe.displayName)
                .font(.caption2.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? tipe.color : .white.opacity(0.5))
                .lineLimit(1)
        }
        .padding(.vertical, 6)
        .background(isSelected ? tipe.color.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? tipe.color.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Shared Components

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
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(isSelected ? color : Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
    }
}

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
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.5)).tracking(0.8)
            content
        }
    }
}

extension View {
    func styledInput() -> some View {
        self.foregroundStyle(.white).padding(12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

extension Text {
    func formSectionLabel() -> some View {
        self.font(.caption).foregroundStyle(.white.opacity(0.5)).tracking(1)
    }
}
