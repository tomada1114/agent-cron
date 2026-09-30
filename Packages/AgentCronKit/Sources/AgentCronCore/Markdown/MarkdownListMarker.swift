/// The marker in front of a list item.
public enum MarkdownListMarker: Equatable, Sendable {
    case bullet
    case ordinal(Int)
}
