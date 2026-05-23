import SwiftUI
import SwiftData

struct AddEditTransaksiSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @Query(sort: \Pocket.urutan) private var allPockets: [Pocket]
    @Query(sort: \Kategori.urutan) private var allKategoris: [Kategori]
    @Query private var allTargets: [Target]

    private var adminKategori: Kategori? {
        allKategoris.first { $0.isAdmin && $0.tipe == .pengeluaran }
    }
    private var nabungKategori: Kategori? {
        allKategoris.first { $0.isNabung && $0.tipe == .pengeluaran }
    }
    private var wishlistKategori: Kategori? {
        allKategoris.first { $0.isWishlist && $0.tipe == .pengeluaran }
    }
    private var wishlistTargets: [Target] {
        allTargets.filter { !$0.isSelesai && $0.jenisTarget == .biasa }
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
    @State private var wishlistDanaTarget: Decimal = 0

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
        guard selectedPocket != nil else { return false }
        if subTipe == .beliWishlist { return nominal > 0 && selectedTarget != nil }
        return nominal > 0
    }

    private var nominalDisplay: String {
        nominal > 0 ? nominal.idrFormatted : "Rp 0"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bgApp.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Large nominal display
                        VStack(spacing: 6) {
                            Text(nominalDisplay)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(theme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)

                            CalcInputField(value: $nominal)
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
                                    ForEach(SubTipeTransaksi.formCases) { st in
                                        SubTipeChip(label: st.displayName, isSelected: subTipe == st)
                                            .onTapGesture {
                                                subTipe = st
                                                selectedTarget = nil
                                                selectedKategori = nil
                                                wishlistDanaTarget = 0
                                            }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Nabung: target picker biasa + investasi
                        if tipe == .pengeluaran && subTipe == .simpanKeTarget {
                            VStack(alignment: .leading, spacing: 10) {
                                sectionLabel("Wishlist / Target")
                                let nabungTargets = allTargets.filter { !$0.isSelesai }
                                if nabungTargets.isEmpty {
                                    Text("Belum ada wishlist / target aktif")
                                        .font(.caption)
                                        .foregroundStyle(theme.textSecondary)
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(theme.bgCard)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                } else {
                                    LazyVGrid(
                                        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                                        spacing: 10
                                    ) {
                                        ForEach(nabungTargets) { target in
                                            WishlistPickerCard(
                                                target: target,
                                                isSelected: selectedTarget?.id == target.id
                                            )
                                            .onTapGesture {
                                                selectedTarget = selectedTarget?.id == target.id ? nil : target
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Beli Wishlist section
                        if tipe == .pengeluaran && subTipe == .beliWishlist {
                            beliWishlistSection
                        }

                        // Kategori grid (hanya normal)
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
                                    Spacer()
                                    adminQuickPick($biayaAdmin)
                                }
                                CalcInputField(value: $biayaAdmin, placeholder: "Ketuk untuk input biaya admin")

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
                                .foregroundStyle(theme.textPrimary)
                                .padding(12)
                                .background(theme.separator)
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
            .toolbarBackground(theme.bgApp, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme == .dark ? .dark : .light, for: .navigationBar)
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
        .preferredColorScheme(theme.colorScheme)
    }

    // MARK: - Beli Wishlist Section

    private var beliWishlistSection: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Picker wishlist — 2-column photo card grid
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Pilih Wishlist")
                if wishlistTargets.isEmpty {
                    Text("Belum ada wishlist aktif")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(wishlistTargets) { target in
                            WishlistPickerCard(
                                target: target,
                                isSelected: selectedTarget?.id == target.id
                            )
                            .onTapGesture {
                                let isSame = selectedTarget?.id == target.id
                                selectedTarget = isSame ? nil : target
                                if !isSame {
                                    nominal = target.targetNominal
                                    wishlistDanaTarget = 0
                                }
                            }
                        }
                    }
                }
            }

            // Info harga target + field harga beli
            if let target = selectedTarget {
                VStack(alignment: .leading, spacing: 10) {

                    // Harga target info
                    HStack(spacing: 8) {
                        Image(systemName: "tag.fill")
                            .font(.caption)
                            .foregroundStyle(Color(hex: target.warna))
                        Text("Harga Target")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.textSecondary)
                        Spacer()
                        Text(target.targetNominal > 0 ? target.targetNominal.idrFormatted : "Tidak diset")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color(hex: target.warna))
                    }
                    .padding(12)
                    .background(Color(hex: target.warna).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Harga beli (nominal)
                    VStack(alignment: .leading, spacing: 6) {
                        sectionLabel("Harga Beli (aktual)")
                        CalcInputField(value: $nominal)
                        if target.targetNominal > 0 && nominal != target.targetNominal {
                            let selisih = nominal - target.targetNominal
                            HStack(spacing: 4) {
                                Image(systemName: selisih > 0 ? "arrow.up.circle" : "arrow.down.circle")
                                    .font(.caption2)
                                    .foregroundStyle(selisih > 0 ? Color(hex: "#F59E0B") : Color(hex: "#22C55E"))
                                Text("\(selisih > 0 ? "+" : "")\(selisih.idrFormatted) dari harga target")
                                    .font(.caption2)
                                    .foregroundStyle(selisih > 0 ? Color(hex: "#F59E0B") : Color(hex: "#22C55E"))
                            }
                        }
                    }

                    // Dana dari wishlist (hanya jika ada linkedPocket dengan saldo)
                    if let linked = target.linkedPocket, linked.saldo > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                sectionLabel("Dana dari Wishlist (opsional)")
                                Spacer()
                                Text("Tersimpan: \(linked.saldo.idrFormatted)")
                                    .font(.caption2)
                                    .foregroundStyle(theme.textSecondary)
                            }
                            CalcInputField(value: $wishlistDanaTarget, placeholder: "0 — tidak pakai dana tabungan")
                                .onChange(of: wishlistDanaTarget) { _, val in
                                    let cap = min(linked.saldo, nominal)
                                    if val > cap { wishlistDanaTarget = cap }
                                }
                            if wishlistDanaTarget > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle")
                                        .font(.caption2).foregroundStyle(.gray)
                                    let sisaDariPocket = nominal - wishlistDanaTarget
                                    Text("Keluar dari pocket: \(sisaDariPocket.idrFormatted) · Dari tabungan: \(wishlistDanaTarget.idrFormatted)")
                                        .font(.caption2).foregroundStyle(.gray)
                                }
                            }
                        }
                    }
                }
                .padding(14)
                .background(theme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Admin Quick Pick

    @ViewBuilder
    private func adminQuickPick(_ binding: Binding<Decimal>) -> some View {
        let presets: [(String, Decimal)] = [("1rb", 1_000), ("2,5rb", 2_500)]
        HStack(spacing: 6) {
            ForEach(presets, id: \.0) { label, amount in
                Button {
                    binding.wrappedValue += amount
                } label: {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: "#F59E0B"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#F59E0B").opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
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
            wishlistDanaTarget = t.wishlistDanaTarget ?? 0
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
        guard nominal > 0 else { return }

        // Determine kategori berdasarkan sub tipe
        let finalKategori: Kategori?
        switch subTipe {
        case .beliWishlist:   finalKategori = wishlistKategori
        case .simpanKeTarget: finalKategori = nabungKategori
        default:              finalKategori = selectedKategori
        }

        if let existing = editingTransaksi {
            // Revert old pocket saldo
            if let oldPocket = existing.pocket {
                if existing.tipe == .pengeluaran {
                    if existing.subTipe == .beliWishlist {
                        // Pocket hanya kena (nominal - danaTarget)
                        let oldDana = existing.wishlistDanaTarget ?? 0
                        oldPocket.saldo += (existing.nominal - oldDana)
                        // Kembalikan dana ke linkedPocket target lama
                        if let oldGoalID = existing.goalID,
                           let oldTarget = allTargets.first(where: { $0.id == oldGoalID }),
                           oldDana > 0,
                           let linked = oldTarget.linkedPocket {
                            linked.saldo += oldDana
                            oldTarget.isSelesai = false
                        }
                    } else {
                        oldPocket.saldo += existing.nominal
                    }
                } else {
                    oldPocket.saldo -= existing.nominal
                }
            }
            // Update fields
            existing.nominal = nominal
            existing.tipe = tipe
            existing.subTipe = subTipe
            existing.kategori = finalKategori
            existing.pocket = pocket
            existing.catatan = catatan.isEmpty ? nil : catatan
            existing.tanggal = tanggal
            existing.goalID = selectedTarget?.id
            existing.wishlistDanaTarget = subTipe == .beliWishlist && wishlistDanaTarget > 0
                ? wishlistDanaTarget : nil

            // Re-apply beliWishlist effect untuk edit
            if subTipe == .beliWishlist, let target = selectedTarget {
                if wishlistDanaTarget > 0, let linked = target.linkedPocket {
                    linked.saldo -= wishlistDanaTarget
                }
                target.isSelesai = true
            }
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
            t.wishlistDanaTarget = subTipe == .beliWishlist && wishlistDanaTarget > 0
                ? wishlistDanaTarget : nil
            modelContext.insert(t)

            // SimpanKeTarget record (hanya untuk simpanKeTarget)
            if tipe == .pengeluaran, subTipe == .simpanKeTarget, let target = selectedTarget {
                let record = SimpanKeTarget(
                    target: target,
                    tanggal: tanggal,
                    nominal: nominal,
                    catatan: catatan.isEmpty ? nil : catatan
                )
                modelContext.insert(record)
                // Tambah saldo linkedPocket target
                if let linkedPocket = target.linkedPocket {
                    linkedPocket.saldo += nominal
                }
            }

            // Beli Wishlist: kurangi linkedPocket, tandai target selesai
            if subTipe == .beliWishlist, let target = selectedTarget {
                if wishlistDanaTarget > 0, let linked = target.linkedPocket {
                    linked.saldo -= wishlistDanaTarget
                }
                target.isSelesai = true
            }
        }

        // Adjust pocket saldo
        if tipe == .pengeluaran {
            // beliWishlist: pocket hanya kena bagian yang tidak ditanggung dana wishlist
            let deductAmount = subTipe == .beliWishlist ? (nominal - wishlistDanaTarget) : nominal
            pocket.saldo -= deductAmount
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
    @Environment(\.appTheme) private var theme

    var body: some View {
        Text(label)
            .font(.caption.weight(.medium))
            .foregroundStyle(isSelected ? .black : theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color(hex: "#22C55E") : theme.bgCard)
            .clipShape(Capsule())
    }
}

// MARK: - Target chip (used for Nabung picker)

private struct TargetChip: View {
    let target: Target
    let isSelected: Bool
    @Environment(\.appTheme) private var theme

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
                .foregroundStyle(isSelected ? .black : theme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color(hex: target.warna) : theme.bgCard)
        .clipShape(Capsule())
    }
}

// MARK: - Wishlist Picker Card (2-column photo card)

private struct WishlistPickerCard: View {
    let target: Target
    let isSelected: Bool
    @Environment(\.appTheme) private var theme

    private var targetColor: Color { Color(hex: target.warna) }
    private var progress: Double { min(target.progressPersen / 100.0, 1.0) }
    private var hasFoto: Bool { target.fotoData != nil }

    var body: some View {
        // Color anchor — ini yang menentukan ukuran card, semua overlay ikut dimensi ini
        Color.clear
            .frame(height: 130)
            .overlay {
                // Background: foto atau warna solid
                if let data = target.fotoData, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    ZStack(alignment: .leading) {
                        theme.bgCard
                        Rectangle()
                            .fill(targetColor)
                            .frame(width: 3)
                    }
                }
            }
            // Gradient overlay
            .overlay {
                LinearGradient(
                    colors: hasFoto
                        ? [.clear, Color.black.opacity(0.45), Color.black.opacity(0.85)]
                        : [.clear, Color.black.opacity(0.1), Color.black.opacity(0.38)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            // Content — selalu di bawah, ukuran tidak mempengaruhi card height
            .overlay(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    // Icon / emoji
                    ZStack {
                        Circle()
                            .fill(hasFoto ? Color.black.opacity(0.3) : targetColor.opacity(0.2))
                            .frame(width: 28, height: 28)
                        if let emoji = target.ikonCustom, !emoji.isEmpty {
                            Text(emoji).font(.system(size: 13))
                        } else {
                            Image(systemName: target.ikon)
                                .font(.system(size: 11))
                                .foregroundStyle(hasFoto ? .white : targetColor)
                        }
                    }

                    // Nama — 1 baris saja agar tinggi konsisten
                    Text(target.nama)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.5), radius: 3)

                    HStack(spacing: 0) {
                        // Persentase
                        Text(target.targetNominal > 0
                             ? "\(String(format: "%.0f", target.progressPersen))%"
                             : "—")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(hasFoto ? .white.opacity(0.8) : targetColor)

                        Spacer()
                    }

                    // Mini progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 3)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(hasFoto ? Color.white : targetColor)
                                .frame(width: geo.size.width * progress, height: 3)
                        }
                    }
                    .frame(height: 3)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isSelected ? targetColor : Color.clear,
                    lineWidth: 3
                )
        }
        // Checkmark overlay saat selected
        .overlay(alignment: .topTrailing) {
            if isSelected {
                ZStack {
                    Circle()
                        .fill(targetColor)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(8)
            }
        }
    }
}
