import SwiftUI
import SwiftData

struct EditPortofolioSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let config: PortofolioConfig

    @State private var nama: String = ""
    @State private var warna: String = "#A78BFA"

    private let presetColors = [
        "#A78BFA", "#22C55E", "#3B82F6", "#F59E0B",
        "#EF4444", "#06B6D4", "#F97316", "#EC4899",
        "#10B981", "#8B5CF6", "#14B8A6", "#6366F1"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        // Live preview
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color(hex: warna))
                            Text(nama.isEmpty ? "—" : nama)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(hex: warna).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: warna).opacity(0.3), lineWidth: 1))

                        // Nama
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NAMA").font(.caption.weight(.semibold)).foregroundStyle(.gray).tracking(0.8)
                            TextField("Nama portofolio...", text: $nama)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Warna
                        VStack(alignment: .leading, spacing: 12) {
                            Text("WARNA").font(.caption.weight(.semibold)).foregroundStyle(.gray).tracking(0.8)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                                ForEach(presetColors, id: \.self) { hex in
                                    Button {
                                        warna = hex
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: hex))
                                                .frame(width: 48, height: 48)
                                            if warna == hex {
                                                Image(systemName: "checkmark")
                                                    .font(.subheadline.weight(.bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Portofolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }.foregroundStyle(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .disabled(nama.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                nama = config.nama
                warna = config.warna
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        let trimmed = nama.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let oldName = config.nama
        config.nama = trimmed
        config.warna = warna
        // Cascade rename to all assets
        if oldName != trimmed {
            if let allAsets = try? modelContext.fetch(FetchDescriptor<Aset>()) {
                for aset in allAsets where aset.portofolio == oldName {
                    aset.portofolio = trimmed
                }
            }
        }
        try? modelContext.save()
        dismiss()
    }
}
