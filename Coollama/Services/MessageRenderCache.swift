import Foundation
import SwiftUI

/// 缓存消息 Markdown 解析结果，避免滚动时重复解析
@MainActor
enum MessageRenderCache {
    private static var blocksCache: [UUID: [MessageBlock]] = [:]
    private static var inlineCache: [String: AttributedString] = [:]
    private static var cacheOrder: [UUID] = []
    private static let maxMessageEntries = 128
    private static let maxInlineEntries = 512
    private static let blockParseCharacterLimit = 20_000

    static func blocks(for messageID: UUID, content: String) -> [MessageBlock] {
        if let cached = blocksCache[messageID] {
            return cached
        }
        guard content.count <= blockParseCharacterLimit else {
            return content.isEmpty ? [] : [.paragraph(content)]
        }
        let parsed = MessageContentParser.parse(content)
        storeBlocks(messageID: messageID, blocks: parsed)
        return parsed
    }

    static func inlineText(for text: String) -> Text {
        guard !text.isEmpty else { return Text("") }

        if let cached = inlineCache[text] {
            return Text(cached).foregroundStyle(OllamaTheme.textPrimary)
        }

        let attributed: AttributedString
        if let parsed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            attributed = parsed
        } else {
            attributed = AttributedString(text)
        }

        inlineCache[text] = attributed
        trimInlineIfNeeded()
        return Text(attributed).foregroundStyle(OllamaTheme.textPrimary)
    }

    static func invalidate(messageID: UUID) {
        blocksCache.removeValue(forKey: messageID)
        cacheOrder.removeAll { $0 == messageID }
    }

    private static func storeBlocks(messageID: UUID, blocks: [MessageBlock]) {
        if blocksCache[messageID] == nil {
            cacheOrder.append(messageID)
            while cacheOrder.count > maxMessageEntries {
                let removed = cacheOrder.removeFirst()
                blocksCache.removeValue(forKey: removed)
            }
        }
        blocksCache[messageID] = blocks
    }

    private static func trimInlineIfNeeded() {
        while inlineCache.count > maxInlineEntries, let key = inlineCache.keys.first {
            inlineCache.removeValue(forKey: key)
        }
    }
}
