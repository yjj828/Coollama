import Foundation
import SwiftData

@Model
final class ChatSession {
    var id: UUID
    var title: String
    var model: String
    var thinkEnabled: Bool
    var thinkLevel: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var messages: [ChatMessage]

    init(
        title: String = "New Chat",
        model: String = "",
        thinkEnabled: Bool = false,
        thinkLevel: String = "medium",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.title = title
        self.model = model
        self.thinkEnabled = thinkEnabled
        self.thinkLevel = thinkLevel
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.messages = []
    }

    var sortedMessages: [ChatMessage] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }

    func updateTitleFromMessages() {
        if let first = sortedMessages.first(where: { $0.isUser }),
           !first.content.isEmpty {
            let trimmed = first.content.trimmingCharacters(in: .whitespacesAndNewlines)
            title = String(trimmed.prefix(30))
            if trimmed.count > 30 { title += "…" }
        }
    }
}
