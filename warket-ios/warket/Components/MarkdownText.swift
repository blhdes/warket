import SwiftUI

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
        .environment(\.openURL, OpenURLAction { $0.isWebLink ? .systemAction : .discarded })
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
