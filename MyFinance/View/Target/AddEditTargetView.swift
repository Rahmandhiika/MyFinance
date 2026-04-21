import SwiftUI
import SwiftData
import PhotosUI

struct AddEditTargetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query var allPockets: [Pocket]

    private let editingTarget: Target?

    // MARK: - Target state

    @State private var nama: String = ""
    @State private var targetNominal: Decimal = 0
    @State private var saldoAwal: Decimal = 0
    @State private var saldoTerkumpulEdit: Decimal = 0
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Date().addingTimeInterval(60 * 60 * 24 * 30)
    @State private var selectedIkon: String = "target"
    @State private var selectedWarna: String = "#22C55E"
    @State private var ikonCustom: String = ""
    @State private var jenisTarget: JenisTarget = .biasa
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var fotoData: Data? = nil

    // MARK: - Investasi aset state

    @State private var invTipe: TipeAset = .reksadana
    @State private var showEditLinkedAset = false

    // Reksadana
    @State private var rdNama: String = ""
    @State private var rdJenis: String = ""
    @State private var rdTotalInvestasi: Decimal = 0
    @State private var rdHargaBeliPerUnit: Decimal = 0
    @State private var rdNavSaatIni: Decimal = 0
    @State private var rdSearchQuery: String = ""
    @State private var rdSearchResults: [ReksadanaItem] = []
    @State private var rdShowResults: Bool = false

    // Deposito
    @State private var depoNominal: Decimal = 0
    @State private var depoBunga: Decimal = 0
    @State private var depoPPH: Decimal = 20
    @State private var depoTenor: Int = 12
    @State private var depoTanggal: Date = Date()
    @State private var depoARO: Bool = false
    @State private var depoPocket: Pocket? = nil

    // Saham IDN
    @State private var sahamNama: String = ""
    @State private var sahamKode: String = ""
    @State private var sahamLot: String = ""
    @State private var sahamHarga: Decimal = 0
    @State private var sahamHargaMarket: Decimal? = nil
    @State private var isFetchingPrice = false

    // Saham AS
    @State private var asNama: String = ""
    @State private var asKode: String = ""
    @State private var asTotalUSD: Decimal = 0
    @State private var asHargaBeli: Decimal = 0
    @State private var asHargaSaatIni: Decimal? = nil
    @State private var asKursBeli: Decimal = 0
    @State private var asKursSaatIni: Decimal = 0
    @State private var isFetchingUSPrice = false

    // Valas
    @State private var valasMata: MataUangValas = .usd
    @State private var valasJumlah: Decimal = 0
    @State private var valasKursBeli: Decimal = 0
    @State private var valasKursSaatIni: Decimal = 0
    @State private var isFetchingKurs = false

    // Emas
    @State private var emasJenis: JenisEmas = .lmAntam
    @State private var emasTahun: Int = Calendar.current.component(.year, from: Date())
    @State private var emasBerat: String = ""
    @State private var emasHarga: Decimal = 0

    private let rdJenisList = ["Pasar Uang", "Obligasi", "Saham", "Campuran"]
    private let tenorOptions = [1, 3, 6, 12, 24, 36]

    init(target: Target? = nil) {
        self.editingTarget = target
    }

    private var isEditing: Bool { editingTarget != nil }
    private var selectedColor: Color { Color(hex: selectedWarna) }
    private var isInvestasi: Bool { jenisTarget == .investasi }

    private var canSave: Bool {
        guard !nama.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if isInvestasi && !isEditing {
            return isAsetFormValid
        }
        return true
    }

    private var isAsetFormValid: Bool {
        switch invTipe {
        case .reksadana: return !rdNama.isEmpty && rdTotalInvestasi > 0 && rdHargaBeliPerUnit > 0
        case .deposito:  return depoNominal > 0 && depoBunga > 0
        case .saham:     return !sahamNama.isEmpty && !sahamLot.isEmpty && sahamHarga > 0
        case .sahamAS:   return !asKode.isEmpty && asTotalUSD > 0 && asHargaBeli > 0 && asKursBeli > 0
        case .valas:     return valasJumlah > 0 && valasKursBeli > 0
        case .emas:      return !emasBerat.isEmpty && emasHarga > 0
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        iconPreview

                        formSection(label: "NAMA") {
                            TextField("Nama target...", text: $nama)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        formSection(label: "BUTUH DANA BERAPA? (OPSIONAL)") {
                            CurrencyInputField(value: $targetNominal)
                        }

                        // Tipe — hanya saat buat baru
                        if !isEditing {
                            jenisTargetSelector
                        }

                        // Konten berdasarkan tipe
                        if isInvestasi {
                            if isEditing {
                                editingInvestasiInfo
                            } else {
                                investasiForm
                            }
                        } else {
                            biasaExtraFields
                        }

                        deadlineSection
                        ikonWarnaSection

                        ctaButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(isEditing ? "Edit Target" : "Bikin Target Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }.foregroundStyle(.gray)
                }
            }
            .onAppear { populateIfEditing() }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showEditLinkedAset) {
            if let aset = editingTarget?.linkedAset {
                AddEditAsetView(existingAset: aset, mode: .edit)
            }
        }
    }

    // MARK: - Icon / Photo Preview

    private var iconPreview: some View {
        VStack(spacing: 12) {
            // Foto background preview atau icon
            ZStack {
                if let data = fotoData, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selectedColor.opacity(0.4), lineWidth: 1.5)
                        )
                } else {
                    ZStack {
                        Circle()
                            .fill(selectedColor.opacity(0.2))
                            .frame(width: 72, height: 72)
                        if !ikonCustom.isEmpty {
                            Text(ikonCustom).font(.system(size: 32))
                        } else {
                            Image(systemName: selectedIkon)
                                .font(.system(size: 28))
                                .foregroundStyle(selectedColor)
                        }
                    }
                }
            }

            // Photo picker button
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: fotoData == nil ? "photo.badge.plus" : "photo.badge.checkmark")
                        .font(.caption)
                    Text(fotoData == nil ? "Tambah Foto Latar" : "Ganti Foto")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(fotoData == nil ? .gray : selectedColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.07))
                .clipShape(Capsule())
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        await MainActor.run { fotoData = data }
                    }
                }
            }

            if fotoData != nil {
                Button {
                    fotoData = nil
                    selectedPhoto = nil
                } label: {
                    Text("Hapus Foto")
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.7))
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Jenis Target Selector

    private var jenisTargetSelector: some View {
        formSection(label: "JENIS TABUNGAN") {
            HStack(spacing: 10) {
                ForEach(JenisTarget.allCases) { jenis in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { jenisTarget = jenis }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: jenis.icon)
                                .font(.subheadline)
                            Text(jenis.displayName)
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(jenisTarget == jenis ? .black : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(jenisTarget == jenis ? selectedColor : Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    // MARK: - Biasa extra fields

    @ViewBuilder
    private var biasaExtraFields: some View {
        formSection(label: "UDAH ADA BERAPA? (OPSIONAL)") {
            HStack(spacing: 8) {
                Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.subheadline)
                CurrencyInputField(value: $saldoAwal)
            }
        }
        if saldoAwal > 0 {
            Text("Dicatat sebagai saldo awal, tidak dihitung sebagai tabungan bulan ini.")
                .font(.caption).foregroundStyle(.white.opacity(0.35))
                .padding(.top, -12)
        }
        if isEditing {
            formSection(label: "SALDO TERKUMPUL SAAT INI") {
                CurrencyInputField(value: $saldoTerkumpulEdit)
            }
            Text("Perubahan saldo tidak dicatat sebagai transaksi, hanya penyesuaian manual.")
                .font(.caption).foregroundStyle(.white.opacity(0.35))
                .padding(.top, -12)
        }
    }

    // MARK: - Investasi: info saat edit

    private var editingInvestasiInfo: some View {
        VStack(spacing: 12) {
            if let aset = editingTarget?.linkedAset {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(aset.tipe.color.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: aset.tipe.iconName)
                            .font(.system(size: 14))
                            .foregroundStyle(aset.tipe.color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(aset.nama)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(aset.tipe.displayName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Text(aset.nilaiEfektif.idrDecimalFormatted)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(aset.tipe.color)
                }
                .padding(14)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    showEditLinkedAset = true
                } label: {
                    Label("Edit Investasi", systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(aset.tipe.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(aset.tipe.color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Investasi form (new)

    private var investasiForm: some View {
        VStack(spacing: 20) {
            // Tipe aset picker
            formSection(label: "TIPE INVESTASI") {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                    spacing: 8
                ) {
                    ForEach(TipeAset.allCases) { tipe in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { invTipe = tipe }
                        } label: {
                            VStack(spacing: 5) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(invTipe == tipe ? tipe.color.opacity(0.2) : Color.white.opacity(0.06))
                                        .frame(height: 38)
                                    Image(systemName: tipe.iconName)
                                        .font(.system(size: 15))
                                        .foregroundStyle(invTipe == tipe ? tipe.color : .white.opacity(0.4))
                                }
                                Text(tipe.displayName)
                                    .font(.caption2.weight(invTipe == tipe ? .bold : .regular))
                                    .foregroundStyle(invTipe == tipe ? tipe.color : .white.opacity(0.5))
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 4)
                            .background(invTipe == tipe ? tipe.color.opacity(0.06) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(invTipe == tipe ? tipe.color.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }
                }
            }

            // Form berdasarkan tipe
            asetFormForType
        }
    }

    @ViewBuilder
    private var asetFormForType: some View {
        switch invTipe {
        case .reksadana: reksadanaForm
        case .deposito:  depositoForm
        case .saham:     sahamForm
        case .sahamAS:   sahamASForm
        case .valas:     valasForm
        case .emas:      emasForm
        }
    }

    // MARK: - Reksadana Form

    private var reksadanaForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            // --- Card 1: jenis chips + search field ---
            investasiCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("DETAIL REKSADANA").invLabel()

                    FormField(label: "JENIS") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(rdJenisList, id: \.self) { jenis in
                                    ChipButton(label: jenis, isSelected: rdJenis == jenis, color: Color(hex: "#3B82F6")) {
                                        rdJenis = rdJenis == jenis ? "" : jenis
                                        rdSearchResults = ReksadanaSearchService.shared.search(rdSearchQuery, jenis: rdJenis.isEmpty ? nil : rdJenis)
                                        rdShowResults = !rdSearchResults.isEmpty
                                    }
                                }
                            }
                        }
                    }

                    FormField(label: "CARI PRODUK") {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.4)).font(.subheadline)
                            TextField("Ketik nama atau manajer investasi...", text: $rdSearchQuery)
                                .foregroundStyle(.white)
                                .autocorrectionDisabled()
                            if !rdSearchQuery.isEmpty {
                                Button {
                                    rdSearchQuery = ""; rdNama = ""; rdJenis = ""; rdShowResults = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.4))
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

                    if !rdNama.isEmpty && !rdShowResults {
                        rdSelectedBadge
                    }
                }
                .padding(16)
            }

            // --- Featured / Search results OUTSIDE investasiCard (no clipShape clipping) ---
            if rdShowResults {
                rdDropdown
            } else if rdSearchQuery.isEmpty && rdNama.isEmpty {
                rdFeaturedList
            }

            // --- Card 2: investasi detail fields ---
            investasiCard {
                VStack(alignment: .leading, spacing: 14) {
                    FormField(label: "TOTAL INVESTASI") {
                        HStack(spacing: 8) {
                            Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.subheadline)
                            CurrencyInputField(value: $rdTotalInvestasi)
                        }
                    }
                    FormField(label: "NAV SAAT BELI/UNIT") {
                        HStack(spacing: 8) {
                            Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.subheadline)
                            CurrencyInputField(value: $rdHargaBeliPerUnit)
                        }
                    }
                    FormField(label: "NAV SAAT INI/UNIT") {
                        HStack(spacing: 8) {
                            Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.subheadline)
                            CurrencyInputField(value: $rdNavSaatIni)
                        }
                    }
                    if rdTotalInvestasi > 0 && rdHargaBeliPerUnit > 0 {
                        let units = rdTotalInvestasi / rdHargaBeliPerUnit
                        estimasiBox(label: "ESTIMASI UNIT", value: "\(units.unitFormatted(4)) unit", note: "Total / NAV beli")
                    }
                }
                .padding(16)
            }
        }
    }

    private var rdFeaturedList: some View {
        let featured = ReksadanaSearchService.shared.featuredFunds
        return Group {
            if !featured.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("POPULER").font(.caption2.weight(.bold)).foregroundStyle(.white.opacity(0.35)).tracking(1).padding(.top, 6)
                    VStack(spacing: 0) {
                        ForEach(featured) { item in
                            Button {
                                rdJenis = item.jenis; rdSearchQuery = item.nama
                                Task { @MainActor in rdShowResults = false }
                            } label: {
                                rdItemRow(item)
                            }
                            if item.id != featured.last?.id { Divider().background(Color.white.opacity(0.06)) }
                        }
                    }
                    .background(Color(hex: "#1A1A1A"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
            }
        }
    }

    private var rdDropdown: some View {
        VStack(spacing: 0) {
            ForEach(rdSearchResults) { item in
                Button {
                    rdNama = item.nama; rdJenis = item.jenis; rdSearchQuery = item.nama; rdShowResults = false
                } label: {
                    rdItemRow(item)
                }
                if item.id != rdSearchResults.last?.id { Divider().background(Color.white.opacity(0.06)) }
            }
        }
        .background(Color(hex: "#1A1A1A"))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func rdItemRow(_ item: ReksadanaItem) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.nama).font(.subheadline.weight(.medium)).foregroundStyle(.white).multilineTextAlignment(.leading)
                Text(item.manajer).font(.caption).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Text(item.jenis).font(.caption2.weight(.bold)).foregroundStyle(jenisColor(item.jenis))
                .padding(.horizontal, 8).padding(.vertical, 3).background(jenisColor(item.jenis).opacity(0.15)).clipShape(Capsule())
        }
        .padding(.horizontal, 12).padding(.vertical, 10).contentShape(Rectangle())
    }

    private var rdSelectedBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: "#3B82F6")).font(.caption)
            Text(rdNama).font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
            Spacer()
            if !rdJenis.isEmpty {
                Text(rdJenis).font(.caption2.weight(.bold)).foregroundStyle(jenisColor(rdJenis))
                    .padding(.horizontal, 8).padding(.vertical, 3).background(jenisColor(rdJenis).opacity(0.15)).clipShape(Capsule())
            }
        }
        .padding(10).background(Color(hex: "#3B82F6").opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func jenisColor(_ jenis: String) -> Color {
        switch jenis {
        case "Pasar Uang": return Color(hex: "#22C55E")
        case "Obligasi":   return Color(hex: "#F59E0B")
        case "Saham":      return Color(hex: "#3B82F6")
        case "Campuran":   return Color(hex: "#A78BFA")
        default:           return .white.opacity(0.5)
        }
    }

    // MARK: - Deposito Form

    private var depositoForm: some View {
        investasiCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("DETAIL DEPOSITO").invLabel()

                FormField(label: "POCKET SUMBER") {
                    PocketChipPicker(pockets: allPockets.filter { $0.isAktif && $0.kelompokPocket == .biasa }, selected: $depoPocket)
                }
                FormField(label: "NOMINAL / POKOK") {
                    HStack(spacing: 8) {
                        Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.subheadline)
                        CurrencyInputField(value: $depoNominal)
                    }
                }
                HStack(spacing: 12) {
                    FormField(label: "BUNGA P.A. (%)") { CurrencyInputField(value: $depoBunga) }
                    FormField(label: "PPH FINAL (%)") { CurrencyInputField(value: $depoPPH) }
                }
                FormField(label: "TENOR") {
                    Picker("Tenor", selection: $depoTenor) {
                        ForEach(tenorOptions, id: \.self) { Text("\($0) Bulan").tag($0) }
                    }
                    .pickerStyle(.menu).padding(10).background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10)).tint(.white)
                }
                FormField(label: "TANGGAL MULAI") {
                    DatePicker("", selection: $depoTanggal, displayedComponents: .date)
                        .datePickerStyle(.compact).colorScheme(.dark).labelsHidden()
                }
                let jatuhTempo = Calendar.current.date(byAdding: .month, value: depoTenor, to: depoTanggal) ?? depoTanggal
                HStack {
                    Text("Jatuh Tempo").font(.subheadline).foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text(jatuhTempo.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                }
                .padding(12).background(Color.white.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 10))
                Toggle(isOn: $depoARO) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto Roll Over (ARO)").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Text("Perpanjang otomatis saat jatuh tempo").font(.caption).foregroundStyle(.white.opacity(0.5))
                    }
                }.tint(Color(hex: "#A78BFA"))
            }
            .padding(16)
        }
    }

    // MARK: - Saham IDN Form

    private var sahamForm: some View {
        investasiCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("DETAIL SAHAM IDN").invLabel()
                FormField(label: "NAMA PERUSAHAAN") {
                    TextField("Contoh: Bank Central Asia", text: $sahamNama).styledInput()
                }
                FormField(label: "KODE SAHAM") {
                    HStack {
                        TextField("Contoh: BBCA", text: $sahamKode)
                            .textInputAutocapitalization(.characters).styledInput()
                        if isFetchingPrice { ProgressView().tint(.white).padding(.trailing, 4) }
                    }
                    if let harga = sahamHargaMarket {
                        Text("Harga pasar: \(harga.idrDecimalFormatted)/lembar")
                            .font(.caption).foregroundStyle(Color(hex: "#22C55E"))
                    }
                }
                .onChange(of: sahamKode) { _, kode in
                    if kode.count >= 4 { Task { await fetchSahamPrice(kode: kode) } }
                }
                FormField(label: "JUMLAH LOT") {
                    TextField("Contoh: 10", text: $sahamLot).keyboardType(.numberPad).styledInput()
                }
                FormField(label: "HARGA BELI/LEMBAR") {
                    HStack(spacing: 8) {
                        Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.subheadline)
                        CurrencyInputField(value: $sahamHarga)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Saham AS Form

    private var sahamASForm: some View {
        investasiCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("DETAIL SAHAM AS").invLabel()
                FormField(label: "NAMA PERUSAHAAN") {
                    TextField("Contoh: NVIDIA Corporation", text: $asNama).styledInput()
                }
                FormField(label: "TICKER") {
                    HStack {
                        TextField("Contoh: NVDA, SPY, SLV", text: $asKode)
                            .textInputAutocapitalization(.characters).styledInput()
                        if isFetchingUSPrice { ProgressView().tint(.white).padding(.trailing, 4) }
                    }
                    if let harga = asHargaSaatIni {
                        Text("Harga pasar: $\(harga.unitFormatted(2))/share")
                            .font(.caption).foregroundStyle(Color(hex: "#F97316"))
                    }
                }
                .onChange(of: asKode) { _, kode in
                    if kode.count >= 2 { Task { await fetchUSPrice(kode: kode) } }
                }
                FormField(label: "TOTAL INVESTASI (USD)") {
                    HStack(spacing: 8) {
                        Text("$").foregroundStyle(.white.opacity(0.5)).font(.subheadline)
                        CurrencyInputField(value: $asTotalUSD)
                    }
                }
                FormField(label: "HARGA BELI/SHARE (USD)") {
                    HStack(spacing: 8) {
                        Text("$").foregroundStyle(.white.opacity(0.5)).font(.subheadline)
                        CurrencyInputField(value: $asHargaBeli)
                    }
                }
                HStack(spacing: 12) {
                    FormField(label: "KURS BELI (IDR/USD)") {
                        HStack(spacing: 4) {
                            Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.caption)
                            CurrencyInputField(value: $asKursBeli)
                        }
                    }
                    FormField(label: "KURS SAAT INI") {
                        HStack(spacing: 4) {
                            Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.caption)
                            CurrencyInputField(value: $asKursSaatIni)
                        }
                    }
                }
                if asTotalUSD > 0 && asHargaBeli > 0 {
                    let shares = asTotalUSD / asHargaBeli
                    estimasiBox(
                        label: "ESTIMASI SHARES", value: "\(shares.unitFormatted(4)) share",
                        note: asKursBeli > 0 ? "≈ \((asTotalUSD * asKursBeli).idrDecimalFormatted)" : nil
                    )
                }
            }
            .padding(16)
        }
        .task { await fetchUSKurs() }
    }

    // MARK: - Valas Form

    private var valasForm: some View {
        investasiCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("DETAIL VALAS").invLabel()
                FormField(label: "MATA UANG") {
                    HStack(spacing: 0) {
                        ForEach(MataUangValas.allCases) { mu in
                            Button {
                                valasMata = mu
                                Task { await fetchValasKurs(mu) }
                            } label: {
                                VStack(spacing: 2) {
                                    Text(mu.flag).font(.title3)
                                    Text(mu.rawValue).font(.caption2.weight(.bold))
                                        .foregroundStyle(valasMata == mu ? .black : .white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(valasMata == mu ? Color(hex: "#06B6D4") : Color.clear)
                            }
                        }
                    }
                    .background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                HStack(spacing: 12) {
                    FormField(label: "KURS SAAT INI") {
                        HStack(spacing: 4) {
                            Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.caption)
                            CurrencyInputField(value: $valasKursSaatIni)
                            if isFetchingKurs { ProgressView().tint(.white).scaleEffect(0.7) }
                        }
                    }
                    FormField(label: "KURS BELI") {
                        HStack(spacing: 4) {
                            Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.caption)
                            CurrencyInputField(value: $valasKursBeli)
                        }
                    }
                }
                FormField(label: "JUMLAH \(valasMata.rawValue)") {
                    CurrencyInputField(value: $valasJumlah)
                }
                if valasJumlah > 0 && valasKursBeli > 0 {
                    Text("Total IDR: \((valasJumlah * valasKursBeli).idrDecimalFormatted)")
                        .font(.caption).foregroundStyle(Color(hex: "#06B6D4"))
                }
            }
            .padding(16)
        }
        .task { await fetchValasKurs(valasMata) }
    }

    // MARK: - Emas Form

    private var emasForm: some View {
        investasiCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("DETAIL EMAS").invLabel()
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
                if !emasJenis.isDigital {
                    FormField(label: "TAHUN CETAK") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(2010...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { year in
                                    ChipButton(label: "\(year)", isSelected: emasTahun == year, color: Color(hex: "#EAB308")) {
                                        emasTahun = year
                                    }
                                }
                            }.padding(.horizontal, 1)
                        }
                    }
                }
                FormField(label: "BERAT (GRAM)") {
                    TextField("Contoh: 1,5", text: $emasBerat).keyboardType(.decimalPad).styledInput()
                }
                FormField(label: "HARGA BELI/GRAM") {
                    HStack(spacing: 8) {
                        Text("Rp").foregroundStyle(.white.opacity(0.5)).font(.subheadline)
                        CurrencyInputField(value: $emasHarga)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Deadline & Ikon

    private var deadlineSection: some View {
        formSection(label: "TARGET KAPAN TERCAPAI? (OPSIONAL)") {
            VStack(spacing: 10) {
                Toggle("Aktifkan deadline", isOn: $hasDeadline)
                    .toggleStyle(SwitchToggleStyle(tint: selectedColor))
                    .foregroundStyle(.white).font(.subheadline)
                if hasDeadline {
                    HStack {
                        DatePicker("", selection: $deadline, in: Date()..., displayedComponents: [.date])
                            .datePickerStyle(.compact).labelsHidden().colorScheme(.dark)
                        Spacer()
                    }
                }
            }
            .padding(12).background(Color.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var ikonWarnaSection: some View {
        formSection(label: "IKON & WARNA") {
            IkonColorPicker(selectedIkon: $selectedIkon, selectedWarna: $selectedWarna, ikonCustom: $ikonCustom)
                .padding(12).background(Color.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button { saveTarget() } label: {
            Text(isEditing ? "Simpan" : (isInvestasi ? "Mulai Investasi!" : "Mulai Nabung!"))
                .font(.headline).foregroundStyle(.black)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(canSave ? selectedColor : Color.gray.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canSave)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func investasiCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func formSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.gray).tracking(0.5)
            content()
        }
    }

    private func estimasiBox(label: String, value: String, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.4)).tracking(0.8)
            Text(value).font(.title3.weight(.bold)).foregroundStyle(.white)
            if let note { Text(note).font(.caption).foregroundStyle(.white.opacity(0.4)) }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(invTipe.color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Async fetches

    private func fetchSahamPrice(kode: String) async {
        isFetchingPrice = true
        defer { isFetchingPrice = false }
        if let p = await AsetPriceService.shared.fetchSahamPrice(kode: kode) {
            await MainActor.run { sahamHargaMarket = p }
        }
    }

    private func fetchUSPrice(kode: String) async {
        isFetchingUSPrice = true
        defer { isFetchingUSPrice = false }
        if let p = await AsetPriceService.shared.fetchUSStockPrice(ticker: kode) {
            await MainActor.run { asHargaSaatIni = p; asHargaBeli = p }
        }
    }

    private func fetchUSKurs() async {
        if let k = await AsetPriceService.shared.fetchKursValas(.usd) {
            await MainActor.run { asKursSaatIni = k; if asKursBeli == 0 { asKursBeli = k } }
        }
    }

    private func fetchValasKurs(_ mata: MataUangValas) async {
        isFetchingKurs = true
        defer { isFetchingKurs = false }
        if let k = await AsetPriceService.shared.fetchKursValas(mata) {
            await MainActor.run {
                valasKursSaatIni = k
                if valasKursBeli == 0 { valasKursBeli = k }
            }
        }
    }

    // MARK: - Populate

    private func populateIfEditing() {
        guard let t = editingTarget else { return }
        nama = t.nama
        targetNominal = t.targetNominal
        selectedIkon = t.ikon
        selectedWarna = t.warna
        ikonCustom = t.ikonCustom ?? ""
        jenisTarget = t.jenisTarget
        if let dl = t.deadline { hasDeadline = true; deadline = dl }
        if t.jenisTarget == .biasa { saldoTerkumpulEdit = t.tersimpan }
        fotoData = t.fotoData
    }

    // MARK: - Save

    private func saveTarget() {
        let trimmedNama = nama.trimmingCharacters(in: .whitespaces)
        guard !trimmedNama.isEmpty else { return }

        if let existing = editingTarget {
            existing.nama = trimmedNama
            existing.targetNominal = targetNominal
            existing.deadline = hasDeadline ? deadline : nil
            existing.ikon = selectedIkon
            existing.warna = selectedWarna
            existing.ikonCustom = ikonCustom.isEmpty ? nil : ikonCustom
            existing.fotoData = fotoData

            // Saldo adjustment hanya untuk target biasa
            if existing.jenisTarget == .biasa {
                let selisih = saldoTerkumpulEdit - existing.tersimpan
                if selisih != 0 {
                    let adj = SimpanKeTarget(target: existing, tanggal: Date(), nominal: selisih, catatan: "Penyesuaian manual")
                    modelContext.insert(adj)
                }
            }
        } else {
            let target = Target(
                nama: trimmedNama,
                targetNominal: targetNominal,
                deadline: hasDeadline ? deadline : nil,
                ikon: selectedIkon,
                warna: selectedWarna,
                jenisTarget: jenisTarget
            )
            target.ikonCustom = ikonCustom.isEmpty ? nil : ikonCustom
            target.fotoData = fotoData
            modelContext.insert(target)

            if jenisTarget == .biasa {
                // Saldo awal
                if saldoAwal > 0 {
                    let tgl = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                    let entry = SimpanKeTarget(target: target, tanggal: tgl, nominal: saldoAwal, catatan: "Saldo awal")
                    modelContext.insert(entry)
                }
            } else {
                // Buat aset & link ke target
                let aset = buildLinkedAset(for: target)
                modelContext.insert(aset)
                target.linkedAset = aset
                aset.linkedTarget = target
            }
        }

        try? modelContext.save()
        dismiss()
    }

    private func buildLinkedAset(for target: Target) -> Aset {
        let aset = Aset(tipe: invTipe, nama: asetNama, kode: asetKode)

        switch invTipe {
        case .reksadana:
            aset.jenisReksadana = rdJenis.isEmpty ? nil : rdJenis
            aset.totalInvestasiReksadana = rdTotalInvestasi
            aset.hargaBeliPerUnit = rdHargaBeliPerUnit > 0 ? rdHargaBeliPerUnit : nil
            aset.navSaatIni = rdNavSaatIni > 0 ? rdNavSaatIni : nil
            let units = rdHargaBeliPerUnit > 0 ? rdTotalInvestasi / rdHargaBeliPerUnit : 0
            aset.nilaiSaatIni = rdNavSaatIni > 0 ? units * rdNavSaatIni : rdTotalInvestasi

        case .deposito:
            let bungaInt = NSDecimalNumber(decimal: depoBunga).intValue
            aset.nama = depoPocket.map { "\($0.nama) \(bungaInt)%" } ?? "Deposito \(bungaInt)%"
            aset.nominalDeposito = depoNominal
            aset.bungaPA = depoBunga
            aset.pphFinal = depoPPH
            aset.tenorBulan = depoTenor
            aset.tanggalMulaiDeposito = depoTanggal
            aset.autoRollOver = depoARO
            aset.nilaiSaatIni = depoNominal
            aset.pocketSumber = depoPocket

        case .saham:
            aset.lot = Decimal(string: sahamLot) ?? 0
            aset.hargaPerLembar = sahamHarga
            aset.nilaiSaatIni = (Decimal(string: sahamLot) ?? 0) * sahamHarga * 100

        case .sahamAS:
            aset.totalInvestasiUSD = asTotalUSD
            aset.hargaBeliPerShareUSD = asHargaBeli
            aset.hargaSaatIniUSD = asHargaSaatIni ?? asHargaBeli
            aset.kursBeliUSD = asKursBeli
            aset.kursSaatIniUSD = asKursSaatIni > 0 ? asKursSaatIni : asKursBeli
            aset.nilaiSaatIni = asTotalUSD * (asKursSaatIni > 0 ? asKursSaatIni : asKursBeli)

        case .valas:
            aset.mataUangValas = valasMata
            aset.jumlahValas = valasJumlah
            aset.kursBeliPerUnit = valasKursBeli
            aset.kursSaatIni = valasKursSaatIni > 0 ? valasKursSaatIni : valasKursBeli
            aset.nilaiSaatIni = valasJumlah * (valasKursSaatIni > 0 ? valasKursSaatIni : valasKursBeli)

        case .emas:
            let berat = Decimal(string: emasBerat.replacingOccurrences(of: ",", with: ".")) ?? 0
            aset.jenisEmas = emasJenis
            aset.tahunCetak = emasJenis.isDigital ? nil : emasTahun
            aset.beratGram = berat
            aset.hargaBeliPerGram = emasHarga
            aset.nilaiSaatIni = berat * emasHarga
        }

        return aset
    }

    private var asetNama: String {
        switch invTipe {
        case .reksadana: return rdNama.isEmpty ? "Reksadana" : rdNama
        case .deposito:  return "Deposito"
        case .saham:     return sahamNama.isEmpty ? sahamKode.uppercased() : sahamNama
        case .sahamAS:   return asNama.isEmpty ? asKode.uppercased() : asNama
        case .valas:     return "\(valasMata.flag) \(valasMata.rawValue)"
        case .emas:      return "\(emasJenis.displayName) \(emasBerat)g"
        }
    }

    private var asetKode: String? {
        switch invTipe {
        case .saham:   return sahamKode.isEmpty ? nil : sahamKode.uppercased()
        case .sahamAS: return asKode.isEmpty ? nil : asKode.uppercased()
        default:       return nil
        }
    }
}

// MARK: - Label helper

private extension Text {
    func invLabel() -> some View {
        self.font(.caption).foregroundStyle(.white.opacity(0.5)).tracking(1)
    }
}
