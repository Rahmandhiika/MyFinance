import SwiftUI
import SwiftData

struct LanggananBulanIniCard: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Langganan.urutan) private var allLangganan: [Langganan]
    @Query(sort: \Pocket.urutan) private var allPocket: [Pocket]
    @Query private var allPembayaran: [PembayaranLangganan]

    // Pocket sheet state
    @State private var showPocketSheet = false
    @State private var pendingLangganan: Langganan? = nil
    @State private var selectedPocket: Pocket? = nil

    // Uncheck alert state
    @State private var showUncheckAlert = false
    @State private var uncheckTarget: Langganan? = nil

    private let accentGreen = Color(hex: "#22C55E")

    private var bulanIni: Int { Calendar.current.component(.month, from: Date()) }
    private var tahunIni: Int { Calendar.current.component(.year, from: Date()) }

    private var aktifLangganan: [Langganan] {
        // Urutan sesuai setting; yang sudah bayar turun ke bawah (display only)
        let base = allLangganan.filter { $0.isAktif }
        return base.sorted { a, b in
            let paidA = sudahBayar(a)
            let paidB = sudahBayar(b)
            if paidA != paidB { return !paidA }  // belum bayar naik ke atas
            return a.urutan < b.urutan
        }
    }

    private var totalBulanan: Decimal {
        aktifLangganan.reduce(0) { $0 + $1.nominal }
    }

    private var totalSudahBayar: Decimal {
        aktifLangganan.filter { sudahBayar($0) }.reduce(0) { $0 + $1.nominal }
    }

    private func pembayaran(for l: Langganan) -> PembayaranLangganan? {
        allPembayaran.first {
            $0.langganan?.id == l.id && $0.bulan == bulanIni && $0.tahun == tahunIni
        }
    }

    private func sudahBayar(_ l: Langganan) -> Bool {
        pembayaran(for: l) != nil
    }

    var body: some View {
        if aktifLangganan.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LANGGANAN BULAN INI")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.gray)
                            .tracking(0.5)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(totalSudahBayar.shortFormatted)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Text("/ \(totalBulanan.shortFormatted)")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                    Spacer()
                    // Progress lunas
                    let pct = totalBulanan > 0
                        ? Double(truncating: (totalSudahBayar / totalBulanan * 100) as NSDecimalNumber)
                        : 0
                    Text(String(format: "%.0f%%", pct))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accentGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(accentGreen.opacity(0.12))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                Divider().background(Color.white.opacity(0.06))

                // List items
                ForEach(aktifLangganan) { l in
                    let paid = sudahBayar(l)
                    Button {
                        if paid {
                            uncheckTarget = l
                            showUncheckAlert = true
                        } else {
                            pendingLangganan = l
                            selectedPocket = allPocket.filter { $0.kelompokPocket == .biasa }.first
                            showPocketSheet = true
                        }
                    } label: {
                        langgananRow(l, paid: paid)
                    }
                    .buttonStyle(.plain)

                    if l.id != aktifLangganan.last?.id {
                        Divider().background(Color.white.opacity(0.05)).padding(.leading, 56)
                    }
                }
            }
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            // Pocket sheet
            .sheet(isPresented: $showPocketSheet) {
                pocketPickerSheet
            }
            // Uncheck alert
            .alert("Batalkan Pembayaran?", isPresented: $showUncheckAlert) {
                Button("Batalkan Pembayaran", role: .destructive) {
                    if let l = uncheckTarget { cancelPembayaran(l) }
                }
                Button("Tidak", role: .cancel) { uncheckTarget = nil }
            } message: {
                if let l = uncheckTarget {
                    Text("Pembayaran \(l.nama) akan dibatalkan dan saldo pocket dikembalikan.")
                }
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func langgananRow(_ l: Langganan, paid: Bool) -> some View {
        HStack(spacing: 12) {
            // Logo
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(paid
                          ? accentGreen.opacity(0.15)
                          : Color(hex: l.kategori?.warna ?? "#6B7280").opacity(0.15))
                    .frame(width: 36, height: 36)
                if let data = l.logo, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .opacity(paid ? 0.7 : 1)
                } else {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(paid ? accentGreen : Color(hex: l.kategori?.warna ?? "#6B7280"))
                }
            }

            // Name + tanggal
            VStack(alignment: .leading, spacing: 2) {
                Text(l.nama)
                    .font(.subheadline.weight(paid ? .bold : .medium))
                    .foregroundStyle(paid ? .white : .white.opacity(0.85))
                Text("Tgl \(l.tanggalTagih)")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }

            Spacer()

            Text(l.nominal.idrFormatted)
                .font(.subheadline.weight(paid ? .bold : .regular))
                .foregroundStyle(paid ? .white : .white.opacity(0.7))

            // Checkbox
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(paid ? accentGreen : Color.white.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                if paid {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(accentGreen)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(paid ? accentGreen.opacity(0.06) : Color.clear)
    }

    // MARK: - Pocket Picker Sheet

    private var biasaPockets: [Pocket] {
        allPocket.filter { $0.kelompokPocket == .biasa }
    }

    @ViewBuilder
    private var pocketPickerSheet: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()
                VStack(spacing: 0) {
                    if let l = pendingLangganan {
                        // Summary
                        VStack(spacing: 6) {
                            if let data = l.logo, let uiImg = UIImage(data: data) {
                                Image(uiImage: uiImg)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: l.kategori?.warna ?? "#6B7280").opacity(0.2))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color(hex: l.kategori?.warna ?? "#6B7280"))
                                }
                            }
                            Text(l.nama)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(l.nominal.idrFormatted)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(accentGreen)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }

                    Divider().background(Color.white.opacity(0.08))

                    Text("BAYAR DARI POCKET")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.gray)
                        .tracking(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    ScrollView {
                        VStack(spacing: 1) {
                            ForEach(biasaPockets) { p in
                                Button {
                                    selectedPocket = p
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: "#22C55E").opacity(0.12))
                                                .frame(width: 36, height: 36)
                                            if let data = p.logo, let uiImg = UIImage(data: data) {
                                                Image(uiImage: uiImg)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 36, height: 36)
                                                    .clipShape(Circle())
                                            } else {
                                                Image(systemName: "creditcard.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundStyle(Color(hex: "#22C55E"))
                                            }
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(p.nama)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.white)
                                            Text(p.saldo.idrDecimalFormatted)
                                                .font(.caption)
                                                .foregroundStyle(.gray)
                                        }
                                        Spacer()
                                        if selectedPocket?.id == p.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(accentGreen)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(selectedPocket?.id == p.id
                                                ? accentGreen.opacity(0.06)
                                                : Color.white.opacity(0.05))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 16)
                    }

                    // Confirm button
                    Button {
                        if let l = pendingLangganan, let p = selectedPocket {
                            konfirmasiBayar(l, pocket: p)
                        }
                        showPocketSheet = false
                    } label: {
                        Text("Konfirmasi Bayar")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(selectedPocket != nil ? accentGreen : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(selectedPocket == nil)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Bayar Langganan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Batal") {
                        showPocketSheet = false
                        pendingLangganan = nil
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    // MARK: - Actions

    private func konfirmasiBayar(_ l: Langganan, pocket: Pocket) {
        // Buat transaksi pengeluaran
        let transaksi = Transaksi(
            tanggal: Date(),
            nominal: l.nominal,
            tipe: .pengeluaran,
            subTipe: .normal,
            pocket: pocket,
            catatan: "Langganan: \(l.nama)"
        )
        transaksi.kategori = l.kategori
        pocket.saldo -= l.nominal
        context.insert(transaksi)

        // Simpan pembayaran
        let bayar = PembayaranLangganan(
            langganan: l,
            bulan: bulanIni,
            tahun: tahunIni,
            pocket: pocket,
            transaksiID: transaksi.id
        )
        context.insert(bayar)
        try? context.save()

        pendingLangganan = nil
        selectedPocket = nil
    }

    private func cancelPembayaran(_ l: Langganan) {
        guard let bayar = pembayaran(for: l) else { return }

        // Kembalikan saldo pocket
        if let pocket = bayar.pocket, let tid = bayar.transaksiID {
            pocket.saldo += l.nominal
            // Hapus transaksi
            var descriptor = FetchDescriptor<Transaksi>(
                predicate: #Predicate { $0.id == tid }
            )
            descriptor.fetchLimit = 1
            if let trx = try? context.fetch(descriptor).first {
                context.delete(trx)
            }
        }

        context.delete(bayar)
        try? context.save()
        uncheckTarget = nil
    }
}
