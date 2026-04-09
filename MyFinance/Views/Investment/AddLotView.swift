import SwiftUI
import SwiftData

struct AddLotView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var holdings: [InvestmentHolding]

    let holdingID: UUID

    @State private var shares: Double = 0
    @State private var buyPrice: Double = 0
    @State private var buyDate = Date()
    @State private var fee: Double = 0

    private var holding: InvestmentHolding? { holdings.first { $0.id == holdingID } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Jumlah") {
                    CurrencyInputField(
                        label: holding?.assetType == .stock ? "Jumlah Lot (1 lot = 100 lembar)" : "Jumlah Unit",
                        amount: $shares
                    )
                }
                Section("Harga & Waktu") {
                    CurrencyInputField(label: "Harga Beli per Lembar/Unit", amount: $buyPrice)
                    DatePicker("Tanggal Beli", selection: $buyDate, displayedComponents: .date)
                    CurrencyInputField(label: "Fee / Komisi", amount: $fee)
                }
                Section("Estimasi") {
                    let actualShares = (holding?.assetType == .stock ? shares * 100 : shares)
                    let totalCost = actualShares * buyPrice + fee
                    HStack {
                        Text("Total Modal")
                        Spacer()
                        Text(totalCost.idrFormatted).bold()
                    }
                }
            }
            .navigationTitle("Tambah Lot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }.disabled(shares == 0 || buyPrice == 0)
                }
            }
        }
    }

    private func save() {
        let actualShares = holding?.assetType == .stock ? shares * 100 : shares
        let lot = StockLot(holdingID: holdingID, shares: actualShares, buyPrice: buyPrice, buyDate: buyDate, fee: fee)
        context.insert(lot)
        try? context.save()
        dismiss()
    }
}
