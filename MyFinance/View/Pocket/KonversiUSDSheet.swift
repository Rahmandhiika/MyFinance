import SwiftUI
import SwiftData

struct KonversiUSDSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    let pocket: Pocket

    enum Arah: String, CaseIterable, Identifiable {
        case idrKeUSD = "IDR → USD"
        case usdKeIDR = "USD → IDR"
        var id: String { rawValue }
    }

    @State private var arah: Arah = .idrKeUSD
    @State private var tanggal: Date = Date()
    @State private var isFetchingKurs = false

    // IDR → USD fields
    @State private var totalIDRKeluar: Decimal = 0
    @State private var conversionFee: Decimal = 0
    @State private var tax: Decimal = 0
    @State private var kursKonversi: Decimal = 0

    // USD → IDR fields
    @State private var usdKeluar: Decimal = 0
    @State private var kursJual: Decimal = 0
    @State private var feeJual: Decimal = 0
    @State private var taxJual: Decimal = 0

    // MARK: - Computed

    // IDR→USD: USD = (totalIDR - fee - tax) / kurs
    private var usdDiterima: Decimal {
        guard kursKonversi > 0, totalIDRKeluar > 0 else { return 0 }
        let netIDR = totalIDRKeluar - conversionFee - tax
        return netIDR > 0 ? netIDR / kursKonversi : 0
    }

    // USD→IDR: IDR = (usd × kurs) - fee - tax
    private var idrDiterima: Decimal {
        guard kursJual > 0, usdKeluar > 0 else { return 0 }
        let gross = usdKeluar * kursJual
        return max(gross - feeJual - taxJual, 0)
    }

    private var canSave: Bool {
        switch arah {
        case .idrKeUSD:
            return totalIDRKeluar > 0 && kursKonversi > 0
                && totalIDRKeluar <= pocket.saldo
                && usdDiterima > 0
        case .usdKeIDR:
            return usdKeluar > 0 && kursJual > 0
                && usdKeluar <= pocket.saldoUSD
                && idrDiterima > 0
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bgApp.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Saldo header
                        saldoHeader
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        // Arah toggle
                        arahPicker
                            .padding(.horizontal, 16)

                        // Form sesuai arah
                        if arah == .idrKeUSD {
                            idrKeUSDForm
                        } else {
                            usdKeIDRForm
                        }

                        // Preview hasil
                        previewCard
                            .padding(.horizontal, 16)

                        // CTA
                        Button(action: simpanKonversi) {
                            Text("Konfirmasi Konversi")
                                .font(.headline).foregroundStyle(.black)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(canSave ? Color(hex: "#F97316") : theme.separator)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!canSave)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Konversi Mata Uang")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.bgApp, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }.foregroundStyle(.gray)
                }
            }
            .task { await autoFetchKurs() }
        }
        .preferredColorScheme(theme.colorScheme)
    }

    // MARK: - Saldo Header

    private var saldoHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SALDO IDR").font(.caption2).foregroundStyle(.gray).tracking(0.5)
                Text(pocket.saldo.idrDecimalFormatted)
                    .font(.subheadline.weight(.bold)).foregroundStyle(theme.textPrimary)
            }
            Spacer()
            Image(systemName: "arrow.2.squarepath")
                .font(.title3).foregroundStyle(Color(hex: "#F97316"))
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("SALDO USD").font(.caption2).foregroundStyle(.gray).tracking(0.5)
                Text("$\(pocket.saldoUSD.unitFormatted(2))")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(pocket.saldoUSD > 0 ? Color(hex: "#F97316") : theme.textSecondary.opacity(0.5))
            }
        }
        .padding(14)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Arah Picker

    private var arahPicker: some View {
        HStack(spacing: 0) {
            ForEach(Arah.allCases) { a in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { arah = a }
                } label: {
                    Text(a.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(arah == a ? .black : theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(arah == a ? Color(hex: "#F97316") : Color.clear)
                }
            }
        }
        .background(theme.separator)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - IDR → USD Form

    private var idrKeUSDForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            formField(label: "TOTAL IDR DIKELUARKAN") {
                idrInput($totalIDRKeluar)
                if totalIDRKeluar > pocket.saldo {
                    Text("⚠ Melebihi saldo IDR")
                        .font(.caption2).foregroundStyle(Color(hex: "#EF4444"))
                }
            }

            HStack(spacing: 12) {
                formField(label: "CONVERSION FEE (IDR)") {
                    idrInput($conversionFee)
                }
                formField(label: "TAX (IDR)") {
                    idrInput($tax)
                }
            }

            formField(label: "KURS (IDR/USD)") {
                kursField(binding: $kursKonversi, isFetching: isFetchingKurs) {
                    Task { await autoFetchKurs() }
                }
            }

            tanggalField
        }
        .padding(.horizontal, 16)
    }

    // MARK: - USD → IDR Form

    private var usdKeIDRForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            formField(label: "JUMLAH USD DIJUAL") {
                HStack(spacing: 8) {
                    Text("$").foregroundStyle(theme.textSecondary).font(.subheadline)
                    CurrencyInputField(value: $usdKeluar)
                }
                if usdKeluar > pocket.saldoUSD {
                    Text("⚠ Melebihi saldo USD ($\(pocket.saldoUSD.unitFormatted(2)))")
                        .font(.caption2).foregroundStyle(Color(hex: "#EF4444"))
                }
            }

            formField(label: "KURS JUAL (IDR/USD)") {
                kursField(binding: $kursJual, isFetching: isFetchingKurs) {
                    Task { await autoFetchKurs() }
                }
            }

            HStack(spacing: 12) {
                formField(label: "CONVERSION FEE (IDR)") {
                    idrInput($feeJual)
                }
                formField(label: "TAX (IDR)") {
                    idrInput($taxJual)
                }
            }

            tanggalField
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        let (valid, fromLabel, fromValue, toLabel, toValue, totalFeeStr): (Bool, String, String, String, String, String)

        if arah == .idrKeUSD {
            let fee = conversionFee + tax
            (valid, fromLabel, fromValue, toLabel, toValue, totalFeeStr) = (
                usdDiterima > 0,
                "IDR KELUAR",
                totalIDRKeluar.idrFormatted,
                "USD DITERIMA",
                "$\(usdDiterima.unitFormatted(2))",
                fee > 0 ? "Fee + Tax: \(fee.idrFormatted)" : ""
            )
        } else {
            let fee = feeJual + taxJual
            (valid, fromLabel, fromValue, toLabel, toValue, totalFeeStr) = (
                idrDiterima > 0,
                "USD KELUAR",
                "$\(usdKeluar.unitFormatted(2))",
                "IDR DITERIMA",
                idrDiterima.idrFormatted,
                fee > 0 ? "Fee + Tax: \(fee.idrFormatted)" : ""
            )
        }

        return Group {
            if valid {
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fromLabel).font(.caption2).foregroundStyle(.gray)
                            Text(fromValue).font(.subheadline.weight(.bold)).foregroundStyle(theme.textPrimary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(Color(hex: "#F97316"))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(toLabel).font(.caption2).foregroundStyle(.gray)
                            Text(toValue)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color(hex: "#F97316"))
                        }
                    }

                    if !totalFeeStr.isEmpty {
                        Divider().background(theme.separator)
                        HStack {
                            Text(totalFeeStr).font(.caption2).foregroundStyle(.gray)
                            Spacer()
                        }
                    }
                }
                .padding(14)
                .background(Color(hex: "#F97316").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#F97316").opacity(0.2), lineWidth: 1))
            }
        }
    }

    // MARK: - Reusable sub-views

    @ViewBuilder
    private func formField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.gray).tracking(0.5)
            content()
        }
    }

    @ViewBuilder
    private func idrInput(_ binding: Binding<Decimal>) -> some View {
        HStack(spacing: 8) {
            Text("Rp").foregroundStyle(theme.textSecondary).font(.subheadline)
            CurrencyInputField(value: binding, allowsDecimal: false)
        }
    }

    @ViewBuilder
    private func kursField(binding: Binding<Decimal>, isFetching: Bool, onFetch: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text("Rp").foregroundStyle(theme.textSecondary).font(.subheadline)
            CurrencyInputField(value: binding)
            Button(action: onFetch) {
                HStack(spacing: 3) {
                    if isFetching {
                        ProgressView().tint(Color(hex: "#F97316")).scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise").font(.caption2.weight(.semibold))
                    }
                    Text("Auto").font(.caption2.weight(.semibold))
                }
                .foregroundStyle(Color(hex: "#F97316"))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color(hex: "#F97316").opacity(0.12))
                .clipShape(Capsule())
            }
        }
    }

    private var tanggalField: some View {
        HStack {
            Text("TANGGAL").font(.caption).foregroundStyle(.gray).tracking(0.5)
            Spacer()
            DatePicker("", selection: $tanggal, displayedComponents: .date)
                .datePickerStyle(.compact).colorScheme(.dark).labelsHidden()
        }
    }

    // MARK: - Actions

    private func simpanKonversi() {
        guard canSave else { return }
        switch arah {
        case .idrKeUSD:
            pocket.saldo    -= totalIDRKeluar
            pocket.saldoUSD += usdDiterima
        case .usdKeIDR:
            pocket.saldoUSD -= usdKeluar
            pocket.saldo    += idrDiterima
        }
        try? modelContext.save()
        dismiss()
    }

    private func autoFetchKurs() async {
        isFetchingKurs = true
        if let k = await AsetPriceService.shared.fetchKursValas(.usd) {
            await MainActor.run {
                if kursKonversi == 0 { kursKonversi = k }
                if kursJual == 0     { kursJual = k }
            }
        }
        await MainActor.run { isFetchingKurs = false }
    }
}
