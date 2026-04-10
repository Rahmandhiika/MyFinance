import SwiftUI
import SwiftData

struct InvestTabView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \InvestasiHolding.nama) private var holdings: [InvestasiHolding]
    @Query(sort: \Pocket.nama) private var allPockets: [Pocket]
    @Query(sort: \Expense.tanggal) private var expenses: [Expense]
    @Query(sort: \Income.tanggal) private var incomes: [Income]

    @State private var showAddHolding = false
    @State private var filterType: TipeInvestasi? = nil
    private var investasiPockets: [Pocket] {
        allPockets.filter { $0.kelompokPocket == .investasi && $0.isAktif }
    }

    private var filteredHoldings: [InvestasiHolding] {
        if let ft = filterType {
            return holdings.filter { $0.tipe == ft }
        }
        return holdings
    }

    // P&L computed per holding: Modal = sum inflow expenses to pocket, Nilai = pocket.saldo
    private func pocketFor(_ holding: InvestasiHolding) -> Pocket? {
        allPockets.first { $0.id == holding.pocketID }
    }

    private func modalFor(_ holding: InvestasiHolding) -> Double {
        // Modal = total income transferred INTO this pocket (or initial saldo set)
        // Simplified: sum of all Income where pocketID matches + transfers in
        let pID = holding.pocketID
        return incomes.filter { $0.pocketID == pID }.reduce(0) { $0 + $1.nominal }
    }

    private var totalNilai: Double {
        holdings.compactMap { pocketFor($0)?.saldo }.reduce(0, +)
    }

    private var totalModal: Double {
        holdings.reduce(0) { $0 + modalFor($1) }
    }

    private var totalPL: Double { totalNilai - totalModal }
    private var totalReturn: Double { totalModal > 0 ? (totalPL / totalModal) * 100 : 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryCard

                    // Filter
                    filterRow

                    // Holdings List
                    if filteredHoldings.isEmpty {
                        emptyHoldingsView
                    } else {
                        holdingsList
                    }

                    Spacer(minLength: 80)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Investasi")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddHolding = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .sheet(isPresented: $showAddHolding) {
                AddInvestasiHoldingView()
            }
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("TOTAL PORTFOLIO")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.7))

                Text(totalNilai.idrFormatted)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Image(systemName: totalPL >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.weight(.bold))
                    Text(totalPL.shortFormatted)
                    Text("(\(totalReturn.percentFormatted))")
                        .font(.caption)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(totalPL >= 0 ? Color(hex: "#34D399") : Color(hex: "#F87171"))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.white.opacity(0.15))
                .clipShape(Capsule())
            }
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#0f0c29"), Color(hex: "#302b63"), Color(hex: "#24243e")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            HStack(spacing: 0) {
                statItem("Modal", totalModal.shortFormatted)
                Rectangle().fill(Color(.separator)).frame(width: 0.5, height: 30)
                statItem("P&L", totalPL.shortFormatted, color: totalPL >= 0 ? .green : .red)
                Rectangle().fill(Color(.separator)).frame(width: 0.5, height: 30)
                statItem("Holdings", "\(holdings.count)")
            }
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
        .padding(.horizontal)
    }

    private func statItem(_ label: String, _ value: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("Semua", isSelected: filterType == nil) { filterType = nil }
                ForEach(TipeInvestasi.allCases, id: \.self) { tipe in
                    filterChip(tipe.displayName, isSelected: filterType == tipe) { filterType = tipe }
                }
            }
            .padding(.horizontal)
        }
    }

    private func filterChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Holdings List

    private var holdingsList: some View {
        LazyVStack(spacing: 10) {
            ForEach(filteredHoldings) { holding in
                NavigationLink(destination: InvestasiDetailView(holding: holding)) {
                    holdingRow(holding)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    private func holdingRow(_ holding: InvestasiHolding) -> some View {
        let pocket = pocketFor(holding)
        let nilai = pocket?.saldo ?? 0
        let modal = modalFor(holding)
        let pl = nilai - modal
        let ret = modal > 0 ? (pl / modal) * 100 : 0

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(holding.tipe.color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: holding.tipe.icon)
                    .font(.title3)
                    .foregroundStyle(holding.tipe.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(holding.nama)
                    .font(.headline.weight(.bold))
                Text(holding.tipe.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(nilai.shortFormatted)
                    .font(.headline.weight(.bold))
                if modal > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: pl >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(ret.percentFormatted)
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(pl >= 0 ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((pl >= 0 ? Color.green : Color.red).opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyHoldingsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue.gradient)
            Text("Belum Ada Holding")
                .font(.title3.weight(.bold))
            Text("Tambahkan investasi pertama Anda")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button { showAddHolding = true } label: {
                Label("Tambah Holding", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Add Holding

struct AddInvestasiHoldingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Pocket.nama) private var allPockets: [Pocket]

    @State private var nama = ""
    @State private var tipe: TipeInvestasi = .saham
    @State private var selectedPocketID: UUID?
    @State private var catatan = ""

    private var investasiPockets: [Pocket] {
        allPockets.filter { $0.kelompokPocket == .investasi && $0.isAktif }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipe Investasi") {
                    Picker("Tipe", selection: $tipe) {
                        ForEach(TipeInvestasi.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Info") {
                    TextField("Nama Holding", text: $nama)
                    TextField("Catatan (opsional)", text: $catatan)
                }

                Section("Pocket Investasi") {
                    if investasiPockets.isEmpty {
                        Text("Buat pocket investasi terlebih dahulu di tab Pocket")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        Picker("Pocket", selection: $selectedPocketID) {
                            Text("Pilih Pocket").tag(Optional<UUID>.none)
                            ForEach(investasiPockets) { p in
                                Text(p.nama).tag(Optional(p.id))
                            }
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
                        .disabled(nama.isEmpty || selectedPocketID == nil)
                }
            }
            .onAppear {
                selectedPocketID = investasiPockets.first?.id
            }
        }
    }

    private func save() {
        guard let pocketID = selectedPocketID else { return }
        let holding = InvestasiHolding(
            pocketID: pocketID, nama: nama, tipe: tipe,
            catatan: catatan.isEmpty ? nil : catatan
        )
        context.insert(holding)
        try? context.save()
        dismiss()
    }
}

// MARK: - Holding Detail

struct InvestasiDetailView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Pocket.nama) private var allPockets: [Pocket]
    @Query(sort: \Income.tanggal) private var incomes: [Income]

    let holding: InvestasiHolding

    @State private var showUpdateNilai = false
    @State private var newNilaiText = ""

    private var pocket: Pocket? {
        allPockets.first { $0.id == holding.pocketID }
    }

    private var nilai: Double { pocket?.saldo ?? 0 }
    private var modal: Double {
        incomes.filter { $0.pocketID == holding.pocketID }.reduce(0) { $0 + $1.nominal }
    }
    private var pl: Double { nilai - modal }
    private var returnPct: Double { modal > 0 ? (pl / modal) * 100 : 0 }

    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nilai Saat Ini")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(nilai.idrFormatted)
                            .font(.title2.bold())
                    }
                    Spacer()
                    Button {
                        newNilaiText = String(format: "%.0f", nilai)
                        showUpdateNilai = true
                    } label: {
                        Label("Update", systemImage: "pencil.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
            } header: {
                Text("Nilai Portfolio")
            } footer: {
                Text("Update nilai saat ini secara manual")
            }

            Section("Detail") {
                LabeledContent("Nama", value: holding.nama)
                LabeledContent("Tipe", value: holding.tipe.displayName)
                LabeledContent("Modal", value: modal.idrFormatted)
                LabeledContent("P&L") {
                    Text(pl.idrFormatted)
                        .foregroundStyle(pl >= 0 ? .green : .red)
                }
                LabeledContent("Return") {
                    Text(returnPct.percentFormatted)
                        .foregroundStyle(pl >= 0 ? .green : .red)
                }
                if let pocket {
                    LabeledContent("Pocket", value: pocket.nama)
                }
                if let catatan = holding.catatan, !catatan.isEmpty {
                    LabeledContent("Catatan", value: catatan)
                }
            }
        }
        .navigationTitle(holding.nama)
        .alert("Update Nilai", isPresented: $showUpdateNilai) {
            TextField("Nilai saat ini", text: $newNilaiText)
                .keyboardType(.numberPad)
            Button("Simpan") { updateNilai() }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Masukkan nilai portfolio saat ini untuk \(holding.nama)")
        }
    }

    private func updateNilai() {
        guard let newVal = Double(newNilaiText), newVal >= 0 else { return }
        if let pocket {
            pocket.saldo = newVal
            try? context.save()
        }
    }
}
