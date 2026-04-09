import SwiftUI
import SwiftData

struct AddEditGoalView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var existingGoal: Goal? = nil

    @State private var title = ""
    @State private var targetAmount: Double = 0
    @State private var hasDeadline = false
    @State private var deadline = Date().addingTimeInterval(86400 * 90)
    @State private var icon = "star.fill"
    @State private var colorHex = "#FFD700"

    private let icons = ["star.fill", "house.fill", "car.fill", "airplane", "laptopcomputer",
                         "iphone", "bag.fill", "heart.fill", "gamecontroller.fill", "graduationcap.fill"]
    private let colors = ["#FFD700", "#FF6B6B", "#4ECDC4", "#45B7D1", "#BB8FCE", "#F7DC6F", "#96CEB4", "#F8A488"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    TextField("Nama Goal (contoh: Beli Macbook)", text: $title)
                    CurrencyInputField(label: "Target Amount", amount: $targetAmount)
                }

                Section("Deadline") {
                    Toggle("Set Deadline", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Tanggal Target", selection: $deadline, in: Date()..., displayedComponents: .date)
                    }
                }

                Section("Tampilan") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(icons, id: \.self) { ic in
                                Image(systemName: ic)
                                    .font(.title2)
                                    .padding(10)
                                    .background(icon == ic ? Color(hex: colorHex) : Color(.secondarySystemBackground))
                                    .foregroundStyle(icon == ic ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .onTapGesture { icon = ic }
                            }
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(colors, id: \.self) { c in
                                Circle()
                                    .fill(Color(hex: c))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if colorHex == c {
                                            Image(systemName: "checkmark").foregroundStyle(.white).font(.caption.bold())
                                        }
                                    }
                                    .onTapGesture { colorHex = c }
                            }
                        }
                    }
                }
            }
            .navigationTitle(existingGoal == nil ? "Buat Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Batal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") { save() }
                        .disabled(title.isEmpty || targetAmount == 0)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        guard let g = existingGoal else { return }
        title = g.title; targetAmount = g.targetAmount
        hasDeadline = g.deadline != nil
        deadline = g.deadline ?? Date().addingTimeInterval(86400 * 90)
        icon = g.icon; colorHex = g.colorHex
    }

    private func save() {
        if let g = existingGoal {
            g.title = title; g.targetAmount = targetAmount
            g.deadline = hasDeadline ? deadline : nil
            g.icon = icon; g.colorHex = colorHex
        } else {
            context.insert(Goal(title: title, targetAmount: targetAmount,
                               deadline: hasDeadline ? deadline : nil,
                               icon: icon, colorHex: colorHex))
        }
        try? context.save()
        dismiss()
    }
}
