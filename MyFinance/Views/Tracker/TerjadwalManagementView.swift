import SwiftUI
import SwiftData

// MARK: - Terjadwal Management (main sheet)

struct TerjadwalManagementView: View {
    @Environment(\.modelContext) private var context

    @Query private var expenseTerjadwal: [ExpenseTerjadwal]
    @Query private var incomeTerjadwal: [IncomeTerjadwal]
    @Query private var transferTerjadwal: [TransferInternalTerjadwal]
    @Query private var pockets: [Pocket]
    @Query private var expenseCategories: [KategoriExpense]
    @Query private var incomeCategories: [KategoriIncome]

    @State private var selectedTab: TipeTransaksi = .expense
    @State private var showAddExpense = false
    @State private var showAddIncome = false
    @State private var showAddTransfer = false

    @State private var editingExpense: ExpenseTerjadwal?
    @State private var editingIncome: IncomeTerjadwal?
    @State private var editingTransfer: TransferInternalTerjadwal?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Selector
                HStack(spacing: 8) {
                    ForEach(TipeTransaksi.allCases, id: \.self) { type in
                        Button {
                            withAnimation { selectedTab = type }
                        } label: {
                            Text(type.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(selectedTab == type ? .white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(selectedTab == type ? type.color : Color(.tertiarySystemGroupedBackground))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

                List {
                    switch selectedTab {
                    case .expense: expenseSection
                    case .income: incomeSection
                    case .transfer: transferSection
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Terjadwal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        switch selectedTab {
                        case .expense: showAddExpense = true
                        case .income: showAddIncome = true
                        case .transfer: showAddTransfer = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddExpense) {
                AddEditExpenseTerjadwalView()
            }
            .sheet(isPresented: $showAddIncome) {
                AddEditIncomeTerjadwalView()
            }
            .sheet(isPresented: $showAddTransfer) {
                AddEditTransferTerjadwalView()
            }
            .sheet(item: $editingExpense) { item in
                AddEditExpenseTerjadwalView(existing: item)
            }
            .sheet(item: $editingIncome) { item in
                AddEditIncomeTerjadwalView(existing: item)
            }
            .sheet(item: $editingTransfer) { item in
                AddEditTransferTerjadwalView(existing: item)
            }
        }
    }

    // MARK: - Expense Section

    private var expenseSection: some View {
        Group {
            if expenseTerjadwal.isEmpty {
                terjadwalEmpty("Belum ada pengeluaran terjadwal")
            } else {
                ForEach(expenseTerjadwal.sorted { $0.setiapTanggal < $1.setiapTanggal }) { item in
                    terjadwalExpenseRow(item)
                        .onTapGesture { editingExpense = item }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                context.delete(item)
                                try? context.save()
                            } label: {
                                Label("Hapus", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                item.isAktif.toggle()
                                try? context.save()
                            } label: {
                                Label(item.isAktif ? "Nonaktifkan" : "Aktifkan",
                                      systemImage: item.isAktif ? "pause.fill" : "play.fill")
                            }
                            .tint(item.isAktif ? .orange : .green)
                        }
                }
            }
        }
    }

    private func terjadwalExpenseRow(_ item: ExpenseTerjadwal) -> some View {
        let katName = expenseCategories.first(where: { $0.id == item.kategoriID })?.nama ?? "Tanpa Kategori"
        let pocketName = pockets.first(where: { $0.id == item.pocketID })?.nama

        return TerjadwalRow(
            nama: item.nama,
            subtitle: katName + (pocketName.map { " • \($0)" } ?? ""),
            tanggal: item.setiapTanggal,
            nominal: item.nominal,
            isAktif: item.isAktif,
            catatOtomatis: item.catatOtomatisAktif,
            color: .red
        )
    }

    // MARK: - Income Section

    private var incomeSection: some View {
        Group {
            if incomeTerjadwal.isEmpty {
                terjadwalEmpty("Belum ada pemasukan terjadwal")
            } else {
                ForEach(incomeTerjadwal.sorted { $0.setiapTanggal < $1.setiapTanggal }) { item in
                    terjadwalIncomeRow(item)
                        .onTapGesture { editingIncome = item }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                context.delete(item)
                                try? context.save()
                            } label: {
                                Label("Hapus", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                item.isAktif.toggle()
                                try? context.save()
                            } label: {
                                Label(item.isAktif ? "Nonaktifkan" : "Aktifkan",
                                      systemImage: item.isAktif ? "pause.fill" : "play.fill")
                            }
                            .tint(item.isAktif ? .orange : .green)
                        }
                }
            }
        }
    }

    private func terjadwalIncomeRow(_ item: IncomeTerjadwal) -> some View {
        let katName = incomeCategories.first(where: { $0.id == item.kategoriID })?.nama ?? "Tanpa Kategori"
        let pocketName = pockets.first(where: { $0.id == item.pocketID })?.nama

        return TerjadwalRow(
            nama: item.nama,
            subtitle: katName + (pocketName.map { " • \($0)" } ?? ""),
            tanggal: item.setiapTanggal,
            nominal: item.nominal,
            isAktif: item.isAktif,
            catatOtomatis: item.catatOtomatisAktif,
            color: .green
        )
    }

    // MARK: - Transfer Section

    private var transferSection: some View {
        Group {
            if transferTerjadwal.isEmpty {
                terjadwalEmpty("Belum ada transfer terjadwal")
            } else {
                ForEach(transferTerjadwal.sorted { $0.setiapTanggal < $1.setiapTanggal }) { item in
                    terjadwalTransferRow(item)
                        .onTapGesture { editingTransfer = item }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                context.delete(item)
                                try? context.save()
                            } label: {
                                Label("Hapus", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                item.isAktif.toggle()
                                try? context.save()
                            } label: {
                                Label(item.isAktif ? "Nonaktifkan" : "Aktifkan",
                                      systemImage: item.isAktif ? "pause.fill" : "play.fill")
                            }
                            .tint(item.isAktif ? .orange : .green)
                        }
                }
            }
        }
    }

    private func terjadwalTransferRow(_ item: TransferInternalTerjadwal) -> some View {
        let asalName = pockets.first(where: { $0.id == item.pocketAsalID })?.nama ?? "?"
        let tujuanName = pockets.first(where: { $0.id == item.pocketTujuanID })?.nama ?? "?"

        return TerjadwalRow(
            nama: item.nama,
            subtitle: "\(asalName) → \(tujuanName)",
            tanggal: item.setiapTanggal,
            nominal: item.nominal,
            isAktif: item.isAktif,
            catatOtomatis: item.catatOtomatisAktif,
            color: .blue
        )
    }

    private func terjadwalEmpty(_ text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

// MARK: - TerjadwalRow Component

private struct TerjadwalRow: View {
    let nama: String
    let subtitle: String
    let tanggal: Int
    let nominal: Double?
    let isAktif: Bool
    let catatOtomatis: Bool
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            // Date badge
            VStack(spacing: 0) {
                Text("\(tanggal)")
                    .font(.headline.bold())
                    .foregroundStyle(isAktif ? color : .secondary)
                Text("tgl")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 40, height: 40)
            .background((isAktif ? color : Color.secondary).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(nama)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isAktif ? .primary : .secondary)
                        .lineLimit(1)
                    if !isAktif {
                        Text("Nonaktif")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary)
                            .clipShape(Capsule())
                    }
                    if catatOtomatis {
                        Image(systemName: "autostartstop")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let nominal {
                Text(nominal.idrFormatted)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isAktif ? color : .secondary)
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add/Edit Expense Terjadwal

struct AddEditExpenseTerjadwalView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var existing: ExpenseTerjadwal?

    @Query private var expenseCategories: [KategoriExpense]
    @Query private var pockets: [Pocket]

    @State private var nama = ""
    @State private var setiapTanggal = 1
    @State private var reminderAktif = true
    @State private var catatOtomatisAktif = false
    @State private var hasNominal = false
    @State private var nominal: Double = 0
    @State private var selectedKategoriID: UUID?
    @State private var selectedPocketID: UUID?
    @State private var catatan = ""
    @State private var isAktif = true

    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Info") {
                    TextField("Nama (misal: Langganan Netflix)", text: $nama)
                    Stepper("Setiap Tanggal \(setiapTanggal)", value: $setiapTanggal, in: 1...31)
                }

                Section("Kategori & Pocket") {
                    Picker("Kategori", selection: $selectedKategoriID) {
                        Text("Pilih Kategori").tag(Optional<UUID>.none)
                        ForEach(expenseCategories) { k in
                            Text(k.nama).tag(Optional(k.id))
                        }
                    }

                    Picker("Pocket", selection: $selectedPocketID) {
                        Text("Pilih Pocket").tag(Optional<UUID>.none)
                        ForEach(pockets) { p in
                            Text(p.nama).tag(Optional(p.id))
                        }
                    }
                }

                Section("Nominal") {
                    Toggle("Nominal Tetap", isOn: $hasNominal)
                    if hasNominal {
                        CurrencyInputField(label: "Nominal", amount: $nominal)
                    }
                }

                Section("Pengingat") {
                    Toggle("Reminder Aktif", isOn: $reminderAktif)
                    Toggle("Catat Otomatis", isOn: $catatOtomatisAktif)
                        .tint(.blue)
                    if catatOtomatisAktif {
                        Text("Transaksi akan otomatis dicatat setiap tanggal tersebut")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    TextField("Catatan (opsional)", text: $catatan, axis: .vertical)
                        .lineLimit(3)
                }

                if isEditing {
                    Section {
                        Toggle("Aktif", isOn: $isAktif)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Terjadwal" : "Tambah Terjadwal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                        .disabled(nama.isEmpty)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        guard let e = existing else { return }
        nama = e.nama
        setiapTanggal = e.setiapTanggal
        reminderAktif = e.reminderAktif
        catatOtomatisAktif = e.catatOtomatisAktif
        hasNominal = e.nominal != nil
        nominal = e.nominal ?? 0
        selectedKategoriID = e.kategoriID
        selectedPocketID = e.pocketID
        catatan = e.catatan ?? ""
        isAktif = e.isAktif
    }

    private func save() {
        if let e = existing {
            e.nama = nama
            e.setiapTanggal = setiapTanggal
            e.reminderAktif = reminderAktif
            e.catatOtomatisAktif = catatOtomatisAktif
            e.nominal = hasNominal ? nominal : nil
            e.kategoriID = selectedKategoriID
            e.pocketID = selectedPocketID
            e.catatan = catatan.isEmpty ? nil : catatan
            e.isAktif = isAktif
        } else {
            let t = ExpenseTerjadwal(
                nama: nama, setiapTanggal: setiapTanggal,
                reminderAktif: reminderAktif, catatOtomatisAktif: catatOtomatisAktif,
                nominal: hasNominal ? nominal : nil,
                kategoriID: selectedKategoriID, pocketID: selectedPocketID,
                catatan: catatan.isEmpty ? nil : catatan
            )
            context.insert(t)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Add/Edit Income Terjadwal

struct AddEditIncomeTerjadwalView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var existing: IncomeTerjadwal?

    @Query private var incomeCategories: [KategoriIncome]
    @Query private var pockets: [Pocket]

    @State private var nama = ""
    @State private var setiapTanggal = 1
    @State private var reminderAktif = true
    @State private var catatOtomatisAktif = false
    @State private var hasNominal = false
    @State private var nominal: Double = 0
    @State private var selectedKategoriID: UUID?
    @State private var selectedPocketID: UUID?
    @State private var catatan = ""
    @State private var isAktif = true

    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Info") {
                    TextField("Nama (misal: Gaji Bulanan)", text: $nama)
                    Stepper("Setiap Tanggal \(setiapTanggal)", value: $setiapTanggal, in: 1...31)
                }

                Section("Kategori & Pocket") {
                    Picker("Kategori", selection: $selectedKategoriID) {
                        Text("Pilih Kategori").tag(Optional<UUID>.none)
                        ForEach(incomeCategories) { k in
                            Text(k.nama).tag(Optional(k.id))
                        }
                    }

                    Picker("Pocket", selection: $selectedPocketID) {
                        Text("Pilih Pocket").tag(Optional<UUID>.none)
                        ForEach(pockets) { p in
                            Text(p.nama).tag(Optional(p.id))
                        }
                    }
                }

                Section("Nominal") {
                    Toggle("Nominal Tetap", isOn: $hasNominal)
                    if hasNominal {
                        CurrencyInputField(label: "Nominal", amount: $nominal)
                    }
                }

                Section("Pengingat") {
                    Toggle("Reminder Aktif", isOn: $reminderAktif)
                    Toggle("Catat Otomatis", isOn: $catatOtomatisAktif)
                        .tint(.blue)
                }

                Section {
                    TextField("Catatan (opsional)", text: $catatan, axis: .vertical)
                        .lineLimit(3)
                }

                if isEditing {
                    Section { Toggle("Aktif", isOn: $isAktif) }
                }
            }
            .navigationTitle(isEditing ? "Edit Terjadwal" : "Tambah Terjadwal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                        .disabled(nama.isEmpty)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        guard let e = existing else { return }
        nama = e.nama
        setiapTanggal = e.setiapTanggal
        reminderAktif = e.reminderAktif
        catatOtomatisAktif = e.catatOtomatisAktif
        hasNominal = e.nominal != nil
        nominal = e.nominal ?? 0
        selectedKategoriID = e.kategoriID
        selectedPocketID = e.pocketID
        catatan = e.catatan ?? ""
        isAktif = e.isAktif
    }

    private func save() {
        if let e = existing {
            e.nama = nama
            e.setiapTanggal = setiapTanggal
            e.reminderAktif = reminderAktif
            e.catatOtomatisAktif = catatOtomatisAktif
            e.nominal = hasNominal ? nominal : nil
            e.kategoriID = selectedKategoriID
            e.pocketID = selectedPocketID
            e.catatan = catatan.isEmpty ? nil : catatan
            e.isAktif = isAktif
        } else {
            let t = IncomeTerjadwal(
                nama: nama, setiapTanggal: setiapTanggal,
                reminderAktif: reminderAktif, catatOtomatisAktif: catatOtomatisAktif,
                nominal: hasNominal ? nominal : nil,
                kategoriID: selectedKategoriID, pocketID: selectedPocketID,
                catatan: catatan.isEmpty ? nil : catatan
            )
            context.insert(t)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Add/Edit Transfer Terjadwal

struct AddEditTransferTerjadwalView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var existing: TransferInternalTerjadwal?

    @Query private var pockets: [Pocket]

    @State private var nama = ""
    @State private var setiapTanggal = 1
    @State private var reminderAktif = true
    @State private var catatOtomatisAktif = false
    @State private var hasNominal = false
    @State private var nominal: Double = 0
    @State private var selectedAsalID: UUID?
    @State private var selectedTujuanID: UUID?
    @State private var catatan = ""
    @State private var isAktif = true

    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Info") {
                    TextField("Nama (misal: Tabung ke Dana Darurat)", text: $nama)
                    Stepper("Setiap Tanggal \(setiapTanggal)", value: $setiapTanggal, in: 1...31)
                }

                Section("Dari & Ke") {
                    Picker("Dari Pocket", selection: $selectedAsalID) {
                        Text("Pilih Pocket Asal").tag(Optional<UUID>.none)
                        ForEach(pockets) { p in
                            Text(p.nama).tag(Optional(p.id))
                        }
                    }

                    Picker("Ke Pocket", selection: $selectedTujuanID) {
                        Text("Pilih Pocket Tujuan").tag(Optional<UUID>.none)
                        ForEach(pockets.filter { $0.id != selectedAsalID }) { p in
                            Text(p.nama).tag(Optional(p.id))
                        }
                    }
                }

                Section("Nominal") {
                    Toggle("Nominal Tetap", isOn: $hasNominal)
                    if hasNominal {
                        CurrencyInputField(label: "Nominal", amount: $nominal)
                    }
                }

                Section("Pengingat") {
                    Toggle("Reminder Aktif", isOn: $reminderAktif)
                    Toggle("Catat Otomatis", isOn: $catatOtomatisAktif)
                        .tint(.blue)
                }

                Section {
                    TextField("Catatan (opsional)", text: $catatan, axis: .vertical)
                        .lineLimit(3)
                }

                if isEditing {
                    Section { Toggle("Aktif", isOn: $isAktif) }
                }
            }
            .navigationTitle(isEditing ? "Edit Terjadwal" : "Tambah Terjadwal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                        .disabled(nama.isEmpty)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        guard let e = existing else { return }
        nama = e.nama
        setiapTanggal = e.setiapTanggal
        reminderAktif = e.reminderAktif
        catatOtomatisAktif = e.catatOtomatisAktif
        hasNominal = e.nominal != nil
        nominal = e.nominal ?? 0
        selectedAsalID = e.pocketAsalID
        selectedTujuanID = e.pocketTujuanID
        catatan = e.catatan ?? ""
        isAktif = e.isAktif
    }

    private func save() {
        if let e = existing {
            e.nama = nama
            e.setiapTanggal = setiapTanggal
            e.reminderAktif = reminderAktif
            e.catatOtomatisAktif = catatOtomatisAktif
            e.nominal = hasNominal ? nominal : nil
            e.pocketAsalID = selectedAsalID
            e.pocketTujuanID = selectedTujuanID
            e.catatan = catatan.isEmpty ? nil : catatan
            e.isAktif = isAktif
        } else {
            let t = TransferInternalTerjadwal(
                nama: nama, setiapTanggal: setiapTanggal,
                reminderAktif: reminderAktif, catatOtomatisAktif: catatOtomatisAktif,
                nominal: hasNominal ? nominal : nil,
                pocketAsalID: selectedAsalID, pocketTujuanID: selectedTujuanID,
                catatan: catatan.isEmpty ? nil : catatan
            )
            context.insert(t)
        }
        try? context.save()
        dismiss()
    }
}
