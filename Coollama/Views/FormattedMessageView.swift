import SwiftUI

struct FormattedMessageView: View, Equatable {
    let messageID: UUID
    let content: String
    var isStreaming: Bool = false

    private var blocks: [MessageBlock] {
        MessageRenderCache.blocks(for: messageID, content: content)
    }

    var body: some View {
        Group {
            if isStreaming {
                Text(content)
                    .font(.body)
                    .foregroundStyle(OllamaTheme.textPrimary)
                    .lineSpacing(5)
            } else {
                formattedBody
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func == (lhs: FormattedMessageView, rhs: FormattedMessageView) -> Bool {
        lhs.messageID == rhs.messageID
            && lhs.content == rhs.content
            && lhs.isStreaming == rhs.isStreaming
    }

    @ViewBuilder
    private var formattedBody: some View {
        if blocks.isEmpty {
            MessageRenderCache.inlineText(for: content)
                .font(.body)
                .lineSpacing(5)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                    blockView(block)
                        .padding(.top, topSpacing(before: index))
                }
            }
        }
    }

    private func topSpacing(before index: Int) -> CGFloat {
        guard index > 0 else { return 0 }
        switch blocks[index] {
        case .heading: return 14
        case .codeBlock: return 12
        case .paragraph, .bulletList, .orderedList, .blockquote: return 10
        }
    }

    @ViewBuilder
    private func blockView(_ block: MessageBlock) -> some View {
        switch block {
        case .paragraph(let text):
            MessageRenderCache.inlineText(for: text)
                .font(.body)
                .lineSpacing(5)

        case .heading(let level, let text):
            Text(text)
                .font(headingFont(level))
                .fontWeight(.semibold)
                .foregroundStyle(OllamaTheme.textPrimary)
                .padding(.bottom, 4)

        case .codeBlock(let language, let code):
            VStack(alignment: .leading, spacing: 0) {
                if let language, !language.isEmpty {
                    Text(language)
                        .font(.caption2)
                        .foregroundStyle(OllamaTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(OllamaTheme.textPrimary.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OllamaTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

        case .bulletList(let items):
            listBlock(items: items, ordered: false)

        case .orderedList(let items):
            listBlock(items: items, ordered: true)

        case .blockquote(let text):
            HStack(alignment: .top, spacing: 0) {
                Rectangle()
                    .fill(OllamaTheme.accent.opacity(0.5))
                    .frame(width: 3)
                MessageRenderCache.inlineText(for: text)
                    .foregroundStyle(OllamaTheme.textSecondary)
                    .padding(.leading, 10)
            }
            .padding(.vertical, 4)
        }
    }

    private func listBlock(items: [String], ordered: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { offset, item in
                HStack(alignment: .top, spacing: 8) {
                    Text(ordered ? "\(offset + 1)." : "•")
                        .font(.body)
                        .foregroundStyle(OllamaTheme.accent)
                        .frame(width: ordered ? 22 : 12, alignment: .leading)
                    MessageRenderCache.inlineText(for: item)
                        .font(.body)
                        .lineSpacing(4)
                }
            }
        }
        .padding(.leading, 4)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title2
        case 2: .title3
        case 3: .headline
        default: .subheadline
        }
    }
}
