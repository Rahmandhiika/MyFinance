import SwiftUI
import SwiftData

struct AnggaranManagementView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allAnggaran: [Anggaran]
    @Query private var allTransaksi: [Transaksi]

    @State private var selectedMonth = Date()
    @State private var showAdd = false
    @State private var editingAnggaran: Anggaran? = nil

    var currentAnggaran: [Anggaran] {
        let cal = Calendar.current
        let m = cal.component(.month, from: selectedMonth)
        let y = cal.component(.year, from: selectedMonth)
        return allAnggaran.filter { a in
            guard a.tipeAnggaran == .bulanan else { return false }
            return (a.bulan == m && a.tahun == y) || a.berulang
        }
    }

    var totalAnggaran: Decimal { currentAnggaran.reduce(0) { $0 + $1.nominal } }

    func terpakai(for anggaran: Anggaran) -> Decimal {
        allTransaksi
            .filter { t in
                t.tipe == .pengeluaran &&
                (anggaran.kategori == nil || t.kategori?.id == anggaran.kategori?.id) &&
                t.tanggal.isSameMonth(as: selectedMonth)
            }
            .reduce(0) { $0 + $1.nominal }
    }

    var totalTerpakai: Decimal { currentAnggaran.reduce(0) { $0 + terpakai(for: $1) } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Navigasi bulan
                MonthNavigator(selectedMonth: $selectedMonth)
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 12) {
                        // Summary card
                        if totalAnggaran > 0 {
                            let progress = Double(truncating: (totalTerpakai / totalAnggaran) as NSDecimalNumber)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("TERPAKAI DARI")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                        Text(totalTerpakai.idrFormatted)
                                            .font(.title2.bold())
                                            .foregroundStyle(progress > 1 ? .red : Color(hex: "#FBBF24"))
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("TOTAL ANGGARAN")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                        Text(totalAnggaran.idrFormatted)
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                    }
                                }
                                ProgressBarView(progress: min(progress, 1), color: Color(hex: "#FBBF24"), height: 6)
                                Text("\(Int(progress * 100))% Terpakai")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }

                        // Anggaran list
                        if currentAnggaran.isEmpty {
                            ContentUnavailableView(
                                "Belum Ada Anggaran",
                                systemImage: "chart.bar",
                                description: Text("Tambah anggaran untuk bulan ini")
                            )
                            .padding(.top, 40)
                        } else {
                            VStack(spacing: 0) {
                                HStack {
                                    Label("TIAP BULAN", systemImage: "calendar")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 8)

                                ForEach(currentAnggaran) { anggaran in
                                    let tp = terpakai(for: anggaran)
                                    let prog = anggaran.nominal > 0
                                        ? Double(truncating: (tp / anggaran.nominal) as NSDecimalNumber)
                                        : 0.0

                                    Button { editingAnggaran = anggaran } label: {
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack {
                                                Label(
                                                    anggaran.kategori?.nama ?? "Keseluruhan",
                                                    systemImage: anggaran.kategori?.ikon ?? "chart.pie"
                                                )
                                                .foregroundStyle(.white)
                                                Spacer()
                                                Text("\(Int(prog * 100))%")
                                                    .foregroundStyle(prog > 1 ? .red : Color(hex: "#FBBF24"))
                                                    .font(.subheadline.bold())
                                                Image(systemName: "pencil")
                                                    .foregroundStyle(.gray)
                                                    .font(.caption)
                                                Button {
                                                    context.delete(anggaran)
                                                    try? context.save()
                                                } label: {
                                                    Image(systemName: "trash")
                                                        .foregroundStyle(.gray)
                                                        .font(.caption)
                                                }
                                            }
                                            ProgressBarView(progress: min(prog, 1), color: Color(hex: "#FBBF24"), height: 4)
                                            HStack {
                                                VStack(alignment: .leading) {
                                                    Text("TERPAKAI DARI").font(.caption2).foregroundStyle(.gray)
                                                    Text(tp.idrFormatted).font(.caption).foregroundStyle(.white)
                                                }
                                                Spacer()
                                                VStack(alignment: .trailing) {
                                                    Text("ANGGARAN").font(.caption2).foregroundStyle(.gray)
                                                    Text(anggaran.nominal.idrFormatted).font(.caption).foregroundStyle(.white)
                                                }
                                            }
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .padding(.horizontal)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .background(Color(hex: "#0D0D0D"))
            .navigationTitle("Anggaran")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Tutup") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Label("Tambah", systemImage: "plus")
                    }
                    .tint(Color(hex: "#FBBF24"))
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddEditAnggaranView(selectedMonth: selectedMonth)
        }
        .sheet(item: $editingAnggaran) { a in
            AddEditAnggaranView(anggaran: a, selectedMonth: selectedMonth)
        }
        .preferredColorScheme(.dark)
    }
}
