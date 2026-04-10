import SwiftUI
import SwiftData

struct DanaDaruratConfigView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var configs: [DanaDaruratConfig]

    @State private var jumlahBulan: Int = 3
    @State private var selectedPrioritas: Set<String> = ["p0", "p1", "p2"]

    private var allPrioritas: [(String, Prioritas)] = [
        ("p0", .p0), ("p1", .p1), ("p2", .p2), ("p3", .p3), ("p4", .p4), ("blank", .blank)
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Dana darurat dihitung berdasarkan rata-rata pengeluaran bulanan dari kategori dengan prioritas yang dipilih, dikalikan jumlah bulan target.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Target Jumlah Bulan") {
                    Stepper("\(jumlahBulan) bulan", value: $jumlahBulan, in: 1...24)
                    Text("Rekomendasi: 3-6 bulan untuk karyawan, 6-12 bulan untuk freelancer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Prioritas Pengeluaran Dihitung") {
                    ForEach(allPrioritas, id: \.0) { raw, prioritas in
                        HStack {
                            Circle()
                                .fill(prioritas.color)
                                .frame(width: 12, height: 12)
                            Text(prioritas == .blank ? "Tanpa Prioritas" : prioritas.displayName)
                                .font(.subheadline)
                            Spacer()
                            if selectedPrioritas.contains(raw) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .font(.caption.bold())
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedPrioritas.contains(raw) {
                                if selectedPrioritas.count > 1 {
                                    selectedPrioritas.remove(raw)
                                }
                            } else {
                                selectedPrioritas.insert(raw)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Konfigurasi Dana Darurat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        if let config = configs.first {
            jumlahBulan = config.jumlahBulan
            selectedPrioritas = Set(config.prioritasIncluded)
        }
    }

    private func save() {
        if let config = configs.first {
            config.jumlahBulan = jumlahBulan
            config.prioritasIncluded = Array(selectedPrioritas)
        } else {
            let config = DanaDaruratConfig(
                jumlahBulan: jumlahBulan,
                prioritasIncluded: Array(selectedPrioritas)
            )
            context.insert(config)
        }
        try? context.save()
        dismiss()
    }
}
