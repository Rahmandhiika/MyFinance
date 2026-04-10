import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var userProfiles: [UserProfile]
    @Query private var danaDaruratConfigs: [DanaDaruratConfig]
    @Query private var pockets: [Pocket]
    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]
    @Query private var transferInternals: [TransferInternal]
    @Query private var kategoriExpenses: [KategoriExpense]
    @Query private var kategoriIncomes: [KategoriIncome]
    @Query private var expenseTerjadwals: [ExpenseTerjadwal]
    @Query private var incomeTerjadwals: [IncomeTerjadwal]
    @Query private var transferInternalTerjadwals: [TransferInternalTerjadwal]
    @Query private var goals: [Goal]
    @Query private var riwayatMencicils: [RiwayatMencicilMenabung]
    @Query private var investasiHoldings: [InvestasiHolding]
    @Query private var budgetBulanans: [BudgetBulanan]
    @Query private var rencanaAnggarans: [RencanaAnggaranTahunan]
    @Query private var asetNonFinansials: [AsetNonFinansial]
    @Query private var kategoriAsets: [KategoriAset]
    @Query private var updateSaldos: [UpdateSaldo]
    @Query private var debiturs: [Debitur]
    @Query private var krediturs: [Kreditur]
    @Query private var fgis: [FGI]

    @State private var editedNama: String = ""
    @State private var editedGreeting: String = ""
    @State private var editedJumlahBulan: Int = 3
    @State private var showResetConfirmation = false
    @State private var hasLoadedProfile = false

    private var userProfile: UserProfile? {
        userProfiles.first
    }

    private var danaDaruratConfig: DanaDaruratConfig? {
        danaDaruratConfigs.first
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profil Section
                Section {
                    HStack {
                        Text("Nama")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("Nama", text: $editedNama)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Greeting")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("Greeting", text: $editedGreeting)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Profil")
                } footer: {
                    Text("Nama dan teks sapaan ditampilkan di halaman utama.")
                }

                // MARK: - Dana Darurat Section
                Section {
                    Stepper("Jumlah Bulan: \(editedJumlahBulan)", value: $editedJumlahBulan, in: 1...24)
                } header: {
                    Text("Dana Darurat")
                } footer: {
                    Text("Target dana darurat dihitung berdasarkan rata-rata pengeluaran bulanan dikalikan jumlah bulan.")
                }

                // MARK: - Data Section
                Section {
                    dataRow(title: "Pocket", count: pockets.count, icon: "wallet.pass.fill", color: .blue)
                    dataRow(title: "Pengeluaran", count: expenses.count, icon: "arrow.up.circle.fill", color: .red)
                    dataRow(title: "Pemasukan", count: incomes.count, icon: "arrow.down.circle.fill", color: .green)
                    dataRow(title: "Transfer", count: transferInternals.count, icon: "arrow.left.arrow.right.circle.fill", color: .orange)
                    dataRow(title: "Goal", count: goals.count, icon: "target", color: .purple)
                    dataRow(title: "Investasi", count: investasiHoldings.count, icon: "chart.line.uptrend.xyaxis", color: .cyan)
                    dataRow(title: "Terjadwal", count: expenseTerjadwals.count + incomeTerjadwals.count + transferInternalTerjadwals.count, icon: "calendar.badge.clock", color: .indigo)
                    dataRow(title: "Kategori", count: kategoriExpenses.count + kategoriIncomes.count, icon: "tag.fill", color: .teal)
                } header: {
                    Text("Statistik Data")
                }

                // MARK: - Danger Zone
                Section {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Reset Semua Data")
                        }
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("Menghapus semua data termasuk pocket, transaksi, kategori, goal, dan investasi. Tindakan ini tidak dapat dibatalkan.")
                        .font(.caption)
                }

                // MARK: - App Info
                Section {
                    HStack {
                        Text("Versi")
                        Spacer()
                        Text("2.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Aplikasi")
                }
            }
            .navigationTitle("Pengaturan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Batal") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Simpan") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if !hasLoadedProfile {
                    editedNama = userProfile?.nama ?? "User"
                    editedGreeting = userProfile?.greetingText ?? "Welcome back"
                    editedJumlahBulan = danaDaruratConfig?.jumlahBulan ?? 3
                    hasLoadedProfile = true
                }
            }
            .confirmationDialog(
                "Reset Semua Data?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset Semua Data", role: .destructive) {
                    resetAllData()
                }
                Button("Batal", role: .cancel) {}
            } message: {
                Text("Semua data pocket, transaksi, kategori, goal, dan investasi akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.")
            }
        }
    }

    // MARK: - Data Row

    private func dataRow(title: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(title)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
        }
    }

    // MARK: - Save Changes

    private func saveChanges() {
        if let profile = userProfile {
            profile.nama = editedNama
            profile.greetingText = editedGreeting
        } else {
            let newProfile = UserProfile(nama: editedNama, greetingText: editedGreeting)
            context.insert(newProfile)
        }

        if let config = danaDaruratConfig {
            config.jumlahBulan = editedJumlahBulan
        } else {
            let newConfig = DanaDaruratConfig(jumlahBulan: editedJumlahBulan)
            context.insert(newConfig)
        }

        try? context.save()
    }

    // MARK: - Reset All Data

    private func resetAllData() {
        expenses.forEach { context.delete($0) }
        incomes.forEach { context.delete($0) }
        transferInternals.forEach { context.delete($0) }
        pockets.forEach { context.delete($0) }
        kategoriExpenses.forEach { context.delete($0) }
        kategoriIncomes.forEach { context.delete($0) }
        expenseTerjadwals.forEach { context.delete($0) }
        incomeTerjadwals.forEach { context.delete($0) }
        transferInternalTerjadwals.forEach { context.delete($0) }
        goals.forEach { context.delete($0) }
        riwayatMencicils.forEach { context.delete($0) }
        investasiHoldings.forEach { context.delete($0) }
        budgetBulanans.forEach { context.delete($0) }
        rencanaAnggarans.forEach { context.delete($0) }
        asetNonFinansials.forEach { context.delete($0) }
        kategoriAsets.forEach { context.delete($0) }
        updateSaldos.forEach { context.delete($0) }
        debiturs.forEach { context.delete($0) }
        krediturs.forEach { context.delete($0) }
        fgis.forEach { context.delete($0) }

        // Reset profile to defaults instead of deleting
        if let profile = userProfile {
            profile.nama = "Dika"
            profile.greetingText = "Welcome back"
        }
        if let config = danaDaruratConfig {
            config.jumlahBulan = 3
        }

        try? context.save()

        // Update local state
        editedNama = "Dika"
        editedGreeting = "Welcome back"
        editedJumlahBulan = 3
    }
}
