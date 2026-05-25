import Foundation
import SwiftData

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var nativeName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }
}

@Model
final class AppSettings {
    var id: UUID = UUID()
    var baseURL: String = "http://127.0.0.1:11434"
    var defaultModel: String = ""
    var defaultThinkEnabled: Bool = false
    var appearanceRaw: String = AppearanceMode.system.rawValue
    var languageRaw: String = AppLanguage.english.rawValue

    init(
        baseURL: String = "http://127.0.0.1:11434",
        defaultModel: String = "",
        defaultThinkEnabled: Bool = false,
        appearance: AppearanceMode = .system,
        language: AppLanguage = .english
    ) {
        self.id = UUID()
        self.baseURL = baseURL
        self.defaultModel = defaultModel
        self.defaultThinkEnabled = defaultThinkEnabled
        self.appearanceRaw = appearance.rawValue
        self.languageRaw = language.rawValue
    }

    var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }

    var language: AppLanguage {
        get { AppLanguage(rawValue: languageRaw) ?? .english }
        set { languageRaw = newValue.rawValue }
    }
}
