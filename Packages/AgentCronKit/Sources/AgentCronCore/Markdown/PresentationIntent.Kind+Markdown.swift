import Foundation

/// Pattern-match shorthands `MarkdownLayout` uses to classify a block.
extension PresentationIntent.Kind {
    var isTable: Bool {
        if case .table = self {
            return true
        }
        return false
    }

    var isTableRow: Bool {
        switch self {
        case .tableRow, .tableHeaderRow:
            true

        default:
            false
        }
    }

    var isCodeBlock: Bool {
        if case .codeBlock = self {
            return true
        }
        return false
    }

    var isList: Bool {
        self == .orderedList || self == .unorderedList
    }

    var headerLevel: Int? {
        if case let .header(level) = self {
            return level
        }
        return nil
    }

    var listOrdinal: Int? {
        if case let .listItem(ordinal) = self {
            return ordinal
        }
        return nil
    }
}
