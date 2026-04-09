import SwiftUI
import SwiftData

struct AddEditHoldingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allAccounts: [Account]
    
    private var investmentAccounts: [Account] {
        allAccounts.filter { $0.type == .investment && !$0.isArchived }
    }

    @State private var ticker = ""
    @State private var name = ""
    @State private var assetType: AssetType = .stock
    @State private var subSector = ""
    @State private var exchange = "IDX"
    @State private var selectedAccountID: UUID? = nil
    @State private var searchText = ""
    @State private var showSuggestions = false
    @State private var suggestions: [KnownAsset] = []
    @State private var currency: AppCurrency = .IDR

    // First lot
    @State private var shares: Double = 0
    @State private var buyPrice: Double = 0
    @State private var buyDate = Date()
    @State private var fee: Double = 0

    private func updateSuggestions() {
        guard searchText.count >= 2 else {
            suggestions = []
            return
        }
        let q = searchText.uppercased()
        suggestions = allKnownAssets.filter {
            $0.ticker.contains(q) || $0.name.uppercased().contains(searchText.uppercased())
        }.filter { $0.assetType == assetType }.prefix(5).map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipe Aset") {
                    Picker("Tipe", selection: $assetType) {
                        ForEach(AssetType.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: assetType) { _, newType in
                        switch newType {
                        case .stock: exchange = "IDX"
                        case .etf: exchange = "NYSE"
                        case .commodity: exchange = "COMMODITY"
                        case .custom: exchange = "OTHER"
                        }
                        ticker = ""; name = ""; subSector = ""; searchText = ""
                        suggestions = []
                    }
                }

                if assetType != .custom {
                    Section("Info Aset") {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField(placeholderText, text: $searchText)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                                .onChange(of: searchText) { oldValue, newValue in
                                    ticker = newValue.uppercased()
                                    updateSuggestions()
                                    showSuggestions = !newValue.isEmpty
                                }

                            if showSuggestions && !suggestions.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(suggestions, id: \.ticker) { asset in
                                        Button {
                                            ticker = asset.ticker
                                            name = asset.name
                                            subSector = asset.subSector
                                            exchange = asset.exchange
                                            searchText = asset.ticker
                                            showSuggestions = false
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(asset.ticker.replacingOccurrences(of: ".JK", with: ""))
                                                        .font(.subheadline.bold())
                                                        .foregroundStyle(.primary)
                                                    Text(asset.name)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Spacer()
                                                Text(asset.subSector)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.blue.opacity(0.1))
                                                    .foregroundStyle(.blue)
                                                    .clipShape(Capsule())
                                            }
                                            .padding(.vertical, 8)
                                        }
                                        if asset.ticker != suggestions.last?.ticker {
                                            Divider()
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }

                        TextField("Nama Lengkap", text: $name)
                        TextField("Kategori (opsional)", text: $subSector)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Info Aset Custom") {
                        TextField("Ticker/Kode", text: $ticker)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                        TextField("Nama Lengkap", text: $name)
                        TextField("Kategori", text: $subSector)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Akun Investasi") {
                    if investmentAccounts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Buat akun investasi terlebih dahulu")
                                .foregroundStyle(.secondary)
                            Text("Buka menu Akun → Tambah Akun → Pilih tipe 'Investasi'")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("Akun", selection: $selectedAccountID) {
                            Text("Pilih Akun").tag(Optional<UUID>.none)
                            ForEach(investmentAccounts) { acc in
                                Text(acc.name).tag(Optional(acc.id))
                            }
                        }
                    }
                }

                Section {
                    Picker("Mata Uang", selection: $currency) {
                        Text("IDR (Rupiah)").tag(AppCurrency.IDR)
                        Text("USD (Dollar)").tag(AppCurrency.USD)
                    }
                    .pickerStyle(.segmented)
                    
                    CurrencyInputField(label: labelForShares, amount: $shares, currency: currency)
                    CurrencyInputField(label: "Harga Beli per Unit", amount: $buyPrice, currency: currency)
                    DatePicker("Tanggal Beli", selection: $buyDate, displayedComponents: .date)
                } header: {
                    Text("Detail Pembelian")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if assetType == .stock {
                            Text("1 lot = 100 lembar saham")
                                .font(.caption)
                        }
                        if currency == .USD {
                            Text("Harga dalam USD akan otomatis dikonversi ke IDR dengan kurs terkini")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Tambah Holding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { 
                    Button("Batal") { dismiss() } 
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                selectedAccountID = investmentAccounts.first?.id
            }
        }
    }
    
    private var placeholderText: String {
        switch assetType {
        case .stock: return "Kode Saham (BBCA, NVDA...)"
        case .etf: return "Ticker ETF (SPY, VOO...)"
        case .commodity: return "Komoditas (GOLD, SILVER...)"
        case .custom: return "Ticker"
        }
    }
    
    private var labelForShares: String {
        switch assetType {
        case .stock: return "Jumlah Lot"
        default: return "Jumlah Unit"
        }
    }
    
    private var canSave: Bool {
        !ticker.isEmpty && !name.isEmpty && selectedAccountID != nil && shares > 0 && buyPrice > 0
    }

    private func save() {
        guard let accountID = selectedAccountID else { return }

        let actualTicker: String
        if assetType == .stock && exchange == "IDX" && !ticker.hasSuffix(".JK") {
            actualTicker = "\(ticker).JK"
        } else {
            actualTicker = ticker
        }
        
        let holding = InvestmentHolding(
            accountID: accountID, ticker: actualTicker, name: name,
            assetType: assetType, subSector: subSector, exchange: exchange
        )
        context.insert(holding)

        // Convert USD to IDR if needed
        var finalBuyPrice = buyPrice
        if currency == .USD {
            let usdToIDR = getUSDToIDRRate()
            finalBuyPrice = buyPrice * usdToIDR
        }

        let actualShares = assetType == .stock ? shares * 100 : shares
        let lot = StockLot(holdingID: holding.id, shares: actualShares, buyPrice: finalBuyPrice, buyDate: buyDate, fee: 0)
        context.insert(lot)

        try? context.save()
        dismiss()
    }
    
    private func getUSDToIDRRate() -> Double {
        let descriptor = FetchDescriptor<ExchangeRate>()
        guard let rates = try? context.fetch(descriptor) else { return 16000 }
        return rates.first(where: { $0.fromCurrency == "USD" && $0.toCurrency == "IDR" })?.rate ?? 16000
    }
}
