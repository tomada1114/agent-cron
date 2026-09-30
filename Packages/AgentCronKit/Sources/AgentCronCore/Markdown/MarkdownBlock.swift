import Foundation

/// One block of a run result laid out for display, walked from Foundation's
/// `presentationIntent` (ADR-0010). Inline emphasis, code, and links stay in each
/// block's `AttributedString`.
public enum MarkdownBlock: Equatable, Sendable {
    case blockQuote(AttributedString)
    /// A fenced or indented code block, without its trailing newline.
    case codeBlock(String)
    /// A heading; `level` is 1 through 6 as written.
    case heading(level: Int, text: AttributedString)
    /// A list item. `depth` is 1 or 2: deeper nesting is clamped to 2 (ADR-0010).
    case listItem(depth: Int, marker: MarkdownListMarker, text: AttributedString)
    case paragraph(AttributedString)
    /// A table flattened to monospaced text: one line per row, columns padded.
    case table(String)
    case thematicBreak
}
