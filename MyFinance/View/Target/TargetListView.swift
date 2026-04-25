import SwiftUI
import SwiftData

struct TargetListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Target.urutan) var allTargets: [Target]

    @State private var showAddSheet = false
    @State private var editingTarget: Target? = nil
    @State private var selectedTarget: Target? = nil
    @State private var isReordering = false

    private let accentGreen = Color(hex: "#22C55E")

    var sortedTargets: [Target] {
        allTargets.sorted { $0.urutan == $1.urutan ? $0.createdAt < $1.createdAt : $0.urutan < $1.urutan }
    }

    var totalTersimpan: Decimal {
        allTargets.reduce(0) { $0 + $1.tersimpan }
    }

    var body: some View {
        ZStack {
            Color(hex: "#0D0D0D").ignoresSafeArea()

            if allTargets.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        headerCard

                        if isReordering {
                            reorderHint
                            reorderList
                        } else {
                            ForEach(sortedTargets) { target in
                                targetCard(target)
                                    .onTapGesture { selectedTarget = target }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("Target")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if !allTargets.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isReordering.toggle()
                            }
                        } label: {
                            Text(isReordering ? "Selesai" : "Atur Urutan")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isReordering ? .white : accentGreen)
                        }
                    }
                    if !isReordering {
                        Button {
                            showAddSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Tambah")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(accentGreen)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddEditTargetView(target: nil)
        }
        .sheet(item: $editingTarget) { target in
            AddEditTargetView(target: target)
        }
        .sheet(item: $selectedTarget) { target in
            TargetDetailSheet(target: target)
        }
    }

    // MARK: - Reorder Hint

    private var reorderHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.caption2)
                .foregroundStyle(.gray)
            Text("Seret untuk mengatur urutan")
                .font(.caption2)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Reorder List (compact rows)

    private var reorderList: some View {
        List {
            ForEach(sortedTargets) { target in
                reorderRow(target)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
            .onMove { source, destination in
                var targets = sortedTargets
                targets.move(fromOffsets: source, toOffset: destination)
                for (index, target) in targets.enumerated() {
                    target.urutan = index
                }
                try? modelContext.save()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDisabled(true)
        .frame(height: CGFloat(allTargets.count) * 68)
        .environment(\.editMode, .constant(.active))
    }

    @ViewBuilder
    private func reorderRow(_ target: Target) -> some View {
        let targetColor = Color(hex: target.warna)
        HStack(spacing: 12) {
            // Color accent + icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(targetColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                if let emoji = target.ikonCustom, !emoji.isEmpty {
                    Text(emoji).font(.system(size: 18))
                } else {
                    Image(systemName: target.ikon)
                        .font(.system(size: 16))
                        .foregroundStyle(targetColor)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(target.nama)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(String(format: "%.0f%%", target.progressPersen))
                    .font(.caption2)
                    .foregroundStyle(targetColor)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Header Card

    private var headerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TOTAL TABUNGAN")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.gray)
                    .tracking(0.5)
                Text(totalTersimpan.idrFormatted)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Text("\(allTargets.count) TARGET")
                .font(.caption.weight(.bold))
                .foregroundStyle(accentGreen)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(accentGreen.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Target Card

    @ViewBuilder
    private func targetCard(_ target: Target) -> some View {
        let targetColor = Color(hex: target.warna)
        let progressValue = min(target.progressPersen / 100.0, 1.0)
        let isInvestasi = target.jenisTarget == .investasi
        let hasFoto = target.fotoData != nil

        ZStack(alignment: .bottom) {
            // Background: foto atau solid
            if let data = target.fotoData, let uiImg = UIImage(data: data) {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 180)
                    .clipped()
            } else {
                ZStack(alignment: .leading) {
                    Color.white.opacity(0.05)
                    Rectangle()
                        .fill(targetColor)
                        .frame(width: 3)
                }
            }

            // Gradient overlay
            LinearGradient(
                colors: hasFoto
                    ? [Color.black.opacity(0), Color.black.opacity(0.55), Color.black.opacity(0.92)]
                    : [Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )

            // Konten
            VStack(alignment: .leading, spacing: 0) {
                // Top row: icon + name + badge + percentage
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(hasFoto ? Color.black.opacity(0.35) : targetColor.opacity(0.2))
                            .frame(width: 44, height: 44)
                        if let emoji = target.ikonCustom, !emoji.isEmpty {
                            Text(emoji).font(.system(size: 20))
                        } else {
                            Image(systemName: target.ikon)
                                .font(.system(size: 18))
                                .foregroundStyle(hasFoto ? .white : targetColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(target.nama)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .shadow(color: hasFoto ? .black.opacity(0.6) : .clear, radius: 4)
                            if isInvestasi {
                                HStack(spacing: 3) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 9, weight: .bold))
                                    Text(target.linkedAset?.tipe.displayName ?? "Investasi")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundStyle(hasFoto ? .white : targetColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(hasFoto ? Color.white.opacity(0.2) : targetColor.opacity(0.15))
                                .clipShape(Capsule())
                            }
                        }
                        if let deadline = target.deadline {
                            let daysLeft = max(Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0, 0)
                            Label("\(daysLeft) hari lagi", systemImage: "calendar")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(hasFoto ? 0.8 : 0.4))
                                .shadow(color: hasFoto ? .black.opacity(0.5) : .clear, radius: 3)
                        } else {
                            Text("Tanpa deadline")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(hasFoto ? 0.7 : 0.3))
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.0f%%", target.progressPersen))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(hasFoto ? .white : targetColor)
                            .shadow(color: hasFoto ? .black.opacity(0.6) : .clear, radius: 4)
                        Text("tercapai")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 14)

                // Progress section
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(target.tersimpan.idrFormatted)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("/ \(target.targetNominal.idrFormatted)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                    }
                    ProgressBarView(progress: progressValue, color: hasFoto ? .white : targetColor, height: 6)
                        .opacity(hasFoto ? 0.9 : 1)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

                // Bottom action buttons
                HStack {
                    Spacer()
                    Button {
                        editingTarget = target
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 13))
                            .foregroundStyle(hasFoto ? .white : .gray)
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(hasFoto ? 0.2 : 0.07))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        deleteTarget(target)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.red.opacity(0.8))
                            .frame(width: 30, height: 30)
                            .background(Color.red.opacity(hasFoto ? 0.25 : 0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(.gray)
            Text("Belum ada target")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Yuk buat target tabungan pertamamu!")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            Button {
                showAddSheet = true
            } label: {
                Text("+ Bikin Target")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(accentGreen)
                    .clipShape(Capsule())
            }
        }
        .padding(32)
    }

    // MARK: - Delete

    private func deleteTarget(_ target: Target) {
        modelContext.delete(target)
        try? modelContext.save()
    }
}
