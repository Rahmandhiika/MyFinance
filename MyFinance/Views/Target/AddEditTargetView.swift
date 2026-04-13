import SwiftUI
import SwiftData

struct AddEditTargetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let editingTarget: Target?

    // Form state
    @State private var nama: String = ""
    @State private var targetNominal: Decimal = 0
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Date().addingTimeInterval(60 * 60 * 24 * 30)
    @State private var selectedIkon: String = "target"
    @State private var selectedWarna: String = "#22C55E"
    @State private var ikonCustom: String = ""

    init(target: Target? = nil) {
        self.editingTarget = target
    }

    private var isEditing: Bool { editingTarget != nil }
    private var selectedColor: Color { Color(hex: selectedWarna) }

    private var canSave: Bool {
        !nama.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // Preview icon
                        ZStack {
                            Circle()
                                .fill(selectedColor.opacity(0.2))
                                .frame(width: 72, height: 72)
                            if !ikonCustom.isEmpty {
                                Text(ikonCustom)
                                    .font(.system(size: 32))
                            } else {
                                Image(systemName: selectedIkon)
                                    .font(.system(size: 28))
                                    .foregroundStyle(selectedColor)
                            }
                        }
                        .padding(.top, 8)

                        // NAMA
                        formSection(label: "NAMA") {
                            TextField("Nama target...", text: $nama)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // BUTUH DANA
                        formSection(label: "BUTUH DANA BERAPA? (OPSIONAL)") {
                            CurrencyInputField(value: $targetNominal)
                        }

                        // DEADLINE
                        formSection(label: "TARGET KAPAN TERCAPAI? (OPSIONAL)") {
                            VStack(spacing: 10) {
                                Toggle("Aktifkan deadline", isOn: $hasDeadline)
                                    .toggleStyle(SwitchToggleStyle(tint: selectedColor))
                                    .foregroundStyle(.white)
                                    .font(.subheadline)

                                if hasDeadline {
                                    HStack {
                                        DatePicker(
                                            "",
                                            selection: $deadline,
                                            in: Date()...,
                                            displayedComponents: [.date]
                                        )
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                        Spacer()
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // IKON & COLOR PICKER
                        formSection(label: "IKON & WARNA") {
                            IkonColorPicker(
                                selectedIkon: $selectedIkon,
                                selectedWarna: $selectedWarna,
                                ikonCustom: $ikonCustom
                            )
                            .padding(12)
                            .background(Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // CTA Button
                        Button {
                            saveTarget()
                        } label: {
                            Text(isEditing ? "Simpan" : "Mulai Nabung!")
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(canSave ? selectedColor : Color.gray.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!canSave)
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle(isEditing ? "Edit Target" : "Bikin Target Baru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#0D0D0D"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                        .foregroundStyle(.gray)
                }
            }
            .onAppear { populateIfEditing() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Section Helper

    @ViewBuilder
    private func formSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.gray)
                .tracking(0.5)
            content()
        }
    }

    // MARK: - Logic

    private func populateIfEditing() {
        guard let t = editingTarget else { return }
        nama = t.nama
        targetNominal = t.targetNominal
        selectedIkon = t.ikon
        selectedWarna = t.warna
        ikonCustom = t.ikonCustom ?? ""
        if let dl = t.deadline {
            hasDeadline = true
            deadline = dl
        }
    }

    private func saveTarget() {
        let trimmedNama = nama.trimmingCharacters(in: .whitespaces)
        guard !trimmedNama.isEmpty else { return }

        if let existing = editingTarget {
            existing.nama = trimmedNama
            existing.targetNominal = targetNominal
            existing.deadline = hasDeadline ? deadline : nil
            existing.ikon = selectedIkon
            existing.warna = selectedWarna
            existing.ikonCustom = ikonCustom.isEmpty ? nil : ikonCustom
        } else {
            let target = Target(
                nama: trimmedNama,
                targetNominal: targetNominal,
                deadline: hasDeadline ? deadline : nil,
                ikon: selectedIkon,
                warna: selectedWarna
            )
            target.ikonCustom = ikonCustom.isEmpty ? nil : ikonCustom
            modelContext.insert(target)
        }

        try? modelContext.save()
        dismiss()
    }
}
