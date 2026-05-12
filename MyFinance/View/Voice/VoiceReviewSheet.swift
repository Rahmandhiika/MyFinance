import SwiftUI
import SwiftData

struct VoiceReviewSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @Query(filter: #Predicate<Pocket> { $0.isAktif }) private var pockets: [Pocket]
    @Query private var allKategoris: [Kategori]

    let parsed: ParsedResult
    let onDone: () -> Void

    // Editable form state
    @State private var tipe: TipeTransaksi = .pengeluaran
    @State private var nominal: Decimal = 0
    @State private var selectedKategori: Kategori? = nil
    @State private var selectedPocket: Pocket? = nil
    @State private var catatan: String = ""
    @State private var tanggal: Date = Date()

    // Derived
    private var filteredKategoris: [Kategori] {
        allKategoris.filter { $0.tipe == tipe }.sorted { $0.urutan < $1.urutan }
    }

    private var canSave: Bool {
        nominal > 0 && selectedPocket != nil
    }

    private var nominalDisplay: String {
        nominal > 0 ? nominal.idrFormatted : "Rp 0"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bgApp.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // Nominal display + input
                        VStack(spacing: 8) {
                            Text(nominalDisplay)
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(theme.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)

                            CalcInputField(value: $nominal)
                                .padding(.horizontal, 24)
                        }
                        .padding(.top, 12)

                        // Tipe segmented
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("Tipe Transaksi")
                            Picker("Tipe", selection: $tipe) {
                                ForEach(TipeTransaksi.allCases) { t in
                                    Text(t.displayName).tag(t)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: tipe) { _, _ in
                                selectedKategori = nil
                            }
                        }
                        .padding(.horizontal, 20)

                        // Kategori grid
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("Kategori")
                            if filteredKategoris.isEmpty {
                                Text("Belum ada kategori")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                    .padding(.horizontal, 4)
                            } else {
                                KategoriGridPicker(
                                    kategoris: filteredKategoris,
                                    selected: $selectedKategori
                                )
                            }
                        }
                        .padding(.horizontal, 20)

                        // Pocket chip picker
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("Pocket")
                            if pockets.isEmpty {
                                Text("Belum ada pocket")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                    .padding(.horizontal, 4)
                            } else {
                                PocketChipPicker(pockets: pockets, selected: $selectedPocket)
                            }
                        }
                        .padding(.horizontal, 20)

                        // Tanggal
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("Tanggal")
                            DatePicker("", selection: $tanggal, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .colorScheme(.dark)
                        }
                        .padding(.horizontal, 20)

                        // Catatan
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("Catatan")
                            TextField("Tulis catatan...", text: $catatan)
                                .foregroundStyle(theme.textPrimary)
                                .padding(12)
                                .background(theme.separator)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.horizontal, 20)

                        // Simpan CTA
                        Button {
                            save()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Simpan Transaksi")
                                    .fontWeight(.semibold)
                            }
                            .font(.body.weight(.semibold))
                            .foregroundStyle(canSave ? .black : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canSave ? Color(hex: "#22C55E") : theme.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(
                                color: canSave ? Color(hex: "#22C55E").opacity(0.35) : .clear,
                                radius: 10, y: 4
                            )
                        }
                        .disabled(!canSave)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Review Transaksi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.bgApp, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(.gray)
                }
            }
            .onAppear {
                populateFromParsed()
            }
        }
        .preferredColorScheme(theme.colorScheme)
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

    private func populateFromParsed() {
        tipe = parsed.tipe
        nominal = parsed.nominal
        catatan = parsed.catatan
        selectedPocket = parsed.matchedPocket
        selectedKategori = parsed.matchedKategori
    }

    private func save() {
        guard let pocket = selectedPocket else { return }

        let transaksi = Transaksi(
            tanggal: tanggal,
            nominal: nominal,
            tipe: tipe,
            subTipe: .normal,
            kategori: selectedKategori,
            pocket: pocket,
            catatan: catatan.isEmpty ? nil : catatan
        )
        modelContext.insert(transaksi)

        // Adjust pocket saldo
        if tipe == .pengeluaran {
            pocket.saldo -= nominal
        } else {
            pocket.saldo += nominal
        }

        try? modelContext.save()
        onDone()
        dismiss()
    }
}
