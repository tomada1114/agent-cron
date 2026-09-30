# AgentCron — Design direction

- **Status:** research record (stage 3). The binding design lock is written in stage 7 as
  an ADR under `docs/architecture/adr/`, per the template's `designing-ui` skill; this file
  is its source.
- **Inputs:** `docs/product/requirements.md`, `docs/product/ux-flows.md`,
  `docs/design/ux-guidelines.md`, template `designing-ui` (system first, custom by
  exception).
- **Research:** Refero styles, 3 searches (developer-tool dark products; native macOS
  utility sites; scheduling/monitoring products), ~25 previews reviewed, 2 full styles
  retrieved (Cron Calendar `0528b40d…`, Things `0796cd74…`). Refero styles cover web
  marketing pages, not native app screens, so they set visual language only; screen
  structure comes from `ux-flows.md` and the HIG.

## Direction: a precise instrument panel

A time-keeping instrument that sits in the menu bar: almost achromatic, native controls,
figures that line up, and one calm brand hue that appears only where the app itself is
acting. Nothing decorates; state is carried by glyph + label + system color.

### Reference lock

- **Primary reference:** Cron Calendar (cron.com) — "minimal dark cockpit": near-achromatic
  surfaces, crisp type hierarchy by weight rather than color, a single vivid accent kept
  to primary actions and tiny highlights, low-radius precise controls.
- **Preserve:**
  1. Single chromatic brand color, used only for the app's own action/activity (never for
     decoration, never for state meaning).
  2. Hierarchy by weight and size of one typeface (system font), not by color.
  3. Figures aligned like an instrument: times, durations, costs in monospaced digits.
  4. Flat surfaces; depth from system materials only (popover, sidebar), no custom shadows.
  5. Small, precise radii — system control radii; custom elements 6 pt.
- **Borrow only:**
  - From Things (culturedcode.com/things): the calm, organized-desktop density — system
    font, generous group spacing (16 pt between groups), native sidebar — so the settings
    window reads as a Mac app, not a dashboard.
  - From Warp (warp.dev): monospace only where the content *is* code-like — the prompt
    editor and directory paths — not across the UI.
- **Role rules:**
  - Brand teal = AccentColor: prominent button fill (Run Now, Save), selection where the
    system uses the accent, the app icon. On macOS the app accent shows only with the
    multicolor Accent setting; any other setting replaces it, so the accent carries no
    meaning.
  - RunningTint (custom Color Set, fixed hue): the "running" glyph and "Running · 4:12"
    text only. It is the one custom color that carries meaning, always paired with ◌ and
    the word "Running".
  - Outcome colors are system colors, never the brand color (see table).
- **Media strategy:** no imagery. Status item and all icons are SF Symbols; the app icon
  is a placeholder until distribution is decided.
- **Reject:** orange brand (collides with timed-out/warning), green or red brand (collide
  with succeeded/failed), dark-only canvas copied from the web references (the app follows
  system appearance), gradients and glows, custom fonts, monospace UI chrome.

## Decision ledger

| Decision | Source | Role rule | Why |
|---|---|---|---|
| One brand hue, action/activity only | Cron Calendar "Do: limit chromatic color to the CTA" | brand never marks state | keeps outcome colors unambiguous |
| Hue = deep teal, not orange | user choice after measurement | — | orange = timed out, red = failed, green = succeeded in system semantics |
| Outcome colors = system colors | user choice; template `designing-ui` (semantic colors) | glyph + label always accompany | light/dark/Increase Contrast handled by the OS |
| System font, weight-led hierarchy | Cron (one family, weight contrast); Things (ui-sans-serif only) | — | native feel, no license, honors accessibility text settings |
| Monospaced digits for time figures | primary-reference trait "instrument"; craft (tabular figures) | figures only | timeline and history columns align |
| SF Mono for prompt editor and paths | Warp (code-native surfaces) | code-like content only | prompts are instructions to an agent; paths are copied |
| Flat surfaces, system materials | Cron "avoid shadows"; HIG materials | popover + sidebar only | no custom elevation to maintain |
| Status item = SF Symbols variants | user choice | glyph variant per state | no custom asset for MVP |

## Token values (target: the design-lock fields)

| Field | Value |
|---|---|
| Accent color | `AccentColor.colorset` — Any `#0E7C7B`, Dark `#0F7F7D` (sRGB). Used for prominent buttons, selection, app icon. |
| Custom colors | `RunningTint.colorset` — Any `#0B6E6D`, Dark `#4FC7BE`: running glyph and running text only. Nothing else custom. |
| Outcome colors | succeeded `Color.green` (systemGreen) · failed `Color.red` · timed out `Color.orange` · stopped `.secondary` · skipped `.secondary` · running `RunningTint` · upcoming `.tertiary` · bypass badge `Color.red` with ⚠ + "Bypass" |
| Outcome glyphs (SF Symbols) | succeeded `checkmark.circle.fill` · failed `xmark.circle.fill` · timed out `timer` · stopped `stop.circle` · skipped `arrow.uturn.right.circle` · running `circle.dotted` (static under Reduce Motion) · upcoming `circle` · bypass `exclamationmark.triangle.fill` |
| Type | System font only. Window section heading `.title2`; job name in detail header `.title3` semibold; section headers in forms `.headline`; content `.body`; secondary facts (schedule summary, next run, cost) `.callout` `.secondary`; timeline rows `.body` with times `.monospacedDigit()`; footnotes `.footnote`. Prompt editor and directory paths `.body.monospaced()`. No fixed-size display text. |
| Spacing scale | 4, 8, 16, 24 pt. 4 inside a row (glyph ↔ label), 8 between related controls, 16 between form groups and popover sections, 24 from content to window edge in detail panes. Popover inner padding 12 pt (8 + 4). |
| Density | Regular; `.controlSize(.regular)`; lists `.inset` style in the main window, plain rows in the popover. Popover row height 28 pt. |
| Corner radius | System default for controls and lists; custom elements (weekday chips, popover banner, bypass badge) 6 pt. |
| Symbols | SF Symbols only. Hierarchical rendering in toolbars and sidebar; monochrome + outcome color in lists and timeline; template (monochrome) in the status item. |
| Materials | Popover: system `MenuBarExtra` window material. Sidebar: system sidebar material. No other materials. |
| Status item | Priority order, one symbol at a time: running `clock.fill` > manual keep-awake active `cup.and.saucer` > idle `clock`. Unseen failure adds a small red dot overlay to whichever symbol shows. Template rendering; validated at 18 pt in both menu-bar appearances during implementation. |
| Window sizing | Main window min 860 × 560 pt, default 1040 × 680 pt. Popover fixed width 340 pt, height to content up to 520 pt. |
| Motion | Restrained per `ux-guidelines.md`: 150 ms row insert/remove and disclosure; status item swaps symbol variants, no continuous spin. Reduce Motion → instant. |
| Copy style | Title case for buttons, menu items, window and section titles ("Run Now", "Delete Job…"); sentence case for labels, descriptions, alerts, empty states. Voice: precise and quiet — states facts, never cheers. |
| App icon | Placeholder until distribution; direction when made: teal instrument dial on graphite. |

## Measured contrast

Pairs file: `docs/design/contrast-pairs.json` (window backgrounds approximated as
`#ECECEC` light / `#1E1E1E` dark, list and popover `#FFFFFF` / `#2B2B2B`; re-measure
against screenshots during implementation). System colors are not measured here — the OS
guarantees them and adapts them to Increase Contrast.

```
name                                                      fg       bg       kind  ratio  required  result
--------------------------------------------------------  -------  -------  ----  -----  --------  ------
Light: white label on AccentColor (prominent button)      #FFFFFF  #0E7C7B  text  5.01   4.50      PASS
Light: AccentColor fill vs window bg                      #0E7C7B  #ECECEC  ui    4.24   3.00      PASS
Light: RunningTint text on window bg                      #0B6E6D  #ECECEC  text  5.13   4.50      PASS
Light: RunningTint text on white list bg                  #0B6E6D  #FFFFFF  text  6.06   4.50      PASS
Dark: white label on AccentColor dark (prominent button)  #FFFFFF  #0F7F7D  text  4.83   4.50      PASS
Dark: AccentColor dark fill vs window bg                  #0F7F7D  #1E1E1E  ui    3.46   3.00      PASS
Dark: RunningTint text on window bg                       #4FC7BE  #1E1E1E  text  8.13   4.50      PASS
Dark: RunningTint text on popover/list bg                 #4FC7BE  #2B2B2B  text  6.91   4.50      PASS
```

## Open

- Refero screen and flow research not run: the screens are native macOS surfaces Refero's
  screen library (web/iOS) does not cover; structure was settled in `ux-flows.md`.
- Status-item symbol composition (keep-awake + running + failure dot at once) needs a
  visual check at 18 pt.
