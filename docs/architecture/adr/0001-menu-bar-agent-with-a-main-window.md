# ADR-0001: A menu-bar agent with one main window

- **Status:** Accepted 2026-09-29
- **Amended:** 2026-09-30 — the activation-policy and launch-at-login adapters landed behind their Core ports (#17); Sources record what their local-machine tests checked. Wiring them in `App/` is #28.
- **Date:** 2026-09-29
- **Deciders:** the owner

## Context

AgentCron fires scheduled agent runs itself (ADR-0003), so it must be running whenever
the user is logged in, and it is glanced at far more often than it is edited. The
template ships a regular windowed app (`WindowGroup`, a Dock tile); the requirements
(`docs/product/requirements.md` §3.7) and wireframes (`docs/product/ux-flows.md` S1–S4)
ask for a status item with a rich popover and a separate main window with a sidebar
(Jobs, History, General).

## Decision drivers

- The core interaction in `AGENTS.md` › Product: glance at the menu bar for what runs
  next and how recent runs went.
- The app must survive a reboot without the user remembering to open it.
- Every command must still be reachable from a menu with its shortcut
  (`docs/design/ux-guidelines.md` › Platform conventions).

## Considered options

1. **Menu-bar agent + one main window** — `LSUIElement`, `MenuBarExtra` in `.window`
   style, and a single `Window` scene for Jobs / History / General.
2. **Regular windowed app with a status item** — Dock tile always visible.
3. **Menu-bar only** — everything, including the job editor, inside the popover.

## Decision

Option 1.

- `project.yml`: `INFOPLIST_KEY_LSUIElement: YES` on the app target
  (`.agents/skills/starting-an-app/references/app-shapes.md`).
- Scenes in `App/AgentCronApp.swift`: `MenuBarExtra` with `.menuBarExtraStyle(.window)`
  for the popover (`ux-flows.md` S1), and one `Window` scene (id `main`) for the main
  window; "Settings…" (⌘,) opens that window on General rather than a separate
  `Settings` scene, so the app has one window to reason about.
- While the main window is open the app switches its activation policy to `.regular`
  so its main menu (File / Job / View commands, `ux-flows.md` §4) and ⌘Tab entry
  appear, and back to `.accessory` when the window closes. This is an adapter in
  `AgentCronPlatform` (`NSApplication.setActivationPolicy`) behind a Core port,
  driven by the window's open/close.
- Launch at login: `SMAppService.mainApp` in an `AgentCronPlatform` adapter behind a
  Core `LoginItemControlling` port; registered on first launch (requirements §3.7),
  switchable in General.
- `LaunchUITests/LaunchTests.swift` asserts the status item, per app-shapes.md.

Option 2 puts a permanent Dock tile on an app the user mostly never opens. Option 3
cannot hold the job editor, history, and Markdown result the wireframes need at a
readable size.

## Consequences

### Positive

- The status item is the whole resident footprint; the main window is there when
  editing.
- Menu commands and shortcuts work whenever the main window is open.

### Negative

- A Dock tile appears while the main window is open (the cost of showing a main menu
  from an agent app).
- `.window`-style popover content is invisible to XCUITest (app-shapes.md › What
  XCUITest can and cannot see); popover behavior is covered by Core view-model tests.

### Follow-ups

- Convert the app shape: `project.yml` key, scenes, launch test (issue).
- Activation-policy switching and launch-at-login adapters (issues).

## Open questions

- Unverified until the first build: that an `LSUIElement` app shows its main menu only
  after switching to `.regular`; settle with `just run` on the conversion issue.

## Sources

- <https://developer.apple.com/documentation/swiftui/menubarextra> — macOS 13+; `.window` style renders contents in a popover-like window — checked 2026-09-29
- <https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement> — an agent app that runs in the background and does not appear in the Dock; says nothing about the main menu — checked 2026-09-29
- <https://developer.apple.com/documentation/servicemanagement/smappservice> — macOS 13+; `mainApp` as a login item, `register()`, `status` (not registered / enabled / requires approval / not found), `openSystemSettingsLoginItems()` — checked 2026-09-29
- Checked 2026-09-30 by `ActivationPolicyControllerTests` and `LoginItemControllerTests` (`just test-local`): `NSApplication.setActivationPolicy(_:)` switched the `swift test` host between `.regular` and `.accessory` and back, as AppKit then reported; `SMAppService.mainApp.status` read as not found in that host, which is not an app bundle. Registering was not run (it changes the user's login items), so the main menu appearing and `register()` from the real app remain for the `just run` check the wiring issue owes.
- `.agents/skills/starting-an-app/references/app-shapes.md` (in-repo) — the proven menu-bar agent files

## Related

- [ADR-0003](0003-in-app-scheduler.md) — why the app must stay running.
