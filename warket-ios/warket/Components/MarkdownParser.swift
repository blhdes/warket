import Foundation

/// A block being rendered. Inline formatting inside each block is handled
/// separately by AttributedString; this enum only captures block structure.
enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullet([String])
    case ordered([String])
    case quote(String)
    case code(String)
    case rule
}

/// Splits markdown source into block-level elements. Covers the syntax the web
/// app's editor offers: headings, bullet/ordered lists, blockquotes, fenced code
/// blocks, horizontal rules, and paragraphs. Inline syntax (**bold**, *italic*,
/// `code`, [links]) is left in the text for AttributedString to parse later.
enum MarkdownParser {
    static func parse(_ source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = source.components(separatedBy: "\n")
        var paragraph: [String] = []
        var i = 0

        func flushParagraph() {
            let text = paragraph.joined(separator: "\n")
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(.paragraph(text))
            }
            paragraph.removeAll()
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                flushParagraph()
                i += 1
                var code: [String] = []
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i]); i += 1
                }
                i += 1 // skip closing fence
                blocks.append(.code(code.joined(separator: "\n")))
                continue
            }

            if trimmed.isEmpty {
                flushParagraph(); i += 1; continue
            }

            if let heading = parseHeading(trimmed) {
                flushParagraph()
                blocks.append(.heading(level: heading.level, text: heading.text))
                i += 1; continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph(); blocks.append(.rule); i += 1; continue
            }

            if trimmed.hasPrefix(">") {
                flushParagraph()
                var quote: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    guard t.hasPrefix(">") else { break }
                    quote.append(String(t.dropFirst()).trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                blocks.append(.quote(quote.joined(separator: "\n")))
                continue
            }

            if isBullet(trimmed) {
                flushParagraph()
                var items: [String] = []
                while i < lines.count, isBullet(lines[i].trimmingCharacters(in: .whitespaces)) {
                    items.append(stripBullet(lines[i].trimmingCharacters(in: .whitespaces)))
                    i += 1
                }
                blocks.append(.bullet(items))
                continue
            }

            if isOrdered(trimmed) {
                flushParagraph()
                var items: [String] = []
                while i < lines.count, isOrdered(lines[i].trimmingCharacters(in: .whitespaces)) {
                    items.append(stripOrdered(lines[i].trimmingCharacters(in: .whitespaces)))
                    i += 1
                }
                blocks.append(.ordered(items))
                continue
            }

            paragraph.append(trimmed)
            i += 1
        }
        flushParagraph()
        return blocks
    }

    // MARK: Line classifiers

    static func parseHeading(_ s: String) -> (level: Int, text: String)? {
        var level = 0
        var idx = s.startIndex
        while idx < s.endIndex, s[idx] == "#", level < 6 {
            level += 1
            idx = s.index(after: idx)
        }
        guard level > 0, idx < s.endIndex, s[idx] == " " else { return nil }
        let text = String(s[s.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
        return (level, text)
    }

    static func isBullet(_ s: String) -> Bool {
        s.hasPrefix("- ") || s.hasPrefix("* ") || s.hasPrefix("+ ")
    }

    static func stripBullet(_ s: String) -> String {
        String(s.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    }

    static func isOrdered(_ s: String) -> Bool {
        s.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil
    }

    static func stripOrdered(_ s: String) -> String {
        guard let r = s.range(of: #"^\d+\.\s"#, options: .regularExpression) else { return s }
        return String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
    }
}
