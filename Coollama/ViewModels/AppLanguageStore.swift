import Foundation

@MainActor
final class AppLanguageStore: ObservableObject {
    static let shared = AppLanguageStore()

    @Published private(set) var language: AppLanguage = .english

    private init() {}

    func update(_ language: AppLanguage) {
        guard self.language != language else { return }
        self.language = language
    }

    func string(_ key: AppString) -> String {
        AppLocalizer.string(key, language: language)
    }

    func format(_ key: AppString, _ arguments: CVarArg...) -> String {
        String(
            format: AppLocalizer.string(key, language: language),
            locale: language.locale,
            arguments: arguments
        )
    }
}
