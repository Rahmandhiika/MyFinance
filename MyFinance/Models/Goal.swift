import SwiftData
import Foundation

@Model
final class Goal {
    var id: UUID
    var title: String
    var targetAmount: Double
    var currentAmount: Double
    var deadline: Date?
    var icon: String
    var colorHex: String
    var isCompleted: Bool
    var createdAt: Date

    init(title: String, targetAmount: Double, deadline: Date? = nil,
         icon: String = "star.fill", colorHex: String = "#FFD700") {
        self.id = UUID()
        self.title = title
        self.targetAmount = targetAmount
        self.currentAmount = 0
        self.deadline = deadline
        self.icon = icon
        self.colorHex = colorHex
        self.isCompleted = false
        self.createdAt = Date()
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(currentAmount / targetAmount, 1.0)
    }

    var isOnTrack: Bool? {
        guard let deadline, !isCompleted else { return nil }
        let totalDays = deadline.timeIntervalSince(createdAt) / 86400
        let elapsedDays = Date().timeIntervalSince(createdAt) / 86400
        guard totalDays > 0 else { return false }
        return progress >= (elapsedDays / totalDays)
    }
}
