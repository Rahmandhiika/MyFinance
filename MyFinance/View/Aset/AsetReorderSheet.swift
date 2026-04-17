import SwiftUI
import SwiftData

struct AsetReorderSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\Aset.urutan), SortDescriptor(\Aset.createdAt)])
    private var allAset: [Aset]

    private func items(for tipe: TipeAset) -> [Aset] {
        allAset.filter { $0.tipe == tipe && $0.linkedTarget == nil }
    }

    private var linkedItems: [Aset] {
        allAset.filter { $0.linkedTarget != nil }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(TipeAset.allCases) { tipe in
                    let group = items(for: tipe)
                    if !group.isEmpty {
                        Section {
                            ForEach(group) { aset in
                                asetRow(aset: aset, tipe: tipe)
                                    .listRowBackground(Color.white.opacity(0.05))
                            }
                            .onMove { from, to in
                                var mutable = group
                                mutable.move(fromOffsets: from, toOffset: to)
                                for (i, aset) in mutable.enumerated() {
                                    aset.urutan = i
                                }
                                try? modelContext.save()
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: tipe.iconName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(tipe.color)
                                Text(tipe.displayName.uppercased())
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .tracking(0.8)
                            }
                        }
                    }
                }

                // Section Target Investasi
                if !linkedItems.isEmpty {
                    Section {
                        ForEach(linkedItems) { aset in
                            asetRow(aset: aset, tipe: aset.tipe, showTargetLabel: true)
                                .listRowBackground(Color(hex: "#22C55E").opacity(0.05))
                        }
                        .onMove { from, to in
                            var mutable = linkedItems
                            mutable.move(fromOffsets: from, toOffset: to)
                            for (i, aset) in mutable.enumerated() {
                                aset.urutan = i
                            }
                            try? modelContext.save()
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: "target")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(hex: "#22C55E"))
                            Text("TARGET INVESTASI")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color(hex: "#22C55E").opacity(0.7))
                                .tracking(0.8)
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#0D0D0D"))
            .listStyle(.insetGrouped)
            .navigationTitle("Atur Urutan Aset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Selesai") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func asetRow(aset: Aset, tipe: TipeAset, showTargetLabel: Bool = false) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tipe.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: tipe.iconName)
                    .font(.system(size: 13))
                    .foregroundStyle(tipe.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(aset.nama)
                    .foregroundStyle(.white)
                    .font(.subheadline)
                if showTargetLabel, let targetNama = aset.linkedTarget?.nama {
                    HStack(spacing: 3) {
                        Image(systemName: "target")
                            .font(.system(size: 9))
                        Text(targetNama)
                            .font(.caption2)
                    }
                    .foregroundStyle(Color(hex: "#22C55E").opacity(0.7))
                }
            }
            Spacer()
            if let kode = aset.kode, !kode.isEmpty {
                Text(kode.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}
