import AgentCronCore
import SwiftUI

/// One laid-out Markdown block, styled per ADR-0010.
struct MarkdownBlockView: View {
    /// Headings 1-3 in order; deeper headings fall back to bold body text.
    private static let headingFonts: [Font] = [.title3, .headline, .subheadline.bold()]
    private static let quoteBarWidth: CGFloat = 2

    let block: MarkdownBlock

    var body: some View {
        switch block {
        case let .heading(level, text):
            Text(text).font(headingFont(level))

        case let .paragraph(text):
            Text(text)

        case let .listItem(depth, marker, text):
            HStack(alignment: .firstTextBaseline, spacing: DesignLock.spacingXS) {
                Text(verbatim: markerText(marker))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text(text)
            }
            .padding(.leading, DesignLock.spacingM * CGFloat(depth - 1))

        case let .blockQuote(text):
            Text(text)
                .foregroundStyle(.secondary)
                .padding(.leading, DesignLock.spacingS)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(width: Self.quoteBarWidth)
                }

        case let .codeBlock(code):
            monospacedBox(code)

        case let .table(table):
            monospacedBox(table)

        case .thematicBreak:
            Divider()
        }
    }

    private func monospacedBox(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.body.monospaced())
            .padding(DesignLock.spacingS)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary, in: RoundedRectangle(cornerRadius: DesignLock.chipCornerRadius))
    }

    private func headingFont(_ level: Int) -> Font {
        Self.headingFonts.indices.contains(level - 1) ? Self.headingFonts[level - 1] : .body.bold()
    }

    private func markerText(_ marker: MarkdownListMarker) -> String {
        switch marker {
        case .bullet:
            "•"

        case let .ordinal(number):
            "\(number)."
        }
    }
}
