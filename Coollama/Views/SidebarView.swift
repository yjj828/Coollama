import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selectedSession: ChatSession?
    @Query(sort: \ChatSession.updatedAt, order: .reverse) private var sessions: [ChatSession]
    @Query private var settingsList: [AppSettings]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageStore: AppLanguageStore
    @ObservedObject private var modelListStore = ModelListStore.shared

    var body: some View {
        VStack(spacing: 0) {
            newChatButton

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(sessions) { session in
                        SessionRowView(
                            session: session,
                            isSelected: selectedSession?.id == session.id,
                            onSelect: { selectedSession = session },
                            onDelete: { deleteSession(session) }
                        )
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .background(OllamaTheme.sidebarBackground)
        .onAppear {
            if selectedSession == nil {
                if sessions.isEmpty {
                    createSession()
                } else {
                    selectedSession = sessions.first
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newChat)) { _ in
            createSession()
        }
    }

    // MARK: New chat button

    private var newChatButton: some View {
        Button(action: createSession) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .medium))
                Text(languageStore.string(.newChat))
                    .font(.callout.weight(.medium))
                Spacer()
                Text("⌘N")
                    .font(.caption2)
                    .foregroundStyle(OllamaTheme.textTertiary)
            }
            .foregroundStyle(OllamaTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Rectangle().fill(OllamaTheme.sidebarBackground)
        )
        .help(languageStore.string(.newChatShortcutHelp))
    }

    // MARK: Session management

    func createSession() {
        let settings = settingsList.first
        let previousModel = selectedSession?.model
        let model = modelListStore.resolveModelForNewSession(previousModel: previousModel)
        let thinkEnabled = selectedSession?.thinkEnabled ?? settings?.defaultThinkEnabled ?? false
        let session = ChatSession(
            title: languageStore.string(.newChat),
            model: model,
            thinkEnabled: thinkEnabled
        )
        modelContext.insert(session)
        try? modelContext.save()
        selectedSession = session
    }

    private func deleteSession(_ session: ChatSession) {
        if selectedSession?.id == session.id {
            selectedSession = sessions.first { $0.id != session.id }
        }
        modelContext.delete(session)
        try? modelContext.save()
        if sessions.filter({ $0.id != session.id }).isEmpty {
            createSession()
        }
    }
}

// MARK: - Session row

private struct SessionRowView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    let session: ChatSession
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            Text(session.title)
                .font(.callout)
                .foregroundStyle(isSelected ? OllamaTheme.textPrimary : OllamaTheme.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(languageStore.string(.delete), role: .destructive, action: onDelete)
        }
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }

    private var rowBackground: some View {
        Group {
            if isSelected {
                OllamaTheme.accentMuted
            } else if isHovered {
                Color.white.opacity(0.05)
            } else {
                Color.clear
            }
        }
    }
}
