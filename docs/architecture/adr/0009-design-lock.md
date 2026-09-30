# ADR-0009: Design lock — a precise instrument panel

- **Status:** Accepted 2026-09-29
- **Date:** 2026-09-29
- **Deciders:** the owner

## Context

Every screen (`docs/product/ux-flows.md` S1–S7) needs the same answer to "what does this
look like?". The owner chose the direction in the kickoff: a near-achromatic,
system-native instrument panel with one brand hue, system outcome colors, SF Symbols,
and a placeholder app icon. The research, references, and measured contrast are in
`docs/design/design-direction.md`; this ADR is the binding lock (`designing-ui`).

## Decision drivers

- System first, custom by exception (`designing-ui`).
- Outcome state never carried by color alone (`docs/design/ux-guidelines.md` ›
  Accessibility targets).

## Considered options

1. **Precise instrument panel** (primary reference Cron Calendar) — one brand hue for the
   app's own action and activity, figures in monospaced digits.
2. **Organized desktop** (Things) — system accent only, no brand hue.
3. **Terminal texture** (Warp) — SF Mono across the UI.

## Decision

Option 1, chosen by the owner; brand hue deep teal, chosen over vermilion (collides with
timed out and failed) and graphite (running state too quiet).

- **Accent color:** `AccentColor.colorset` Any `#0E7C7B`, Dark `#0F7F7D` (sRGB): prominent
  buttons (Run Now, Save), selection, app icon. Carries no meaning — the user's Accent
  setting may replace it.
- **Custom colors:** `RunningTint.colorset` Any `#0B6E6D`, Dark `#4FC7BE`: the running
  glyph and "Running · m:ss" text only. Nothing else custom.
- **Outcome colors and glyphs:** succeeded `Color.green` `checkmark.circle.fill`;
  failed `Color.red` `xmark.circle.fill`; timed out `Color.orange` `timer`; stopped
  `.secondary` `stop.circle`; skipped `.secondary` `arrow.uturn.right.circle`; running
  `RunningTint` `circle.dotted`; upcoming `.tertiary` `circle`; bypass badge
  `Color.red` `exclamationmark.triangle.fill` + "Bypass". Always glyph + label.
- **Type:** system font only. `.title2` window section heading; `.title3` semibold job
  name in the detail header; `.headline` form section headers; `.body` content;
  `.callout` `.secondary` for schedule summary, next run, cost; `.footnote` notes. Times,
  durations, costs `.monospacedDigit()`. Prompt editor and paths `.body.monospaced()`.
- **Spacing scale:** 4, 8, 16, 24 pt — 4 inside a row, 8 between related controls, 16
  between groups and popover sections, 24 content-to-edge in detail panes; popover inner
  padding 12 (8 + 4).
- **Density:** regular; `.inset` lists in the main window; popover rows 28 pt.
- **Corner radius:** system for controls and lists; 6 pt for weekday chips, the popover
  banner, and the bypass badge.
- **Symbols:** SF Symbols only; hierarchical in toolbar and sidebar, monochrome +
  outcome color in lists, template in the status item.
- **Status item:** one symbol, priority running `clock.fill` > manual keep-awake
  `cup.and.saucer` > idle `clock`; unseen failure adds a red dot overlay.
- **Materials:** system popover and sidebar materials only.
- **Window sizing:** main window min 860 × 560 pt, default 1040 × 680 pt; popover 340 pt
  wide, height to content up to 520 pt.
- **Motion:** 150 ms for row insert/remove and disclosure; symbol swaps, no continuous
  spin; Reduce Motion → instant.
- **Copy style:** Title Case for buttons, menu items, window and section titles;
  sentence case for labels, descriptions, alerts, empty states. Voice: precise and
  quiet.
- **App icon:** placeholder until distribution (ADR-0011).
- Shared values live in one internal `DesignLock` type in `AgentCronUI` once a second
  view needs them (`designing-ui` › Sharing values between views).

## Consequences

### Positive

- Every screen is built against fixed values; contrast is already measured.

### Negative

- The status-item priority hides a manual keep-awake while a job runs (the popover still
  shows it).

### Follow-ups

- Apply the tokens: `AccentColor`, `RunningTint`, `DesignLock` (issue).

## Open questions

- The status-item composition at 18 pt needs a visual check on the first build.

## Sources

- `docs/design/design-direction.md` — references, decision ledger, measured contrast
  (8/8 pairs pass WCAG AA) (in-repo).
- <https://developer.apple.com/design/human-interface-guidelines/color> — semantic
  colors, the multicolor accent rule — as cited by `designing-ui`, checked 2026-09-28.

## Related

- [ADR-0001](0001-menu-bar-agent-with-a-main-window.md) — the shape the lock applies to.
