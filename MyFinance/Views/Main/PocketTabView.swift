import SwiftUI
import SwiftData

struct PocketTabView: View {
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Pocket> { $0.isAktif }, sort: \Pocket.createdAt) private var pockets: [Pocket]
    @Query private var debiturs: [Debitur]
    @Query private var krediturs: [Kreditur]
    @Query private var goals: [Goal]
    @Query private var riwayatGoal: [RiwayatMencicilMenabung]
    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]
    @Query private var asetNonFinansial: [AsetNonFinansial]
    @Query private var kategoriAset: [KategoriAset]
    @Query private var danaDaruratConfig: [DanaDaruratConfig]
    @Query private var kategoriExpense: [KategoriExpense]

    @State private var selectedSection: PocketSection = .pocket
    @State private var showAddPocket = false
    @State private var showAddDebitur = false
    @State private var showAddKreditur = false
    @State private var showAddGoal = false
    @State private var showAddAset = false
    @State private var newName = ""
    @State private var newCatatan = ""

    enum PocketSection: String, CaseIterable {
        case pocket = "Pocket"
        case piutang = "Piutang"
        case utang = "Utang"
        case netWorth = "Net Worth"
        case goals = "Goals"
        case danaDarurat = "Dana Darurat"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Section selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PocketSection.allCases, id: \.self) { section in
                            Button {
                                withAnimation(.spring(response: 0.3)) { selectedSection = section }
                            } label: {
                                Text(section.rawValue)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(selectedSection == section ? .white : .primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedSection == section ? Color.blue : Color(.tertiarySystemGroupedBackground))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }

                ScrollView {
                    switch selectedSection {
                    case .pocket: pocketSection
                    case .piutang: piutangSection
                    case .utang: utangSection
                    case .netWorth: netWorthSection
                    case .goals: goalsSection
                    case .danaDarurat: danaDaruratSection
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Pocket")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Pocket Section

    private var pocketSection: some View {
        VStack(spacing: 16) {
            ForEach(KelompokPocket.allCases, id: \.self) { kelompok in
                let filtered = pockets.filter { $0.kelompokPocket == kelompok }
                if !filtered.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: kelompok.icon)
                                .foregroundStyle(.secondary)
                            Text(kelompok.displayName)
                                .font(.headline)
                            Spacer()
                            Text(filtered.reduce(0) { $0 + $1.saldo }.shortFormatted)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        ForEach(filtered) { pocket in
                            NavigationLink(destination: PocketDetailView(pocket: pocket)) {
                                pocketCard(pocket)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Button { showAddPocket = true } label: {
                Label("Tambah Pocket", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)

            Spacer(minLength: 80)
        }
        .padding(.top, 8)
        .sheet(isPresented: $showAddPocket) {
            AddEditPocketView()
        }
    }

    private func pocketCard(_ pocket: Pocket) -> some View {
        HStack(spacing: 14) {
            Image(systemName: pocket.kelompokPocket.icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(pocket.nama).font(.headline)
                Text(pocket.kategoriPocket.displayName)
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Text(pocket.saldo.idrFormatted)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(pocket.saldo >= 0 ? Color.primary : Color.red)

            Image(systemName: "chevron.right")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Piutang

    private var piutangSection: some View {
        VStack(spacing: 12) {
            if debiturs.isEmpty {
                emptyCard("Belum ada debitur", "Tambah debitur untuk tracking piutang")
            }

            ForEach(debiturs) { d in
                let dipinjamkan = expenses.filter { $0.debiturID == d.id }.reduce(0) { $0 + $1.nominal }
                let kembali = incomes.filter { $0.debiturID == d.id }.reduce(0) { $0 + $1.nominal }
                let sisa = dipinjamkan - kembali

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(d.nama).font(.headline)
                        Text("Dipinjamkan: \(dipinjamkan.shortFormatted)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(sisa.idrFormatted)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(sisa > 0 ? .orange : .green)
                        Text(sisa > 0 ? "Belum Lunas" : "Lunas")
                            .font(.caption2)
                            .foregroundStyle(sisa > 0 ? .orange : .green)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }

            Button { showAddDebitur = true } label: {
                Label("Tambah Debitur", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)

            Spacer(minLength: 80)
        }
        .padding(.top, 8)
        .alert("Tambah Debitur", isPresented: $showAddDebitur) {
            TextField("Nama", text: $newName)
            Button("Simpan") {
                guard !newName.isEmpty else { return }
                context.insert(Debitur(nama: newName))
                try? context.save()
                newName = ""
            }
            Button("Batal", role: .cancel) { newName = "" }
        }
    }

    // MARK: - Utang

    private var utangSection: some View {
        VStack(spacing: 12) {
            if krediturs.isEmpty {
                emptyCard("Belum ada kreditur", "Tambah kreditur untuk tracking utang")
            }

            ForEach(krediturs) { k in
                let dipinjam = incomes.filter { $0.krediturID == k.id }.reduce(0) { $0 + $1.nominal }
                let dibayar = expenses.filter { $0.krediturID == k.id }.reduce(0) { $0 + $1.nominal }
                let sisa = dipinjam - dibayar

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(k.nama).font(.headline)
                        Text("Total pinjaman: \(dipinjam.shortFormatted)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(sisa.idrFormatted)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(sisa > 0 ? .red : .green)
                        Text(sisa > 0 ? "Belum Lunas" : "Lunas")
                            .font(.caption2)
                            .foregroundStyle(sisa > 0 ? .red : .green)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }

            Button { showAddKreditur = true } label: {
                Label("Tambah Kreditur", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)

            Spacer(minLength: 80)
        }
        .padding(.top, 8)
        .alert("Tambah Kreditur", isPresented: $showAddKreditur) {
            TextField("Nama", text: $newName)
            Button("Simpan") {
                guard !newName.isEmpty else { return }
                context.insert(Kreditur(nama: newName))
                try? context.save()
                newName = ""
            }
            Button("Batal", role: .cancel) { newName = "" }
        }
    }

    // MARK: - Net Worth

    private var netWorthSection: some View {
        let saldoBiasa = pockets.filter { $0.kelompokPocket == .biasa }.reduce(0) { $0 + $1.saldo }
        let saldoInvestasi = pockets.filter { $0.kelompokPocket == .investasi }.reduce(0) { $0 + $1.saldo }
        let asetNF = asetNonFinansial.reduce(0) { $0 + $1.nilaiPasarTerakhir }

        let totalPiutang: Double = {
            debiturs.reduce(0) { total, d in
                let dipinjamkan = expenses.filter { $0.debiturID == d.id }.reduce(0) { $0 + $1.nominal }
                let kembali = incomes.filter { $0.debiturID == d.id }.reduce(0) { $0 + $1.nominal }
                return total + max(0, dipinjamkan - kembali)
            }
        }()

        let totalAset = saldoBiasa + saldoInvestasi + asetNF + totalPiutang

        let saldoUtang = abs(pockets.filter { $0.kelompokPocket == .utang }.reduce(0) { $0 + $1.saldo })
        let totalUtang: Double = {
            krediturs.reduce(0) { total, k in
                let dipinjam = incomes.filter { $0.krediturID == k.id }.reduce(0) { $0 + $1.nominal }
                let dibayar = expenses.filter { $0.krediturID == k.id }.reduce(0) { $0 + $1.nominal }
                return total + max(0, dipinjam - dibayar)
            }
        }()
        let totalKewajiban = saldoUtang + totalUtang
        let netWorth = totalAset - totalKewajiban

        return VStack(spacing: 16) {
            // Hero card
            VStack(spacing: 12) {
                Text("NET WORTH").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.white.opacity(0.7))
                Text(netWorth.idrFormatted)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)

            // Breakdown
            VStack(spacing: 12) {
                nwRow("Pocket Biasa", saldoBiasa)
                nwRow("Pocket Investasi", saldoInvestasi)
                nwRow("Aset Non-Finansial", asetNF)
                nwRow("Piutang", totalPiutang)
                Divider()
                nwRow("Total Aset", totalAset, bold: true, color: .green)

                nwRow("Utang Pocket", saldoUtang)
                nwRow("Utang Kreditur", totalUtang)
                Divider()
                nwRow("Total Kewajiban", totalKewajiban, bold: true, color: .red)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            // Aset Non-Finansial
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Aset Non-Finansial").font(.headline)
                    Spacer()
                    Button { showAddAset = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundStyle(.blue)
                    }
                }
                if asetNonFinansial.isEmpty {
                    Text("Belum ada aset non-finansial").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(asetNonFinansial) { aset in
                    HStack {
                        Text(aset.namaAset).font(.subheadline)
                        Spacer()
                        Text(aset.nilaiPasarTerakhir.idrFormatted)
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Spacer(minLength: 80)
        }
        .padding(.top, 8)
        .sheet(isPresented: $showAddAset) {
            AddAsetNonFinansialView()
        }
    }

    private func nwRow(_ label: String, _ value: Double, bold: Bool = false, color: Color = .primary) -> some View {
        HStack {
            Text(label).font(bold ? .subheadline.weight(.bold) : .subheadline)
            Spacer()
            Text(value.idrFormatted).font(bold ? .subheadline.weight(.bold) : .subheadline).foregroundStyle(color)
        }
    }

    // MARK: - Goals

    private var goalsSection: some View {
        VStack(spacing: 12) {
            if goals.isEmpty {
                emptyCard("Belum ada goal", "Buat financial goal pertama Anda")
            }

            ForEach(goals) { goal in
                let terkumpul = riwayatGoal.filter { $0.goalID == goal.id }.reduce(0) { $0 + $1.nominal }
                let progress = goal.targetNominal > 0 ? min(terkumpul / goal.targetNominal, 1.0) : 0

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.nama).font(.headline)
                            Text(goal.tipe.displayName)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if goal.isSelesai {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    ProgressView(value: progress)
                        .tint(progress >= 1.0 ? .green : .blue)

                    HStack {
                        Text(terkumpul.shortFormatted)
                            .font(.caption.weight(.semibold))
                        Text("/ \(goal.targetNominal.shortFormatted)")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f%%", progress * 100))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(progress >= 1.0 ? .green : .blue)
                    }

                    if let deadline = goal.deadline {
                        Text("Deadline: \(deadline.formatted(.dateTime.day().month().year()))")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }

            Button { showAddGoal = true } label: {
                Label("Tambah Goal", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)

            Spacer(minLength: 80)
        }
        .padding(.top, 8)
        .sheet(isPresented: $showAddGoal) {
            AddGoalView()
        }
    }

    // MARK: - Dana Darurat

    private var danaDaruratSection: some View {
        let config = danaDaruratConfig.first
        let bulan = config?.jumlahBulan ?? 3
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()

        let recentExpenses = expenses.filter { exp in
            exp.tanggal >= sixMonthsAgo
        }

        let realExpenses = recentExpenses.filter { exp in
            guard let katID = exp.kategoriID,
                  let kat = kategoriExpense.first(where: { $0.id == katID }) else { return true }
            return kat.kelompok == .expense && kat.prioritas != .blank
        }

        let avgMonthly = realExpenses.reduce(0) { $0 + $1.nominal } / 6.0
        let target = avgMonthly * Double(bulan)
        let current = pockets.filter { $0.kelompokPocket == .biasa }.reduce(0) { $0 + $1.saldo }
        let progress = target > 0 ? min(current / target, 1.0) : 0

        return VStack(spacing: 16) {
            VStack(spacing: 12) {
                Text("DANA DARURAT").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.white.opacity(0.7))

                Text("Target: \(bulan) Bulan")
                    .font(.headline).foregroundStyle(.white)

                Text(target.idrFormatted)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                ProgressView(value: progress)
                    .tint(.white)
                    .padding(.horizontal, 40)

                Text(String(format: "%.0f%% tercapai", progress * 100))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [Color(hex: "#11998e"), Color(hex: "#38ef7d")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)

            VStack(spacing: 8) {
                HStack {
                    Text("Saldo Biasa Saat Ini").font(.subheadline)
                    Spacer()
                    Text(current.idrFormatted).font(.subheadline.weight(.bold))
                }
                HStack {
                    Text("Rata-rata Expense/Bulan").font(.subheadline)
                    Spacer()
                    Text(avgMonthly.idrFormatted).font(.subheadline.weight(.bold))
                }
                HStack {
                    Text("Target (\(bulan) bulan)").font(.subheadline)
                    Spacer()
                    Text(target.idrFormatted).font(.subheadline.weight(.bold))
                }
                HStack {
                    Text("Kekurangan").font(.subheadline)
                    Spacer()
                    Text(max(0, target - current).idrFormatted)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Spacer(minLength: 80)
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func emptyCard(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.headline)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - Add Goal View

struct AddGoalView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var nama = ""
    @State private var tipe: TipeGoal = .tabungan
    @State private var targetNominal: Double = 0
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var catatan = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Info Goal") {
                    TextField("Nama Goal", text: $nama)
                    Picker("Tipe", selection: $tipe) {
                        ForEach(TipeGoal.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    CurrencyInputField(label: "Target Nominal", amount: $targetNominal)
                }

                Section {
                    Toggle("Deadline", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Tanggal", selection: $deadline, in: Date()..., displayedComponents: .date)
                    }
                }

                Section {
                    TextField("Catatan (opsional)", text: $catatan, axis: .vertical)
                }
            }
            .navigationTitle("Tambah Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                        .disabled(nama.isEmpty || targetNominal <= 0)
                }
            }
        }
    }

    private func save() {
        let goal = Goal(nama: nama, tipe: tipe, targetNominal: targetNominal,
                       deadline: hasDeadline ? deadline : nil,
                       catatan: catatan.isEmpty ? nil : catatan)
        context.insert(goal)
        try? context.save()
        dismiss()
    }
}

// MARK: - Add Aset Non-Finansial

struct AddAsetNonFinansialView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var kategoriAset: [KategoriAset]

    @State private var namaAset = ""
    @State private var nilaiPasar: Double = 0
    @State private var selectedKategoriID: UUID?
    @State private var showAddKategori = false
    @State private var newKategoriName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Kategori Aset") {
                    Picker("Kategori", selection: $selectedKategoriID) {
                        Text("Pilih").tag(Optional<UUID>.none)
                        ForEach(kategoriAset) { k in Text(k.nama).tag(Optional(k.id)) }
                    }
                    Button("+ Tambah Kategori") { showAddKategori = true }
                        .font(.caption)
                }

                Section("Detail") {
                    TextField("Nama Aset", text: $namaAset)
                    CurrencyInputField(label: "Nilai Pasar Terakhir", amount: $nilaiPasar)
                }
            }
            .navigationTitle("Tambah Aset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                        .disabled(namaAset.isEmpty || selectedKategoriID == nil)
                }
            }
            .alert("Tambah Kategori Aset", isPresented: $showAddKategori) {
                TextField("Nama", text: $newKategoriName)
                Button("Simpan") {
                    let k = KategoriAset(nama: newKategoriName)
                    context.insert(k)
                    try? context.save()
                    selectedKategoriID = k.id
                    newKategoriName = ""
                }
                Button("Batal", role: .cancel) {}
            }
        }
    }

    private func save() {
        guard let katID = selectedKategoriID else { return }
        let aset = AsetNonFinansial(kategoriAsetID: katID, namaAset: namaAset, nilaiPasarTerakhir: nilaiPasar)
        context.insert(aset)
        try? context.save()
        dismiss()
    }
}
