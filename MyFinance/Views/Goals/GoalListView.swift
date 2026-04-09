import SwiftUI
import SwiftData

struct GoalListView: View {
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            if goals.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "target")
                        .font(.system(size: 56))
                        .foregroundStyle(.secondary)
                    Text("Belum ada goal")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Button("+ Buat Goal Pertama") { showAdd = true }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Goals")
            } else {
                List {
                    ForEach(goals) { goal in
                        GoalCardView(goal: goal)
                    }
                }
                .navigationTitle("Goals")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showAdd = true } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddEditGoalView()
        }
    }
}

struct GoalCardView: View {
    @Environment(\.modelContext) private var context
    let goal: Goal

    @State private var showEdit = false
    @State private var showUpdateAmount = false
    @State private var newAmount: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: goal.colorHex).opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: goal.icon)
                        .foregroundStyle(Color(hex: goal.colorHex))
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title).font(.headline)
                    if let deadline = goal.deadline {
                        Text("Deadline: \(deadline.formatted(.dateTime.day().month().year()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if goal.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                } else if let onTrack = goal.isOnTrack {
                    Label(onTrack ? "On Track" : "Behind", systemImage: onTrack ? "checkmark" : "exclamationmark")
                        .font(.caption.bold())
                        .foregroundStyle(onTrack ? .green : .orange)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: goal.progress)
                    .tint(Color(hex: goal.colorHex))

                HStack {
                    Text(goal.currentAmount.idrFormatted)
                        .font(.subheadline.bold())
                    Text("dari \(goal.targetAmount.idrFormatted)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", goal.progress * 100))
                        .font(.caption.bold())
                        .foregroundStyle(Color(hex: goal.colorHex))
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .leading) {
            Button {
                newAmount = goal.currentAmount
                showUpdateAmount = true
            } label: {
                Label("Update", systemImage: "arrow.up.circle")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing) {
            Button { showEdit = true } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .sheet(isPresented: $showEdit) { AddEditGoalView(existingGoal: goal) }
        .alert("Update Progress", isPresented: $showUpdateAmount) {
            TextField("Jumlah saat ini", value: $newAmount, format: .number)
                .keyboardType(.numberPad)
            Button("Simpan") {
                goal.currentAmount = min(newAmount, goal.targetAmount)
                goal.isCompleted = goal.currentAmount >= goal.targetAmount
                try? context.save()
            }
            Button("Batal", role: .cancel) {}
        }
    }
}
