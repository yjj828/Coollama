import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Query private var settingsList: [AppSettings]
    @StateObject private var sessionFocus = ChatSessionFocus()
    @State private var selectedSession: ChatSession?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedSession: $selectedSession)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
        } detail: {
            if let session = selectedSession {
                ChatView(session: session, columnVisibility: $columnVisibility)
            } else {
                placeholderView
            }
        }
        .environmentObject(sessionFocus)
        .onChange(of: selectedSession?.id) { _, newID in
            Task { @MainActor in
                await Task.yield()
                sessionFocus.visibleSessionID = newID
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .safeAreaPadding(.top, WindowMetrics.titleBarClearance)
        .hiddenTitleBarWindow()
        .ollamaBackground(colorScheme: settingsList.first?.appearance.colorScheme)
        .frame(minWidth: 880, minHeight: 580)
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                ensureSettings()
                syncLanguage()
            }
        }
        .onChange(of: settingsList.first?.languageRaw) { _, _ in
            scheduleLanguageSync()
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 0) {
            HStack {
                SidebarToggleButton(columnVisibility: $columnVisibility)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Spacer()

            VStack(spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(OllamaTheme.textTertiary)
                Text(languageStore.string(.chooseOrCreateChat))
                    .font(.callout)
                    .foregroundStyle(OllamaTheme.textSecondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OllamaTheme.background)
    }

    private func ensureSettings() {
        if settingsList.isEmpty {
            let settings = AppSettings()
            modelContext.insert(settings)
            try? modelContext.save()
        }
    }

    private func syncLanguage() {
        if let settings = settingsList.first {
            languageStore.update(settings.language)
        }
    }

    private func scheduleLanguageSync() {
        Task { @MainActor in
            await Task.yield()
            syncLanguage()
        }
    }
}
