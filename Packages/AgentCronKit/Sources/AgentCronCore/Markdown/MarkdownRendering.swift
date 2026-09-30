/// What a run result renders as: laid-out blocks, or the raw text when parsing failed.
public enum MarkdownRendering: Equatable, Sendable {
    case blocks([MarkdownBlock])
    case raw(String)
}
