import Foundation

/// Turns Markdown text into ``MarkdownRendering`` with Foundation's parser only
/// (ADR-0010). A parse failure never hides the text: it falls back to
/// ``MarkdownRendering/raw(_:)``.
public enum MarkdownLayout {
    /// The deepest list level laid out with its own indent.
    public static let maxListDepth = 2

    /// Parses `text` with `.full` syntax and walks it into blocks.
    public static func render(_ text: String) -> MarkdownRendering {
        render(text) { source in
            try AttributedString(
                markdown: source,
                options: .init(interpretedSyntax: .full, failurePolicy: .throwError),
            )
        }
    }

    /// The seam for a parse failure, which Foundation's parser gives no reliable input for.
    static func render(
        _ text: String,
        parse: (String) throws -> AttributedString,
    ) -> MarkdownRendering {
        guard !text.isEmpty else {
            return .blocks([])
        }
        do {
            return try .blocks(blocks(in: parse(text)))
        } catch {
            return .raw(text)
        }
    }

    static func blocks(in document: AttributedString) -> [MarkdownBlock] {
        var groups: [(intent: PresentationIntent?, text: AttributedString)] = []
        var previousKey: Int?
        for (intent, range) in document.runs[\.presentationIntent] {
            var slice = AttributedString(document[range])
            slice.presentationIntent = intent
            let key = groupingKey(intent)
            if let key, key == previousKey, !groups.isEmpty {
                groups[groups.count - 1].text.append(slice)
            } else {
                groups.append((intent, slice))
            }
            previousKey = key
        }
        return groups.map { group in block(intent: group.intent, text: group.text) }
    }

    /// Runs sharing a key form one block: a table's cells share the table, everything
    /// else its innermost block.
    private static func groupingKey(_ intent: PresentationIntent?) -> Int? {
        guard let intent else {
            return nil
        }
        let table = intent.components.first(where: \.kind.isTable)
        return table?.identity ?? intent.components.first?.identity
    }

    private static func block(
        intent: PresentationIntent?,
        text: AttributedString,
    ) -> MarkdownBlock {
        var inline = text
        inline.presentationIntent = nil
        let kinds = intent?.components.map(\.kind) ?? []
        if kinds.contains(where: \.isTable) {
            return .table(tableText(text))
        }
        if kinds.contains(where: \.isCodeBlock) {
            var code = String(text.characters)
            if code.hasSuffix("\n") {
                code.removeLast()
            }
            return .codeBlock(code)
        }
        if kinds.contains(.thematicBreak) {
            return .thematicBreak
        }
        if let listItem = listItem(kinds, inline) {
            return listItem
        }
        if let level = kinds.lazy.compactMap(\.headerLevel).first {
            return .heading(level: level, text: inline)
        }
        return kinds.contains(.blockQuote) ? .blockQuote(inline) : .paragraph(inline)
    }

    private static func listItem(
        _ kinds: [PresentationIntent.Kind],
        _ text: AttributedString,
    ) -> MarkdownBlock? {
        guard let itemIndex = kinds.firstIndex(where: { kind in kind.listOrdinal != nil }),
              let ordinal = kinds[itemIndex].listOrdinal
        else {
            return nil
        }
        let depth = kinds.count(where: \.isList)
        let isOrdered = kinds[(itemIndex + 1)...].first(where: \.isList) == .orderedList
        return .listItem(
            depth: min(max(depth, 1), maxListDepth),
            marker: isOrdered ? .ordinal(ordinal) : .bullet,
            text: text,
        )
    }

    /// Flattens a table's cells into rows of left-padded columns joined by `" | "`.
    private static func tableText(_ table: AttributedString) -> String {
        var rows: [[String]] = []
        var previousRow: Int?
        for (intent, range) in table.runs[\.presentationIntent] {
            let row = intent?.components.first(where: \.kind.isTableRow)?.identity
            let cell = String(table[range].characters)
            if row == previousRow, !rows.isEmpty {
                rows[rows.count - 1].append(cell)
            } else {
                rows.append([cell])
            }
            previousRow = row
        }
        let columnCount = rows.map(\.count).max() ?? 0
        let widths = (0 ..< columnCount).map { column in
            rows.map { cells in column < cells.count ? cells[column].count : 0 }.max() ?? 0
        }
        return rows.map { cells in paddedRow(cells, widths: widths) }.joined(separator: "\n")
    }

    private static func paddedRow(_ cells: [String], widths: [Int]) -> String {
        let padded = cells.enumerated().map { index, cell in
            index == cells.count - 1 ? cell : cell.padding(
                toLength: widths[index],
                withPad: " ",
                startingAt: 0,
            )
        }
        return padded.joined(separator: " | ")
    }
}
