import SwiftUI
import SwiftData

@main
struct CoollamaApp: App {
    @ObservedObject private var modelListStore = ModelListStore.shared
    @StateObject private var languageStore = AppLanguageStore.shared

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([ChatSession.self, ChatMessage.self, AppSettings.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(modelListStore)
                .environmentObject(languageStore)
                .environment(\.locale, languageStore.language.locale)
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(languageStore.string(.newChat)) {
                    NotificationCenter.default.post(name: .newChat, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(languageStore)
                .environment(\.locale, languageStore.language.locale)
        }
        .modelContainer(sharedModelContainer)
    }
}

extension Notification.Name {
    static let newChat = Notification.Name("newChat")
}
