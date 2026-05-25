import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID
    var role: String
    var content: String
    var thinking: String
    var createdAt: Date
    var isInterrupted: Bool

    @Relationship(inverse: \ChatSession.messages)
    var session: ChatSession?

    init(
        role: String,
        content: String = "",
        thinking: String = "",
        createdAt: Date = .now,
        isInterrupted: Bool = false
    ) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.thinking = thinking
        self.createdAt = createdAt
        self.isInterrupted = isInterrupted
    }

    var isUser: Bool { role == "user" }
    var isAssistant: Bool { role == "assistant" }
}
