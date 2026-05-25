import SwiftUI

/// 轻量快照，避免滚动时直接观察 SwiftData 模型
struct MessageRowSnapshot: Identifiable, Equatable {
    let id: UUID
    let isUser: Bool
    let content: String
    let thinking: String
    let isInterrupted: Bool
    let isLastAssistant: Bool
}

struct MessageRowView: View, Equatable {
    @EnvironmentObject private var languageStore: AppLanguageStore

    let snapshot: MessageRowSnapshot
    var streamingThinking: String = ""
    var streamingContent: String = ""
    var isStreaming: Bool = false
    var canRegenerate: Bool = false
    var onRegenerate: (() -> Void)?

    private var displayThinking: String {
        isStreaming && !streamingThinking.isEmpty ? streamingThinking : snapshot.thinking
    }

    private var displayContent: String {
        isStreaming && !streamingContent.isEmpty ? streamingContent : snapshot.content
    }

    private var showsRegenerateButton: Bool {
        !snapshot.isUser
            && snapshot.isLastAssistant
            && !isStreaming
            && canRegenerate
            && !displayContent.isEmpty
    }

    static func == (lhs: MessageRowView, rhs: MessageRowView) -> Bool {
        lhs.snapshot == rhs.snapshot
            && lhs.streamingThinking == rhs.streamingThinking
            && lhs.streamingContent == rhs.streamingContent
            && lhs.isStreaming == rhs.isStreaming
            && lhs.canRegenerate == rhs.canRegenerate
    }

    var body: some View {
        if snapshot.isUser {
            userRow
        } else {
            assistantRow
        }
    }

    // MARK: User

    private var userRow: some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer(minLength: 80)
            VStack(alignment: .trailing, spacing: 4) {
                Text(displayContent)
                    .font(.body)
                    .foregroundStyle(OllamaTheme.textPrimary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(OllamaTheme.userBubble)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                if snapshot.isInterrupted {
                    interruptedLabel
                }
            }
        }
        .padding(.horizontal, ChatContentLayout.innerHorizontalPadding)
        .padding(.vertical, 6)
    }

    // MARK: Assistant

    private var assistantRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !displayThinking.isEmpty {
                ThinkingSectionView(
                    thinking: displayThinking,
                    isStreaming: isStreaming
                )
                .padding(.horizontal, ChatContentLayout.innerHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 6)
            }

            Group {
                if displayContent.isEmpty && isStreaming {
                    generatingIndicator
                } else if !displayContent.isEmpty {
                    FormattedMessageView(
                        messageID: snapshot.id,
                        content: displayContent,
                        isStreaming: isStreaming
                    )
                    .equatable()
                    .padding(.horizontal, ChatContentLayout.innerHorizontalPadding)
                    .padding(.vertical, 10)
                }
            }

            if snapshot.isInterrupted {
                interruptedLabel
                    .padding(.horizontal, ChatContentLayout.innerHorizontalPadding)
                    .padding(.bottom, 4)
            }

            if showsRegenerateButton {
                regenerateButton
                    .padding(.horizontal, ChatContentLayout.innerHorizontalPadding)
                    .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var regenerateButton: some View {
        Button {
            onRegenerate?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption2)
                Text(languageStore.string(.regenerate))
                    .font(.caption)
            }
            .foregroundStyle(OllamaTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(languageStore.string(.regenerateLastResponseHelp))
    }

    // MARK: Shared

    private var generatingIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                PulsingDot(delay: Double(i) * 0.18)
            }
        }
        .padding(.horizontal, ChatContentLayout.innerHorizontalPadding)
        .padding(.vertical, 14)
    }

    private var interruptedLabel: some View {
        Text(languageStore.string(.interrupted))
            .font(.caption2)
            .foregroundStyle(OllamaTheme.warningText.opacity(0.7))
    }
}

// MARK: - Pulsing dot

private struct PulsingDot: View {
    let delay: Double
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.3

    var body: some View {
        Circle()
            .fill(OllamaTheme.textSecondary)
            .frame(width: 6, height: 6)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.55)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    scale = 1.0
                    opacity = 0.8
                }
            }
    }
}
