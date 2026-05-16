import SwiftData
import Foundation

@Model
final class SavedAIInsight {
    var id: UUID
    var content: String
    var source: String       // "chat" atau nama insight type
    var savedAt: Date

    init(content: String, source: String) {
        self.id      = UUID()
        self.content = content
        self.source  = source
        self.savedAt = Date()
    }
}
