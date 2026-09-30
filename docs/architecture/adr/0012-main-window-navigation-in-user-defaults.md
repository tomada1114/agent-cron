# ADR-0012: Remember the main window's navigation in UserDefaults

- **Status:** Proposed
- **Date:** 2026-09-30
- **Deciders:** the owner

## Context

The main window remembers its selected section, selected job, and selected run across
launches (`docs/design/ux-guidelines.md` › Navigation; issue #19's REQ-002). ADR-0005
keeps jobs and runs as JSON files and rejected `UserDefaults` for them because it is not
meant for history-sized data; it says nothing about small UI state. `UserDefaults` keys
are contract (`docs/architecture.md` › What is contract and what is private), and
choosing `UserDefaults` at all is a persistence decision, so the first keys owe this
record. The window's size, position, and sidebar width are already restored by the
system: a running build stores them as `NSWindow Frame main` and
`NSSplitView Subview Frames main, SidebarNavigationSplitView` in the same domain, with no
code of this app's asking for it (observed 2026-09-30).

## Decision drivers

- A restore that a Core test can drive with an injected store (`just test`), so the
  first-launch default and the "stored job no longer exists" rule sit under the coverage
  floor.
- No new port or dependency for three small values.
- The main menu acts on the navigation while the window is closed (Settings… ⌘, picks
  General before the window draws), so the state cannot live only inside the window's
  view tree.

## Considered options

1. **`UserDefaults`, read and written by a Core model** — `MainNavigationModel` takes a
   `UserDefaults` (default `.standard`); tests hand it a throwaway suite.
2. **SwiftUI `@SceneStorage` in the view** — per-scene restoration owned by SwiftUI.
3. **A field in `jobs.json`** — the ADR-0005 document.

## Decision

Option 1, proposed. Three keys in the app's standard domain, written on every change:

| Key | Value | Absent means |
|---|---|---|
| `mainWindow.section` | `String`, a `MainSection` raw value: `jobs`, `history`, `general` | Jobs |
| `mainWindow.selectedJobID` | `String`, a job's `UUID` | no job selected |
| `mainWindow.selectedRunID` | `String`, a run's `UUID` | no run selected |

A value that cannot be read back restores as its "absent" state. A stored job or run
that no longer exists is cleared once the screen that loads jobs or runs reports what
exists (`knownJobsChanged(to:)`, `knownRunsChanged(to:)`).

The same domain holds one more contract key, written by `AppLifecycleModel` (issue #17)
and read the same way, through an injected `UserDefaults`:

| Key | Value | Absent means |
|---|---|---|
| `didRegisterLoginItemOnFirstLaunch` | `Bool`, `true` once the first launch has tried to register launch at login, whether or not the OS allowed it | the first launch has not happened: register, then set it |

Once it is set the app never registers on its own again, so a user who turned launch
at login off stays off (requirements §3.7).

Option 2 keeps the state in the view, where no Core test reaches it, and the menu
commands would need it from outside the window's scene. Option 3 couples a UI preference
to the scheduler's document, whose writes and schema version exist for jobs.

## Consequences

### Positive

- The restore rules are Core tests over a scratch suite; nothing new to fake.
- A launch argument (`-mainWindow.section history`) starts the app on a section for
  that launch only, through `UserDefaults`' argument domain.

### Negative

- Renaming a `MainSection` case or a key resets the user's saved navigation unless Core
  migrates the old value.
- Renaming or removing `didRegisterLoginItemOnFirstLaunch` makes the next launch
  register launch at login again, overriding a user who had turned it off.

### Follow-ups

- The Jobs (#21) and History (#24) screens call `knownJobsChanged(to:)` and
  `knownRunsChanged(to:)` after they load.

## Open questions

- None.

## Sources

- `docs/architecture.md` › What is contract and what is private (in-repo).
- [ADR-0005](0005-json-files-in-application-support.md) (in-repo).

## Related

- [ADR-0005](0005-json-files-in-application-support.md) — the persistence this sits beside.
- [ADR-0001](0001-menu-bar-agent-with-a-main-window.md) — the one main window whose
  navigation this is.
