import SwiftUI

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

/// Renders markdown with block-level layout (headings, lists, quotes, code) and
/// inline formatting (bold/italic/strikethrough/code/links) on the brand theme.
struct MarkdownText: View {
    private let blocks: [MarkdownBlock]

    init(_ source: String) {
        blocks = MarkdownParser.parse(source)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                render(block)
            }
        }
        .tint(Theme.accent) // link color
    }

    @ViewBuilder
    private func render(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(inline(text))
                .font(.system(size: headingSize(level), weight: .semibold, design: .serif))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, level <= 2 ? 4 : 0)

        case .paragraph(let text):
            Text(inline(text))
                .font(.body)
                .foregroundStyle(Theme.textPrimary)

        case .bullet(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(Theme.accent)
                        Text(inline(item)).foregroundStyle(Theme.textPrimary)
                    }
                    .font(.body)
                }
            }

        case .ordered(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(idx + 1).")
                            .foregroundStyle(Theme.accent)
                            .monospacedDigit()
                        Text(inline(item)).foregroundStyle(Theme.textPrimary)
                    }
                    .font(.body)
                }
            }

        case .quote(let text):
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.accent)
                    .frame(width: 3)
                Text(inline(text))
                    .font(.body)
                    .italic()
                    .foregroundStyle(Theme.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)

        case .code(let text):
            Text(text)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.md))

        case .rule:
            Rectangle()
                .fill(Theme.borderDefault)
                .frame(height: 1)
                .padding(.vertical, 2)
        }
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: 26
        case 2: 22
        case 3: 19
        default: 17
        }
    }

    /// Inline-only markdown so block markers we've already stripped don't recurse.
    private func inline(_ s: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: s, options: options)) ?? AttributedString(s)
    }
}
