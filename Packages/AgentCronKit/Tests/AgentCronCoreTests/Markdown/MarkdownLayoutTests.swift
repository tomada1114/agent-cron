@testable import AgentCronCore
import Foundation
import Testing

@Suite("MarkdownLayout")
struct MarkdownLayoutTests {
    private func blocks(_ text: String) -> [MarkdownBlock] {
        guard case let .blocks(blocks) = MarkdownLayout.render(text) else {
            Issue.record("expected blocks for \(text)")
            return []
        }
        return blocks
    }

    private func plain(_ text: AttributedString) -> String {
        String(text.characters)
    }

    private func markerText(_ marker: MarkdownListMarker) -> String {
        switch marker {
        case .bullet:
            "-"

        case let .ordinal(number):
            "\(number)."
        }
    }

    /// Blocks with inline text reduced to its characters, so parser-added attributes
    /// (such as a list delimiter) do not take part in the comparison.
    private func flat(_ text: String) -> [String] {
        blocks(text).map { block in
            switch block {
            case let .heading(level, text):
                "h\(level) \(plain(text))"

            case let .paragraph(text):
                "p \(plain(text))"

            case let .listItem(depth, marker, text):
                "li\(depth) \(markerText(marker)) \(plain(text))"

            case let .blockQuote(text):
                "> \(plain(text))"

            case let .codeBlock(code):
                "code \(code)"

            case let .table(table):
                "table \(table)"

            case .thematicBreak:
                "hr"
            }
        }
    }

    @Test
    func `empty text renders no blocks`() {
        #expect(MarkdownLayout.render("") == .blocks([]))
    }

    @Test(arguments: 1 ... 6)
    func `headings keep their level, including deeper than 3`(level: Int) throws {
        let result = blocks(String(repeating: "#", count: level) + " Title")
        let block = try #require(result.first)
        guard case let .heading(parsed, text) = block else {
            Issue.record("expected heading, got \(block)")
            return
        }
        #expect(parsed == level)
        #expect(plain(text) == "Title")
        #expect(text.presentationIntent == nil)
    }

    @Test
    func `the digest sample is a level-2 heading and one bulleted item`() {
        let result = blocks("## Today's digest\n- Swift 6.2 released")
        #expect(result.count == 2)
        guard case let .heading(level, heading) = result.first,
              case let .listItem(depth, marker, item) = result.last
        else {
            Issue.record("unexpected blocks \(result)")
            return
        }
        #expect(level == 2)
        #expect(plain(heading) == "Today's digest")
        #expect(depth == 1)
        #expect(marker == .bullet)
        #expect(plain(item) == "Swift 6.2 released")
    }

    @Test
    func `a paragraph keeps inline emphasis, code, and links`() throws {
        let result = blocks("Plain *em* `code` [link](https://example.com)")
        #expect(result.count == 1)
        guard case let .paragraph(text) = try #require(result.first) else {
            Issue.record("expected paragraph")
            return
        }
        #expect(plain(text) == "Plain em code link")
        let links = text.runs.compactMap(\.link)
        #expect(links == [URL(string: "https://example.com")])
        let intents = text.runs.compactMap(\.inlinePresentationIntent)
        #expect(intents.contains(.emphasized))
        #expect(intents.contains(.code))
    }

    @Test
    func `ordered lists carry ordinals`() {
        #expect(flat("1. one\n2. two") == ["li1 1. one", "li1 2. two"])
    }

    @Test
    func `nesting deeper than two levels is clamped to the second level`() {
        #expect(flat("- a\n  - b\n    - c\n      1. d") == [
            "li1 - a",
            "li2 - b",
            "li2 - c",
            "li2 1. d",
        ])
    }

    @Test
    func `a block quote, a thematic break, and a paragraph stay separate blocks`() {
        #expect(flat("> quoted\n\n---\n\nafter") == ["> quoted", "hr", "p after"])
    }

    @Test
    func `a fenced code block keeps its text without the trailing newline`() {
        #expect(blocks("```\nls -la\ncd /tmp\n```") == [.codeBlock("ls -la\ncd /tmp")])
    }

    @Test
    func `a table becomes padded monospaced rows`() {
        #expect(blocks("| a | bb |\n|---|---|\n| 111 | 2 |\n| 3 | 4 |") == [
            .table("a   | bb\n111 | 2\n3   | 4"),
        ])
    }

    @Test
    func `a parse failure falls back to the raw text`() {
        struct Failure: Error {}
        let rendering = MarkdownLayout.render("# raw *text*") { _ in throw Failure() }
        #expect(rendering == .raw("# raw *text*"))
    }

    @Test
    func `text with no block intent is a paragraph`() {
        #expect(MarkdownLayout
            .blocks(in: AttributedString("bare")) == [.paragraph(AttributedString("bare"))])
    }
}
