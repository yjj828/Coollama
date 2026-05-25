import Combine
import Foundation

struct TagsResponse: Decodable {
    let models: [OllamaModelInfo]
}

struct OllamaModelInfo: Decodable, Identifiable, Equatable {
    let name: String
    let model: String?
    let modifiedAt: String?
    let size: Int64?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, model, size
        case modifiedAt = "modified_at"
    }
}

struct APIMessage: Codable {
    let role: String
    let content: String
    let thinking: String?

    init(role: String, content: String, thinking: String? = nil) {
        self.role = role
        self.content = content
        self.thinking = thinking
    }
}

struct ChatRequest: Encodable {
    let model: String
    let messages: [APIMessage]
    let stream: Bool
    let think: ThinkParameter?

    init(model: String, messages: [APIMessage], stream: Bool = true, think: ThinkParameter?) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.think = think
    }
}

struct ChatStreamChunk: Decodable {
    let model: String?
    let createdAt: String?
    let message: StreamMessage?
    let done: Bool
    let totalDuration: Int64?
    let loadDuration: Int64?
    let promptEvalCount: Int?
    let evalCount: Int?

    enum CodingKeys: String, CodingKey {
        case model, message, done
        case createdAt = "created_at"
        case totalDuration = "total_duration"
        case loadDuration = "load_duration"
        case promptEvalCount = "prompt_eval_count"
        case evalCount = "eval_count"
    }
}

struct StreamMessage: Decodable {
    let role: String?
    let content: String?
    let thinking: String?
}

enum ChatStreamEvent {
    case thinkingDelta(String)
    case contentDelta(String)
    case done(ChatStreamChunk)
}

enum OllamaError: LocalizedError {
    case invalidURL
    case connectionFailed(String)
    case httpError(Int, String)
    case decodingFailed
    case cancelled
    case noModelSelected
    case modelNotAvailable(String)

    var errorDescription: String? {
        localizedMessage(language: .english)
    }

    func localizedMessage(language: AppLanguage) -> String {
        switch self {
        case .invalidURL:
            AppLocalizer.string(.invalidURL, language: language)
        case .connectionFailed(let detail):
            AppLocalizer.format(.unableToConnectOllama, language: language, detail)
        case .httpError(let code, let body):
            "HTTP \(code)：\(body)"
        case .decodingFailed:
            AppLocalizer.string(.decodingFailed, language: language)
        case .cancelled:
            AppLocalizer.string(.cancelled, language: language)
        case .noModelSelected:
            AppLocalizer.string(.noModelSelected, language: language)
        case .modelNotAvailable(let name):
            AppLocalizer.format(.modelNotAvailable, language: language, name)
        }
    }
}

// MARK: - Model list cache

@MainActor
final class ModelListStore: ObservableObject {
    static let shared = ModelListStore()

    @Published private(set) var models: [OllamaModelInfo] = []

    private init() {}

    func update(_ models: [OllamaModelInfo]) {
        self.models = models
    }

    var modelNames: Set<String> {
        Set(models.map(\.name))
    }

    func contains(_ modelName: String) -> Bool {
        !modelName.isEmpty && modelNames.contains(modelName)
    }

    /// 新对话：沿用上一对话模型；不可用则用列表第一项；无模型则留空
    func resolveModelForNewSession(previousModel: String?) -> String {
        let trimmed = previousModel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty, modelNames.contains(trimmed) {
            return trimmed
        }
        return models.first?.name ?? ""
    }
}
