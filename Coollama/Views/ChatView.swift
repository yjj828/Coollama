import SwiftUI
import SwiftData

struct ChatView: View {
    @Bindable var session: ChatSession
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @EnvironmentObject private var sessionFocus: ChatSessionFocus
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]
    @StateObject private var viewModel = ChatViewModel()
    @State private var scrollThrottle = ScrollThrottle()
    @State private var deferredUpdates = DeferredUpdateCoordinator()
    @State private var sideInset: CGFloat = 20
    @State private var messageSnapshots: [MessageRowSnapshot] = []

    var body: some View {
        VStack(spacing: 0) {
            chatToolbar

            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            messageList

            InputBarView(
                text: $viewModel.inputText,
                isGenerating: viewModel.isGenerating(in: session.id),
                onSend: {
                    Task { await viewModel.sendMessage(session: session, context: modelContext, settings: settingsList.first) }
                },
                onStop: { viewModel.stopGeneration() }
            )
        }
        .padding(.horizontal, sideInset)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { scheduleSideInsetUpdate(geometry.size.width) }
                    .onChange(of: geometry.size.width) { _, width in
                        scheduleSideInsetUpdate(width)
                    }
            }
        }
        .background(OllamaTheme.background)
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                viewModel.attach(sessionFocus: sessionFocus)
                sessionFocus.visibleSessionID = session.id
                viewModel.sessionBecameVisible(session.id)
                reloadMessageSnapshots()
                if let settings = settingsList.first {
                    viewModel.configure(baseURL: settings.baseURL)
                }
                await viewModel.loadModels()
                applyModelIfEmpty()
            }
        }
        .onChange(of: settingsList.first?.baseURL) { _, newURL in
            if let newURL {
                viewModel.configure(baseURL: newURL)
                Task { await viewModel.loadModels() }
            }
        }
        .onChange(of: session.id) { _, newID in
            Task { @MainActor in
                await Task.yield()
                sessionFocus.visibleSessionID = newID
                viewModel.sessionBecameVisible(newID)
                reloadMessageSnapshots()
                applyModelIfEmpty()
            }
        }
        .onChange(of: session.messages.count) { _, _ in
            scheduleMessageSnapshotReload()
        }
        .onChange(of: session.updatedAt) { _, _ in
            scheduleMessageSnapshotReload()
        }
        .onChange(of: viewModel.isGenerating) { wasGenerating, isGenerating in
            if wasGenerating && !isGenerating {
                scheduleMessageSnapshotReload()
            }
        }
    }

    // MARK: Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            List {
                if messageSnapshots.isEmpty {
                    emptyState
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(messageSnapshots) { snapshot in
                        messageRow(for: snapshot)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .id(snapshot.id)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(OllamaTheme.background)
            .onChange(of: messageSnapshots.count) { _, _ in
                scheduleScrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: viewModel.streamingRevision) { _, _ in
                scheduleScrollToBottom(proxy: proxy, animated: true, throttle: true)
            }
        }
    }

    @ViewBuilder
    private func messageRow(for snapshot: MessageRowSnapshot) -> some View {
        let isStreamingTarget = viewModel.isStreaming(
            sessionID: session.id,
            messageID: snapshot.id
        )

        MessageRowView(
            snapshot: snapshot,
            streamingThinking: isStreamingTarget ? viewModel.streamingThinking : "",
            streamingContent: isStreamingTarget ? viewModel.streamingContent : "",
            isStreaming: isStreamingTarget,
            canRegenerate: !viewModel.isGenerating,
            onRegenerate: {
                Task { await viewModel.regenerateLast(session: session, context: modelContext) }
            }
        )
        .equatable()
    }

    // MARK: Toolbar

    private var chatToolbar: some View {
        HStack(spacing: 12) {
            ModelPickerView(
                selectedModel: $session.model,
                models: viewModel.models
            )

            ThinkToggleView(session: session)

            Spacer()

            if viewModel.isGenerating, !viewModel.isGenerating(in: session.id) {
                Button(action: { viewModel.stopGeneration() }) {
                    Label(languageStore.string(.stopGeneration), systemImage: "stop.circle")
                        .font(.caption)
                        .foregroundStyle(OllamaTheme.warningText)
                }
                .buttonStyle(.plain)
                .help(languageStore.string(.stopOtherChatGenerationHelp))
            }

            if viewModel.isGenerating(in: session.id) {
                StatusPulse()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(OllamaTheme.background)
    }

    // MARK: Error banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(OllamaTheme.warningText)
            Text(message)
                .font(.callout)
                .foregroundStyle(OllamaTheme.textPrimary)
            Spacer()
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OllamaTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(OllamaTheme.errorBanner)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(OllamaTheme.textTertiary)
            Text(languageStore.string(.startNewChat))
                .font(.callout)
                .foregroundStyle(OllamaTheme.textSecondary)
            Text(languageStore.string(.emptyChatHint))
                .font(.caption)
                .foregroundStyle(OllamaTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
        .padding(.horizontal, ChatContentLayout.innerHorizontalPadding)
    }

    // MARK: Helpers

    private func updateSideInset(_ width: CGFloat) {
        let inset = ChatContentLayout.sideInset(for: width)
        if abs(sideInset - inset) > 0.5 {
            sideInset = inset
        }
    }

    private func scheduleSideInsetUpdate(_ width: CGFloat) {
        Task { @MainActor in
            await Task.yield()
            updateSideInset(width)
        }
    }

    private func scheduleMessageSnapshotReload() {
        deferredUpdates.pendingSnapshotTask?.cancel()
        deferredUpdates.pendingSnapshotTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            reloadMessageSnapshots()
            deferredUpdates.pendingSnapshotTask = nil
        }
    }

    private func reloadMessageSnapshots() {
        let sorted = session.sortedMessages
        let lastAssistantID = sorted.last(where: { $0.isAssistant })?.id
        let snapshots = sorted.map { message in
            MessageRowSnapshot(
                id: message.id,
                isUser: message.isUser,
                content: message.content,
                thinking: message.thinking,
                isInterrupted: message.isInterrupted,
                isLastAssistant: message.id == lastAssistantID
            )
        }
        if messageSnapshots != snapshots {
            messageSnapshots = snapshots
        }
    }

    private func scheduleScrollToBottom(
        proxy: ScrollViewProxy,
        animated: Bool,
        throttle: Bool = false
    ) {
        if throttle {
            guard viewModel.isGenerating(in: session.id) else { return }
            guard scrollThrottle.shouldFire(interval: 0.15) else { return }
        }
        guard let lastID = messageSnapshots.last?.id else { return }
        deferredUpdates.pendingScrollTask?.cancel()
        deferredUpdates.pendingScrollTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            if animated {
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
            deferredUpdates.pendingScrollTask = nil
        }
    }

    private func applyModelIfEmpty() {
        if session.model.isEmpty {
            session.model = viewModel.models.first?.name ?? ""
        }
    }
}

// MARK: - Scroll throttle

private final class ScrollThrottle {
    private var lastFire = Date.distantPast

    func shouldFire(interval: TimeInterval) -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastFire) >= interval else { return false }
        lastFire = now
        return true
    }
}

private final class DeferredUpdateCoordinator {
    var pendingScrollTask: Task<Void, Never>?
    var pendingSnapshotTask: Task<Void, Never>?
}

// MARK: - Status pulse

private struct StatusPulse: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0.4

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(OllamaTheme.accent)
                .frame(width: 6, height: 6)
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                        scale = 1.1
                        opacity = 1.0
                    }
                }
            Text(languageStore.string(.generating))
                .font(.caption)
                .foregroundStyle(OllamaTheme.textSecondary)
        }
    }
}
