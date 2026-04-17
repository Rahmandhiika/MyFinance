import SwiftUI
import SwiftData

struct LanggananReorderSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Langganan.urutan) private var allLangganan: [Langganan]

    @State private var items: [Langganan] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()

                List {
                    ForEach(items) { l in
                        HStack(spacing: 12) {
                            // Logo
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: l.kategori?.warna ?? "#6B7280").opacity(0.15))
                                    .frame(width: 36, height: 36)
                                if let data = l.logo, let uiImg = UIImage(data: data) {
                                    Image(uiImage: uiImg)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 36, height: 36)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color(hex: l.kategori?.warna ?? "#6B7280"))
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.nama)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)
                                Text("Tgl \(l.tanggalTagih) · \(l.nominal.idrFormatted)")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }

                            Spacer()
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                        .listRowSeparatorTint(Color.white.opacity(0.06))
                        .opacity(l.isAktif ? 1 : 0.4)
                    }
                    .onMove { from, to in
                        items.move(fromOffsets: from, toOffset: to)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
            }
            .navigationTitle("Atur Urutan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Simpan") {
                        saveOrder()
                        dismiss()
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(hex: "#22C55E"))
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { items = allLangganan }
    }

    private func saveOrder() {
        for (index, l) in items.enumerated() {
            l.urutan = index
        }
        try? context.save()
    }
}
