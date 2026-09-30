# ADR-0010: Render run results as Markdown without a dependency

- **Status:** Accepted 2026-09-30
- **Date:** 2026-09-29
- **Deciders:** the owner

## Context

The run detail shows the agent's final result rendered as Markdown with a Raw toggle
(`docs/product/ux-flows.md` S3). Agent results use headings, lists, code blocks, and
links. The template ships zero dependencies.

## Decision drivers

- No new dependency (README › Design Philosophy); adding one needs the owner's sign-off.
- Readable reports; a broken render must never hide the text.

## Considered options

1. **Foundation's Markdown parser + a small block renderer in `AgentCronUI`** —
   `AttributedString(markdown:options:)` with `.full` syntax, then walk runs by
   `presentationIntent` to lay out headings, lists, quotes, and code blocks.
2. **A Markdown rendering package** (for example swift-markdown-ui) — richest output, a
   new dependency.
3. **Plain monospaced text only** — rejected by the owner.

## Decision

Option 1, proposed. Supported blocks: headings (1–3 styled, deeper as bold), paragraphs,
ordered and unordered lists (two levels), block quotes, fenced code (monospaced, no
syntax color), thematic breaks, and inline emphasis, code, and links. Tables render as
monospaced text. On a parse failure the view falls back to Raw. Text stays selectable.

## Consequences

### Positive

- No dependency; the parser is Apple's.

### Negative

- Our renderer, our bugs: a layout that looks off is ours to fix.

### Follow-ups

- Block renderer + previews per block type (issue).

## Open questions

- Unverified: that SwiftUI `Text` does not lay out block-level intent by itself (the
  reason a renderer is needed); confirm in the renderer issue's first preview.

## Sources

- <https://developer.apple.com/documentation/foundation/attributedstring/markdownparsingoptions/interpretedsyntax-swift.enum/full> — `.full` interprets the full Markdown syntax; macOS 12+ — checked 2026-09-29
- <https://developer.apple.com/documentation/foundation/attributescopes/foundationattributes/presentationintent> — block intent (paragraphs, lists, block quotes, tables) on runs; macOS 12+ — checked 2026-09-29

## Related

- None.
