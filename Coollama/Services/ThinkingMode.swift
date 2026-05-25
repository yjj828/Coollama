import Foundation

enum ThinkLevel: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    func label(language: AppLanguage) -> String {
        switch self {
        case .low: AppLocalizer.string(.thinkLow, language: language)
        case .medium: AppLocalizer.string(.thinkMedium, language: language)
        case .high: AppLocalizer.string(.thinkHigh, language: language)
        }
    }
}

enum ThinkingMode: Equatable {
    case disabled
    case enabled
    case level(ThinkLevel)

    static func from(session: ChatSession) -> ThinkingMode {
        guard session.thinkEnabled else { return .disabled }
        if session.model.lowercased().contains("gpt-oss") {
            return .level(ThinkLevel(rawValue: session.thinkLevel) ?? .medium)
        }
        return .enabled
    }

    static func usesLevelPicker(model: String) -> Bool {
        model.lowercased().contains("gpt-oss")
    }

    var apiValue: ThinkParameter? {
        switch self {
        case .disabled:
            .bool(false)
        case .enabled:
            .bool(true)
        case .level(let level):
            .level(level.rawValue)
        }
    }
}

enum ThinkParameter: Encodable {
    case bool(Bool)
    case level(String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value):
            try container.encode(value)
        case .level(let value):
            try container.encode(value)
        }
    }
}
