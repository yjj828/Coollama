import Foundation
import SwiftData

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var baseURL: String = "http://127.0.0.1:11434"
    @Published var defaultModel: String = ""
    @Published var defaultThinkEnabled: Bool = false
    @Published var appearance: AppearanceMode = .system
    @Published var language: AppLanguage = .english
    @Published var connectionStatus: ConnectionStatus = .unknown
    @Published var availableModels: [OllamaModelInfo] = []
    @Published var statusMessage: String = ""

    private let client = OllamaClient()
    private var settings: AppSettings?

    enum ConnectionStatus {
        case unknown, testing, connected, failed
    }

    /// 当 baseURL 指向非本机时返回对应 host，UI 据此显示安全警告
    var remoteHost: String? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let components = URLComponents(string: trimmed),
              let host = components.host?.lowercased(),
              !host.isEmpty else {
            return nil
        }
        let localHosts: Set<String> = ["127.0.0.1", "localhost", "::1", "0.0.0.0"]
        return localHosts.contains(host) ? nil : host
    }

    func load(from context: ModelContext) {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            settings = existing
            baseURL = existing.baseURL
            defaultModel = existing.defaultModel
            defaultThinkEnabled = existing.defaultThinkEnabled
            appearance = existing.appearance
            language = existing.language
        } else {
            let newSettings = AppSettings()
            context.insert(newSettings)
            settings = newSettings
            language = newSettings.language
            try? context.save()
        }
        AppLanguageStore.shared.update(language)
        client.updateBaseURL(baseURL)
        Task { await refreshModels() }
    }

    func save(context: ModelContext) {
        guard let settings else { return }
        settings.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.defaultModel = defaultModel
        settings.defaultThinkEnabled = defaultThinkEnabled
        settings.appearance = appearance
        settings.language = language
        AppLanguageStore.shared.update(language)
        client.updateBaseURL(settings.baseURL)
        try? context.save()
        statusMessage = AppLocalizer.string(.saved, language: language)
    }

    func refreshModels() async {
        do {
            availableModels = try await client.fetchModels()
            ModelListStore.shared.update(availableModels)
            if defaultModel.isEmpty, let first = availableModels.first {
                defaultModel = first.name
            }
            connectionStatus = .connected
        } catch {
            connectionStatus = .failed
            availableModels = []
            ModelListStore.shared.update([])
        }
    }

    func testConnection() async {
        connectionStatus = .testing
        client.updateBaseURL(baseURL)
        let ok = await client.testConnection()
        connectionStatus = ok ? .connected : .failed
        if ok {
            await refreshModels()
            statusMessage = AppLocalizer.string(.connectionSucceeded, language: language)
        } else {
            statusMessage = client.lastError ?? AppLocalizer.string(.connectionFailed, language: language)
        }
    }
}
