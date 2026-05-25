import Foundation
import SwiftData

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var models: [OllamaModelInfo] = []
    @Published var inputText: String = ""
    @Published var isGenerating: Bool = false
    @Published var errorMessage: String?
    @Published var streamingThinking: String = ""
    @Published var streamingContent: String = ""
    /// 仅当向 UI 推送流式快照时递增，供滚动监听（避免监听 String 每个字符）
    @Published private(set) var streamingRevision: UInt = 0
    @Published private(set) var generatingSessionID: UUID?
    @Published private(set) var streamingMessageID: UUID?

    private var client = OllamaClient()
    private var streamTask: Task<Void, Never>?
    private weak var sessionFocus: ChatSessionFocus?
    private var streamThinkingBuffer = ""
    private var streamContentBuffer = ""
    private var pendingStreamingPublishTask: Task<Void, Never>?
    private let streamingPublishInterval: UInt64 = 50_000_000
    /// 每次生成的唯一 token；任务在写回 UI/SwiftData 状态前都校验 token，
    /// 避免历史任务在新一轮生成开始后误改全局状态
    private var generationToken: UUID?

    func attach(sessionFocus: ChatSessionFocus) {
        self.sessionFocus = sessionFocus
    }

    func isStreaming(sessionID: UUID, messageID: UUID) -> Bool {
        isGenerating
            && generatingSessionID == sessionID
            && streamingMessageID == messageID
    }

    func isGenerating(in sessionID: UUID) -> Bool {
        isGenerating && generatingSessionID == sessionID
    }

    /// 切换侧栏会话后由 ChatView 调用（延迟到下一帧，避免 onChange 同帧多次写状态）
    func sessionBecameVisible(_ sessionID: UUID) {
        if sessionID == generatingSessionID {
            publishStreamingSnapshotIfCurrent(token: generationToken)
        } else if !inputText.isEmpty {
            inputText = ""
        }
    }

    func configure(baseURL: String) {
        client.updateBaseURL(baseURL)
    }

    func loadModels() async {
        do {
            models = try await client.fetchModels()
            ModelListStore.shared.update(models)
            errorMessage = nil
        } catch {
            errorMessage = localizedErrorMessage(error)
            models = []
            ModelListStore.shared.update([])
        }
    }

    func isModelAvailable(_ modelName: String) -> Bool {
        ModelListStore.shared.contains(modelName)
    }

    func sendMessage(session: ChatSession, context: ModelContext, settings: AppSettings?) async {
        guard !isGenerating else {
            errorMessage = AppLanguageStore.shared.string(.otherChatGenerating)
            return
        }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard !session.model.isEmpty else {
            errorMessage = OllamaError.noModelSelected.localizedMessage(language: AppLanguageStore.shared.language)
            return
        }
        guard isModelAvailable(session.model) else {
            errorMessage = OllamaError.modelNotAvailable(session.model).localizedMessage(language: AppLanguageStore.shared.language)
            return
        }

        let userMessage = ChatMessage(role: "user", content: text)
        userMessage.session = session
        session.messages.append(userMessage)
        session.updatedAt = .now
        session.updateTitleFromMessages()
        inputText = ""
        try? context.save()

        await generateResponse(for: session, context: context)
    }

    func regenerateLast(session: ChatSession, context: ModelContext) async {
        guard !isGenerating else {
            errorMessage = AppLanguageStore.shared.string(.otherChatGenerating)
            return
        }
        guard let lastUserIndex = session.sortedMessages.lastIndex(where: { $0.isUser }) else { return }
        let toRemove = Array(session.sortedMessages[(lastUserIndex + 1)...])
        for msg in toRemove {
            context.delete(msg)
            session.messages.removeAll { $0.id == msg.id }
        }
        try? context.save()
        await generateResponse(for: session, context: context)
    }

    /// 仅做取消信号，缓冲区与状态留给 streamTask 在 catch 中保存后再清理，
    /// 否则 catch 读到的 buffer 已被清空，会导致中断的助手消息丢失内容。
    func stopGeneration() {
        streamTask?.cancel()
    }

    private func generateResponse(for session: ChatSession, context: ModelContext) async {
        guard isModelAvailable(session.model) else {
            errorMessage = OllamaError.modelNotAvailable(session.model).localizedMessage(language: AppLanguageStore.shared.language)
            return
        }

        let myToken = UUID()
        generationToken = myToken
        isGenerating = true
        generatingSessionID = session.id
        pendingStreamingPublishTask?.cancel()
        pendingStreamingPublishTask = nil
        streamThinkingBuffer = ""
        streamContentBuffer = ""
        clearStreamingDisplay()
        errorMessage = nil

        let assistantMessage = ChatMessage(role: "assistant")
        assistantMessage.session = session
        session.messages.append(assistantMessage)
        streamingMessageID = assistantMessage.id
        // 立刻 bump updatedAt：触发 ChatView 的 onChange 立刻刷新 messageSnapshots，
        // 否则「重新生成」场景下旧助手消息删除 + 新空消息追加后 count 不变，
        // 用户会看到旧消息原封不动直到流结束。
        session.updatedAt = .now

        let apiMessages = session.sortedMessages
            .filter { $0.id != assistantMessage.id }
            .map { msg -> APIMessage in
                if msg.isAssistant, !msg.thinking.isEmpty {
                    return APIMessage(role: msg.role, content: msg.content, thinking: msg.thinking)
                }
                return APIMessage(role: msg.role, content: msg.content)
            }

        let thinkMode = ThinkingMode.from(session: session)
        let thinkParam = thinkMode.apiValue

        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = self.client.chatStream(
                    model: session.model,
                    messages: apiMessages,
                    think: thinkParam
                )

                for try await event in stream {
                    if Task.isCancelled { throw CancellationError() }
                    switch event {
                    case .thinkingDelta(let delta):
                        self.streamThinkingBuffer += delta
                        self.scheduleStreamingSnapshotIfVisible(token: myToken)
                    case .contentDelta(let delta):
                        self.streamContentBuffer += delta
                        self.scheduleStreamingSnapshotIfVisible(token: myToken)
                    case .done:
                        break
                    }
                }

                self.publishStreamingSnapshotIfCurrent(token: myToken)
                assistantMessage.thinking = self.streamThinkingBuffer
                assistantMessage.content = self.streamContentBuffer
                MessageRenderCache.invalidate(messageID: assistantMessage.id)
                session.updatedAt = .now
                try? context.save()
            } catch is CancellationError {
                assistantMessage.thinking = self.streamThinkingBuffer
                assistantMessage.content = self.streamContentBuffer
                MessageRenderCache.invalidate(messageID: assistantMessage.id)
                if assistantMessage.content.isEmpty && assistantMessage.thinking.isEmpty {
                    context.delete(assistantMessage)
                    session.messages.removeAll { $0.id == assistantMessage.id }
                } else {
                    assistantMessage.isInterrupted = true
                }
                session.updatedAt = .now
                try? context.save()
            } catch {
                assistantMessage.thinking = self.streamThinkingBuffer
                assistantMessage.content = self.streamContentBuffer
                MessageRenderCache.invalidate(messageID: assistantMessage.id)
                if self.generationToken == myToken {
                    self.errorMessage = self.localizedErrorMessage(error)
                }
                if assistantMessage.content.isEmpty && assistantMessage.thinking.isEmpty {
                    context.delete(assistantMessage)
                    session.messages.removeAll { $0.id == assistantMessage.id }
                } else {
                    assistantMessage.isInterrupted = true
                }
                session.updatedAt = .now
                try? context.save()
            }

            if self.generationToken == myToken {
                self.generationToken = nil
                self.isGenerating = false
                self.generatingSessionID = nil
                self.streamingMessageID = nil
                self.pendingStreamingPublishTask?.cancel()
                self.pendingStreamingPublishTask = nil
                self.streamThinkingBuffer = ""
                self.streamContentBuffer = ""
                self.clearStreamingDisplay()
            }
        }

        await streamTask?.value
    }

    private var isVisibleGeneratingSession: Bool {
        guard let generatingSessionID,
              let visible = sessionFocus?.visibleSessionID else { return false }
        return visible == generatingSessionID
    }

    private func scheduleStreamingSnapshotIfVisible(token: UUID) {
        guard generationToken == token else { return }
        guard isVisibleGeneratingSession else { return }
        guard pendingStreamingPublishTask == nil else { return }

        let interval = streamingPublishInterval
        pendingStreamingPublishTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: interval)
            await MainActor.run {
                guard let self else { return }
                self.pendingStreamingPublishTask = nil
                self.publishStreamingSnapshotIfCurrent(token: token)
            }
        }
    }

    private func publishStreamingSnapshotIfCurrent(token: UUID?) {
        guard let token, generationToken == token else { return }
        guard isVisibleGeneratingSession else { return }
        publishStreamingSnapshot()
    }

    private func publishStreamingSnapshot() {
        guard streamingThinking != streamThinkingBuffer || streamingContent != streamContentBuffer else { return }
        streamingThinking = streamThinkingBuffer
        streamingContent = streamContentBuffer
        streamingRevision &+= 1
    }

    private func clearStreamingDisplay() {
        streamingThinking = ""
        streamingContent = ""
    }

    private func localizedErrorMessage(_ error: Error) -> String {
        if let ollamaError = error as? OllamaError {
            return ollamaError.localizedMessage(language: AppLanguageStore.shared.language)
        }
        return error.localizedDescription
    }
}
