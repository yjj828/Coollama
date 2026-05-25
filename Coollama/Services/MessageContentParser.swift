import Foundation

// MARK: - Block model

enum MessageBlock: Identifiable, Equatable {
    case paragraph(String)
    case heading(Int, String)
    case codeBlock(language: String?, code: String)
    case bulletList([String])
    case orderedList([String])
    case blockquote(String)

    var id: String {
        switch self {
        case .paragraph(let t): "p-\(t.hashValue)"
        case .heading(let l, let t): "h\(l)-\(t.hashValue)"
        case .codeBlock(let lang, let c): "code-\(lang ?? "")-\(c.hashValue)"
        case .bulletList(let items): "ul-\(items.hashValue)"
        case .orderedList(let items): "ol-\(items.hashValue)"
        case .blockquote(let t): "q-\(t.hashValue)"
        }
    }
}

// MARK: - Parser

enum MessageContentParser {
    static func normalize(_ text: String) -> String {
        var result = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        if !result.contains("```"), !result.contains("\n#"), !result.contains("\n- "), !result.contains("\n* ") {
            result = result.replacingOccurrences(
                of: #"(?<=[。！？.!?])\n(?!\n)"#,
                with: "\n\n",
                options: .regularExpression
            )
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parse(_ text: String) -> [MessageBlock] {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return [] }

        var blocks: [MessageBlock] = []
        let lines = normalized.components(separatedBy: "\n")
        var index = 0

        while index < lines.count {
            let line = lines[index]

            if line.hasPrefix("```") {
                let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                index += 1
                while index < lines.count, !lines[index].hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                blocks.append(.codeBlock(language: language.isEmpty ? nil : language, code: codeLines.joined(separator: "\n")))
                continue
            }

            if let heading = parseHeading(line) {
                blocks.append(heading)
                index += 1
                continue
            }

            if line.hasPrefix("> ") {
                var quoteLines: [String] = []
                while index < lines.count, lines[index].hasPrefix("> ") {
                    quoteLines.append(String(lines[index].dropFirst(2)))
                    index += 1
                }
                blocks.append(.blockquote(quoteLines.joined(separator: "\n")))
                continue
            }

            if isBulletLine(line) {
                var items: [String] = []
                while index < lines.count, isBulletLine(lines[index]) {
                    items.append(bulletContent(lines[index]))
                    index += 1
                }
                blocks.append(.bulletList(items))
                continue
            }

            if isOrderedLine(line) {
                var items: [String] = []
                while index < lines.count, isOrderedLine(lines[index]) {
                    items.append(orderedContent(lines[index]))
                    index += 1
                }
                blocks.append(.orderedList(items))
                continue
            }

            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                continue
            }

            var paragraphLines: [String] = [line]
            index += 1
            while index < lines.count {
                let next = lines[index]
                if next.trimmingCharacters(in: .whitespaces).isEmpty { break }
                if next.hasPrefix("```") || next.hasPrefix("> ") || isBulletLine(next) || isOrderedLine(next) || parseHeading(next) != nil {
                    break
                }
                paragraphLines.append(next)
                index += 1
            }
            let paragraph = paragraphLines.joined(separator: "\n")
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph))
            }
        }

        return blocks
    }

    private static func parseHeading(_ line: String) -> MessageBlock? {
        var level = 0
        for char in line {
            if char == "#" { level += 1 } else { break }
        }
        guard level >= 1, level <= 6, line.count > level, line[line.index(line.startIndex, offsetBy: level)] == " " else {
            return nil
        }
        let text = String(line.dropFirst(level + 1)).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : .heading(level, text)
    }

    private static func isBulletLine(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("• ")
    }

    private static func bulletContent(_ line: String) -> String {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("- ") { return String(t.dropFirst(2)) }
        if t.hasPrefix("* ") { return String(t.dropFirst(2)) }
        if t.hasPrefix("• ") { return String(t.dropFirst(2)) }
        return t
    }

    private static func isOrderedLine(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard let dot = t.firstIndex(of: ".") else { return false }
        let prefix = t[..<dot]
        return !prefix.isEmpty && prefix.allSatisfy(\.isNumber) && t.index(after: dot) < t.endIndex && t[t.index(after: dot)] == " "
    }

    private static func orderedContent(_ line: String) -> String {
        let t = line.trimmingCharacters(in: .whitespaces)
        if let dot = t.firstIndex(of: ".") {
            let after = t.index(dot, offsetBy: 2, limitedBy: t.endIndex) ?? t.endIndex
            return String(t[after...]).trimmingCharacters(in: .whitespaces)
        }
        return t
    }
}
