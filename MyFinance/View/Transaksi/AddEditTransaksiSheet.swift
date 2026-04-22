import SwiftUI
import SwiftData

struct AddEditTransaksiSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Pocket.urutan) private var allPockets: [Pocket]
    @Query(sort: \Kategori.urutan) private var allKategoris: [Kategori]
    @Query private var allTargets: [Target]

    private var adminKategori: Kategori? {
        allKategoris.first { $0.isAdmin && $0.tipe == .pengeluaran }
    }

    private var nabungKategori: Kategori? {
        allKategoris.first { $0.isNabung && $0.tipe == .pengeluaran }
    }

    // Edit mode
    private let editingTransaksi: Transaksi?

    // Pre-fill support (for opening from TargetDetailSheet)
    private let prefilledSubTipe: SubTipeTransaksi?
    private let prefilledTargetID: UUID?

    // Form state
    @State private var nominal: Decimal = 0
    @State private var tipe: TipeTransaksi = .pengeluaran
    @State private var subTipe: SubTipeTransaksi = .normal
    @State private var selectedKategori: Kategori? = nil
    @State private var selectedPocket: Pocket? = nil
    @State private var selectedTarget: Target? = nil
    @State private var catatan: String = ""
    @State private var tanggal: Date = Date()
    @State private var biayaAdmin: Decimal = 0

    init(transaksi: Transaksi? = nil,
         prefilledSubTipe: SubTipeTransaksi? = nil,
         prefilledTargetID: UUID? = nil) {
        self.editingTransaksi = transaksi
        self.prefilledSubTipe = prefilledSubTipe
        self.prefilledTargetID = prefilledTargetID
    }

    // MARK: - Computed

    private var activePockets: [Pocket] {
        allPockets.filter { $0.isAktif }
    }

    private var filteredKategoris: [Kategori] {
        allKategoris.filter { $0.tipe == tipe }
    }

    private var canSave: Bool {
        nominal > 0 && selectedPocket != nil
    }

    private var nominalDisplay: String {
        nominal > 0 ? nominal.idrFormatted : "Rp 0"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Large nominal display
                        VStack(spacing: 6) {
                            Text(nominalDisplay)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)

                            CurrencyInputField(value: $nominal)
                                .padding(.horizontal, 16)

                            // Quick amount buttons — only in ADD mode
                            if editingTransaksi == nil {
                                QuickAmountButtons(nominal: $nominal)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(.top, 8)

                        // Tipe segmented
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("Tipe")
                            Picker("Tipe", selection: $tipe) {
                                ForEach(TipeTransaksi.allCases) { t in
                                    Text(t.displayName).tag(t)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: tipe) { _, _ in
                                selectedKategori = nil
                                subTipe = .normal
                                selectedTarget = nil
                                biayaAdmin = 0
                            }
                        }
                        .padding(.horizontal, 16)

                        // SubTipe (only for pengeluaran)
                        if tipe == .pengeluaran {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionLabel("Sub Tipe")
                                HStack(spacing: 8) {
                                    ForEach(SubTipeTransaksi.allCases) { st in
                                        SubTipeChip(
                                            label: st.displayName,
                                            isSelected: subTipe == st
                                        )
                                        .onTapGesture {
                                            subTipe = st
                                            selectedTarget = nil
                                            selectedKategori = nil
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Target picker (when subTipe != normal)
                        if tipe == .pengeluaran && subTipe != .normal {
                            VStack(alignment: .leading, spacing: 10) {
                                sectionLabel("Target")
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(allTargets.filter { !$0.isSelesai }) { target in
                                            TargetChip(target: target, isSelected: selectedTarget?.id == target.id)
                                                .onTapGesture {
                                                    selectedTarget = selectedTarget?.id == target.id ? nil : target
                                                }
                                        }
                                    }
                                    .padding(.horizontal, 1)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Kategori grid (when subTipe == normal)
                        if subTipe == .normal {
                            VStack(alignment: .leading, spacing: 10) {
                                sectionLabel("Kategori")
                                KategoriGridPicker(
                                    kategoris: filteredKategoris,
                                    selected: $selectedKategori
                                )
                            }
                            .padding(.horizontal, 16)
                        }

                        // Pocket picker
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("Pocket")
                            PocketChipPicker(pockets: activePockets, selected: $selectedPocket)
                        }
                        .padding(.horizontal, 16)

                        // Biaya Admin (hanya add mode, hanya pengeluaran)
                        if editingTransaksi == nil && tipe == .pengeluaran {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "building.columns.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color(hex: "#F59E0B"))
                                    sectionLabel("Biaya Admin (opsional)")
                                }
                                HStack(spacing: 8) {
                                    Text("Rp")
                                        .foregroundStyle(.white.opacity(0.5))
                                        .font(.subheadline)
                                        .padding(.leading, 12)
                                    CurrencyInputField(value: $biayaAdmin)
                                }
                                .background(Color.white.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                if biayaAdmin > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "info.circle")
                                            .font(.caption2)
                                            .foregroundStyle(.gray)
                                        Text("Dicatat sebagai transaksi terpisah\(adminKategori != nil ? " kategori \"\(adminKategori!.nama)\"" : "") dari pocket yang sama")
                                            .font(.caption2)
                                            .foregroundStyle(.gray)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Catatan
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("Catatan")
                            TextField("Tulis catatan...", text: $catatan)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.horizontal, 16)

                        // Tanggal
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("Tanggal")
                            DatePicker("", selection: $tanggal, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .colorScheme(.dark)
                        }
                        .padding(.horizontal, 16)

                        Spacer(minLength: 32)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle(editingTransaksi == nil ? "Tambah Transaksi" : "Edit Transaksi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { saveTransaksi() }
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? Color(hex: "#22C55E") : .gray)
                        .disabled(!canSave)
                }
            }
            .onAppear { populateIfEditing() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.gray)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    // MARK: - Logic

    private func populateIfEditing() {
        if let t = editingTransaksi {
            nominal = t.nominal
            tipe = t.tipe
            subTipe = t.subTipe
            selectedKategori = t.kategori
            selectedPocket = t.pocket
            catatan = t.catatan ?? ""
            tanggal = t.tanggal
            if let gid = t.goalID {
                selectedTarget = allTargets.first { $0.id == gid }
            }
        } else if let preSubTipe = prefilledSubTipe {
            // Pre-fill for target flows
            tipe = .pengeluaran
            subTipe = preSubTipe
            if let pid = prefilledTargetID {
                selectedTarget = allTargets.first { $0.id == pid }
            }
        }
    }

    private func saveTransaksi() {
        guard let pocket = selectedPocket else { return }

        // Transaksi simpan/pakai target otomatis pakai kategori nabung
        let finalKategori: Kategori? = subTipe != .normal ? nabungKategori : selectedKategori

        if let existing = editingTransaksi {
            // Revert old pocket saldo
            if let oldPocket = existing.pocket {
                if existing.tipe == .pengeluaran {
                    oldPocket.saldo += existing.nominal
                } else {
                    oldPocket.saldo -= existing.nominal
                }
            }
            // Update
            existing.nominal = nominal
            existing.tipe = tipe
            existing.subTipe = subTipe
            existing.kategori = finalKategori
            existing.pocket = pocket
            existing.catatan = catatan.isEmpty ? nil : catatan
            existing.tanggal = tanggal
            existing.goalID = selectedTarget?.id
        } else {
            let t = Transaksi(
                tanggal: tanggal,
                nominal: nominal,
                tipe: tipe,
                subTipe: subTipe,
                kategori: finalKategori,
                pocket: pocket,
                catatan: catatan.isEmpty ? nil : catatan,
                goalID: selectedTarget?.id
            )
            modelContext.insert(t)

            // SimpanKeTarget record
            if tipe == .pengeluaran, let target = selectedTarget, subTipe != .normal {
                let record = SimpanKeTarget(
                    target: target,
                    tanggal: tanggal,
                    nominal: nominal,
                    catatan: catatan.isEmpty ? nil : catatan
                )
                modelContext.insert(record)

                // Tambah saldo pocket yang ter-link ke target biasa
                if subTipe == .simpanKeTarget, let linkedPocket = target.linkedPocket {
                    linkedPocket.saldo += nominal
                }
            }
        }

        // Adjust pocket saldo
        if tipe == .pengeluaran {
            pocket.saldo -= nominal
        } else {
            pocket.saldo += nominal
        }

        // Catat biaya admin sebagai transaksi terpisah (hanya add mode)
        if editingTransaksi == nil && tipe == .pengeluaran && biayaAdmin > 0 {
            let adminTransaksi = Transaksi(
                tanggal: tanggal,
                nominal: biayaAdmin,
                tipe: .pengeluaran,
                subTipe: .normal,
                pocket: pocket,
                catatan: "Biaya admin"
            )
            adminTransaksi.kategori = adminKategori
            pocket.saldo -= biayaAdmin
            modelContext.insert(adminTransaksi)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - SubTipe chip

private struct SubTipeChip: View {
    let label: String
    let isSelected: Bool

    var body: some View {
        Text(label)
            .font(.caption.weight(.medium))
            .foregroundStyle(isSelected ? .black : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color(hex: "#22C55E") : Color.white.opacity(0.1))
            .clipShape(Capsule())
    }
}

// MARK: - Target chip

private struct TargetChip: View {
    let target: Target
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            if let emoji = target.ikonCustom, !emoji.isEmpty {
                Text(emoji).font(.caption)
            } else {
                Image(systemName: target.ikon)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .black : Color(hex: target.warna))
            }
            Text(target.nama)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .black : .white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color(hex: target.warna) : Color.white.opacity(0.1))
        .clipShape(Capsule())
    }
}
