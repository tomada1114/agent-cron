import AgentCronCore
import SwiftUI

/// A run result rendered as Markdown (ADR-0010): `MarkdownLayout` decides the blocks,
/// this view only styles them. A parse failure shows the text raw, and all text is
/// selectable.
public struct MarkdownResultView: View {
    private let rendering: MarkdownRendering

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignLock.spacingS) {
            switch rendering {
            case let .blocks(blocks):
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    MarkdownBlockView(block: block)
                }

            case let .raw(text):
                Text(verbatim: text)
                    .font(.body.monospaced())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .accessibilityIdentifier("markdownResult")
    }

    /// The view for a run's result text.
    public init(text: String) {
        rendering = MarkdownLayout.render(text)
    }

    /// A given rendering, so a preview can show the raw fallback that Foundation's
    /// parser gives no reliable input for.
    init(rendering: MarkdownRendering) {
        self.rendering = rendering
    }
}

#Preview("headings") {
    MarkdownResultView(text: "# Level 1\n## Level 2\n### Level 3\n#### Level 4\n###### Level 6")
        .padding()
}

#Preview("paragraph") {
    MarkdownResultView(text: "Two runs finished.\n\nThe second paragraph follows a blank line.")
        .padding()
}

#Preview("lists") {
    MarkdownResultView(text: "- one\n  - nested\n    - third level\n1. first\n2. second").padding()
}

#Preview("quote") {
    MarkdownResultView(text: "> Dependabot PR #12 was left open: it bumps a major version.")
        .padding()
}

#Preview("code") {
    MarkdownResultView(text: "```\nls -la\n```").padding()
}

#Preview("break") {
    MarkdownResultView(text: "Above\n\n---\n\nBelow").padding()
}

#Preview("inline") {
    MarkdownResultView(
        text: "Some *emphasis*, **strong**, `code`, and a [link](https://www.swift.org).",
    )
    .padding()
}

#Preview("table") {
    MarkdownResultView(text: "| a | b |\n|---|---|\n| 1 | 2 |").padding()
}

#Preview("digest sample") {
    MarkdownResultView(text: """
    ## Today's digest
    - Swift 6.2 released with *approachable concurrency*
    - Xcode beta adds `#Preview` improvements — [notes](https://developer.apple.com)

    ### Merged
    1. Bump actions/checkout
    2. Bump swiftlint

    ---

    ```
    git log --oneline -2
    ```
    """).padding()
}

#Preview("invalid") {
    MarkdownResultView(rendering: .raw("# not rendered\nshown raw on a parse failure")).padding()
}

#Preview("empty") {
    MarkdownResultView(text: "").padding()
}
