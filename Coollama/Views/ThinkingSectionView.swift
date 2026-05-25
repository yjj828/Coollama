import SwiftUI

struct ThinkingSectionView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    let thinking: String
    var isStreaming: Bool = false

    @State private var isExpanded: Bool = true

    var body: some View {
        if thinking.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                toggleButton

                if isExpanded {
                    thinkingContent
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: Toggle header

    private var toggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(OllamaTheme.textTertiary)

                Text(isStreaming ? languageStore.string(.thinking) : languageStore.string(.thinkingProcess))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(OllamaTheme.textSecondary)

                if isStreaming {
                    StreamingEllipsis()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, isExpanded ? 6 : 0)
    }

    // MARK: Content

    private var thinkingContent: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(OllamaTheme.thinkingLine)
                .frame(width: 2)
                .clipShape(Capsule())

            Text(thinking)
                .font(.footnote)
                .foregroundStyle(OllamaTheme.textSecondary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 10)
                .padding(.vertical, 2)
        }
        .background(OllamaTheme.thinkingTint)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: Lifecycle

    private func updateExpansion() {
        if isStreaming { isExpanded = true }
    }
}

// MARK: - Streaming ellipsis

private struct StreamingEllipsis: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.45)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.45) % 3 + 1
            Text(String(repeating: ".", count: tick))
                .font(.caption)
                .foregroundStyle(OllamaTheme.textTertiary)
                .frame(width: 16, alignment: .leading)
        }
    }
}
