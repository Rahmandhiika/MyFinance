import SwiftUI
import SwiftData

struct LanggananManagementView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Langganan.urutan) private var allLangganan: [Langganan]

    @State private var showAdd = false
    @State private var editing: Langganan? = nil
    @State private var showReorder = false

    private var totalBulanan: Decimal {
        allLangganan.filter { $0.isAktif }.reduce(0) { $0 + $1.nominal }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()

                if allLangganan.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Header total
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("TOTAL PER BULAN")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.gray)
                                        .tracking(0.5)
                                    Text(totalBulanan.idrFormatted)
                                        .font(.title2.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                Text("\(allLangganan.filter { $0.isAktif }.count) AKTIF")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color(hex: "#22C55E"))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: "#22C55E").opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 16)

                            // List
                            VStack(spacing: 1) {
                                ForEach(allLangganan) { l in
                                    langgananRow(l)
                                    if l.id != allLangganan.last?.id {
                                        Divider().background(Color.white.opacity(0.06)).padding(.leading, 60)
                                    }
                                }
                            }
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Langganan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Selesai") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if allLangganan.count > 1 {
                            Button {
                                showReorder = true
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.subheadline)
                                    .foregroundStyle(.gray)
                            }
                        }
                        Button {
                            showAdd = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Tambah")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(hex: "#22C55E"))
                        }
                    }
                }
            }
            .sheet(isPresented: $showAdd) { AddEditLanggananView() }
            .sheet(item: $editing) { l in AddEditLanggananView(existing: l) }
            .sheet(isPresented: $showReorder) { LanggananReorderSheet() }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func langgananRow(_ l: Langganan) -> some View {
        HStack(spacing: 12) {
            // Logo
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: l.kategori?.warna ?? "#6B7280").opacity(0.15))
                    .frame(width: 44, height: 44)
                if let data = l.logo, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: l.kategori?.warna ?? "#6B7280"))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(l.nama)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Tgl \(l.tanggalTagih) tiap bulan")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            Spacer()

            Text(l.nominal.idrFormatted)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            Menu {
                Button { editing = l } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button {
                    l.isAktif.toggle()
                    try? context.save()
                } label: {
                    Label(l.isAktif ? "Nonaktifkan" : "Aktifkan",
                          systemImage: l.isAktif ? "pause.circle" : "play.circle")
                }
                Button(role: .destructive) {
                    context.delete(l)
                    try? context.save()
                } label: {
                    Label("Hapus", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundStyle(.gray)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .opacity(l.isAktif ? 1 : 0.4)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard.circle")
                .font(.system(size: 48))
                .foregroundStyle(.gray)
            Text("Belum ada langganan")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Tambah Netflix, Spotify, iCloud, dan\nlangganan bulanan lainnya.")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            Button { showAdd = true } label: {
                Text("+ Tambah Langganan")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#22C55E"))
                    .clipShape(Capsule())
            }
        }
    }
}
