import SwiftUI

// MARK: - Target Alokasi Sheet

struct TargetAlokasiSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    let alokasiData: [AsetListView.AlokasiItem]
    @Binding var targetAlokasiJSON: String

    // Local editable targets: label → target %
    @State private var targets: [String: Double] = [:]

    private var totalTarget: Double {
        targets.values.reduce(0, +)
    }

    private var totalColor: Color {
        let diff = abs(totalTarget - 100)
        if diff <= 2   { return Color(hex: "#22C55E") }
        if diff <= 10  { return Color(hex: "#F59E0B") }
        return Color(hex: "#EF4444")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.bgApp.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        summaryCard
                        targetRows
                        hintText
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Set Target Alokasi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.bgApp, for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(theme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
        .onAppear { loadExisting() }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL TARGET")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                        .tracking(0.5)
                    Text(String(format: "%.0f%%", totalTarget))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(totalColor)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if abs(totalTarget - 100) <= 2 {
                        Label("Pas!", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(hex: "#22C55E"))
                    } else if totalTarget < 100 {
                        let sisa = 100 - totalTarget
                        Text("Sisa \(String(format: "%.0f%%", sisa))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(hex: "#60A5FA"))
                    } else {
                        let lebih = totalTarget - 100
                        Text("Lebih \(String(format: "%.0f%%", lebih))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(hex: "#EF4444"))
                    }
                    Text("ideal = 100%")
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                }
            }

            // Progress bar total
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.separator)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(totalColor)
                        .frame(width: min(geo.size.width * CGFloat(totalTarget / 100), geo.size.width), height: 8)
                        .animation(.spring(response: 0.4), value: totalTarget)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardBorder, lineWidth: 1))
    }

    // MARK: - Target Rows

    private var targetRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(alokasiData.enumerated()), id: \.element.id) { idx, item in
                if idx > 0 { Divider().background(theme.separator) }
                targetRow(item: item)
            }
        }
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func targetRow(item: AsetListView.AlokasiItem) -> some View {
        let binding = Binding<Double>(
            get: { targets[item.label] ?? 0 },
            set: { targets[item.label] = max(0, min(100, $0)) }
        )
        let currentPct = item.nilai / alokasiData.reduce(0) { $0 + $1.nilai } * 100
        let targetVal  = targets[item.label] ?? 0
        let delta      = currentPct - targetVal

        VStack(spacing: 10) {
            HStack(spacing: 12) {
                // Color dot
                RoundedRectangle(cornerRadius: 4)
                    .fill(item.color)
                    .frame(width: 12, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text("Saat ini \(String(format: "%.1f%%", currentPct))")
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                // Target value + stepper
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Button {
                            let cur = targets[item.label] ?? 0
                            targets[item.label] = max(0, cur - 5)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(theme.textSecondary)
                        }

                        Text(String(format: "%.0f%%", binding.wrappedValue))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(theme.textPrimary)
                            .frame(minWidth: 44)
                            .multilineTextAlignment(.center)

                        Button {
                            let cur = targets[item.label] ?? 0
                            targets[item.label] = min(100, cur + 5)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(theme.accent)
                        }
                    }

                    // Delta label
                    if targetVal > 0 {
                        let sign   = delta > 0 ? "+" : ""
                        let color: Color = abs(delta) <= 5  ? Color(hex: "#22C55E")
                                         : delta > 0        ? Color(hex: "#F59E0B")
                                                            : Color(hex: "#60A5FA")
                        Text("\(sign)\(String(format: "%.0f%%", delta))")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(color)
                    }
                }
            }

            // Slider
            Slider(value: binding, in: 0...100, step: 1)
                .tint(item.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Hint Text

    private var hintText: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tips", systemImage: "lightbulb.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(hex: "#F59E0B"))

            Text("Set target setiap kelas aset supaya MyFinance bisa kasih tau kapan portofolio lo menyimpang dari rencana. Nggak harus tepat 100%, tapi idealnya mendekati.")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                autoBalance()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.caption.weight(.semibold))
                    Text("Auto-balance ke 100%")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(theme.accent.opacity(0.1))
                .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color(hex: "#F59E0B").opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#F59E0B").opacity(0.2), lineWidth: 1))
    }

    // MARK: - Helpers

    private func loadExisting() {
        guard let data = targetAlokasiJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
            // Default: distribusikan merata berdasarkan porsi saat ini
            setProportionalDefaults()
            return
        }
        targets = dict
        // Pastikan semua item di alokasiData ada di targets
        for item in alokasiData where targets[item.label] == nil {
            targets[item.label] = 0
        }
    }

    private func setProportionalDefaults() {
        let totalNilai = alokasiData.reduce(0.0) { $0 + $1.nilai }
        guard totalNilai > 0 else { return }
        for item in alokasiData {
            let rawPct = item.nilai / totalNilai * 100
            targets[item.label] = (rawPct / 5).rounded() * 5  // round ke kelipatan 5
        }
    }

    private func autoBalance() {
        let totalNilai = alokasiData.reduce(0.0) { $0 + $1.nilai }
        guard totalNilai > 0 else { return }
        var newTargets: [String: Double] = [:]
        var sumSoFar = 0.0
        for (idx, item) in alokasiData.enumerated() {
            if idx == alokasiData.count - 1 {
                // Last item gets the remainder to ensure exact 100
                newTargets[item.label] = max(0, 100 - sumSoFar)
            } else {
                let rawPct = (item.nilai / totalNilai * 100 / 5).rounded() * 5
                newTargets[item.label] = rawPct
                sumSoFar += rawPct
            }
        }
        withAnimation(.spring(response: 0.4)) {
            targets = newTargets
        }
    }

    private func save() {
        // Remove zero-target entries
        let filtered = targets.filter { $0.value > 0 }
        if let data = try? JSONEncoder().encode(filtered),
           let str = String(data: data, encoding: .utf8) {
            targetAlokasiJSON = str
        }
        dismiss()
    }
}
