import SwiftUI
import SwiftData

struct TargetListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Target.createdAt) var allTargets: [Target]
    @Query var allSimpan: [SimpanKeTarget]

    @State private var showAddSheet = false
    @State private var editingTarget: Target? = nil
    @State private var selectedTarget: Target? = nil

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
                        ForEach(allTargets) { target in
                            targetCard(target)
                                .onTapGesture {
                                    selectedTarget = target
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
                Button {
                    showAddSheet = true
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
                .foregroundStyle(Color(hex: "#22C55E"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "#22C55E").opacity(0.15))
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

        VStack(alignment: .leading, spacing: 12) {
            // Top row: icon + action buttons
            HStack(alignment: .center, spacing: 0) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(targetColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    if let emoji = target.ikonCustom, !emoji.isEmpty {
                        Text(emoji)
                            .font(.system(size: 20))
                    } else {
                        Image(systemName: target.ikon)
                            .font(.system(size: 18))
                            .foregroundStyle(targetColor)
                    }
                }

                Spacer()

                // Action buttons
                HStack(spacing: 8) {
                    Button {
                        editingTarget = target
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundStyle(.gray)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.07))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        deleteTarget(target)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.red.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Name
            Text(target.nama)
                .font(.headline)
                .foregroundStyle(.white)

            // Saldo & Target rows
            HStack {
                Text("Saldo: \(target.tersimpan.idrFormatted)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
            }

            HStack {
                Text("Target: \(target.targetNominal.idrFormatted)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(String(format: "%.0f%%", target.progressPersen))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(targetColor)
            }

            // Progress bar
            ProgressBarView(progress: progressValue, color: targetColor, height: 6)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                    .background(Color(hex: "#22C55E"))
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
