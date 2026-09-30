# UX guidelines

| | |
|---|---|
| Product | AgentCron |
| Platforms | macOS (menu-bar agent; deployment target per the template) |
| App type | Developer tools + AI agent UI (unattended runs, not chat) |
| Related | Requirements: `docs/product/requirements.md` · UX flows: `docs/product/ux-flows.md` · Design direction: `docs/design/design-direction.md` |

## Principles

- **Nothing runs that the user did not save** — a scheduled run always uses the last saved
  job. Decides: explicit Save over live-apply. Gives up: the zero-click feel of System
  Settings.
- **Quiet until something needs you** — success is silent unless a job opts in; failure
  is visible in three places (history, popover banner, notification per job). Decides:
  error severity split, restrained motion. Gives up: a "busy" feeling that the app is
  working.
- **Every run is explainable afterwards** — a run keeps the prompt, options, and result it
  ran with. Decides: run detail snapshots over live job references. Gives up: a little
  storage.

## Navigation

- Model: one main window with a left sidebar (Jobs ⌘1, History ⌘2, General ⌘3) and a
  list + detail split in each section (`ux-flows.md` S2–S4). The popover is a launcher
  and status glance, never an editor.
- The window remembers its size, position, sidebar width, selected section, and selected
  job across launches.
- Links between sections (popover row → run, run → its job, "Show all in History") select
  the target and reveal it in the list; the History filter is set to that job when coming
  from a job.

## Platform conventions

- **macOS:** every command is in the app menu with its shortcut (`ux-flows.md` §4);
  toolbar buttons are shortcuts to menu items. Settings… (⌘,) opens the General section of
  the main window. No Dock icon (`LSUIElement`); opening the window activates the app so
  its menu bar appears. Standard controls (`Form`, `Toggle`, `Picker`, `TextEditor`) are
  used wherever one exists, so system focus rings, VoiceOver, and Full Keyboard Access come
  free. Popover closes on focus loss and Esc.

## States

| State | Trigger | Shows | Primary action | Copy pattern |
|---|---|---|---|---|
| First-run empty (jobs) | no job exists | what a job is + one CTA | New Job ⌘N | "No jobs yet. A job runs an agent prompt in a folder on a schedule." |
| First-run empty (history) | no run exists | what appears here | Open Jobs | "No runs yet. Runs appear here after a job runs." |
| Filtered to zero | history filters match nothing | — | Clear Filters | "No runs match these filters." |
| Nothing today (popover) | no runs today | next scheduled run | — | "Nothing scheduled today. Next: [day time] [job]." |
| All paused (popover) | every job disabled | — | Open Jobs | "All jobs are paused." |
| Agent not found | `claude` does not resolve in `zsh -l` | banner in popover + ✗ row in General | Open General / Check Again | "claude was not found in your login shell." |
| Folder missing | job directory no longer exists | inline warning on the Directory row | Choose… | "This folder no longer exists." |
| Notifications denied | user refused notification permission | inline note under each job's Notify row when it is not "None" | Open System Settings | "Notifications are off for AgentCron in System Settings." |
| Unseen failures | failed/timed-out/skipped runs since the popover was last opened | banner at top of popover; status-item dot | View | "[n] failed run(s) since you last looked." |
| Running | a job's process is alive | elapsed time (updated every 1 s), Stop | Stop ⌘. | "Running · 4:12" |

## Feedback and loading

| Rule | Value |
|---|---|
| Loading indicator delay | Local data loads synchronously; the only waits are the agent check and process start. No indicator under 300 ms; inline spinner on that row after 300 ms, kept at least 500 ms. |
| Save | Explicit. While the editor differs from the saved job: "Edited" label in the detail header, [Revert] and [Save ⌘S] enabled. Switching job, section, or closing the window with unsaved edits asks "Save changes to "[name]"?" [Don't Save] [Cancel] [Save]. |
| Edits while running | Saving is allowed; a note under the header says "Changes apply from the next run." |
| Destructive actions | Delete Job confirms (alert, `ux-flows.md` S5). Stop runs immediately without confirmation (the run is recorded as stopped). Choosing `bypassPermissions` confirms (S6). |
| Error placement | Input errors → inline below the field. Run failures → history + popover banner + notification per job setting. Blocking app errors (cannot read or write the data store) → alert with the reason and [Quit] / [Try Again]. No toasts. |
| Notifications | One per finished run that matches the job's setting; never grouped; click opens the run in History. |

## Forms and validation

- Timing: validate a field when focus leaves it; once it shows an error, re-validate on
  every change so the error clears as soon as it is fixed. Save validates all fields.
- Rules (from requirements §3.1): Name required, 1–60 characters; Directory required and
  existing; Prompt non-empty after trimming; at least one day and one time; times unique
  within a job; Timeout integer 1–1440 minutes.
- Errors: below the field in secondary-red text, with the field's accessibility label
  including the error; the message says what to fix ("Choose at least one day.").
- Failed Save: focus moves to the first invalid field; nothing is saved.
- Save stays enabled while edits exist; input is never cleared on error.
- Required is the default; no field is marked optional (all optional fields have a
  "Default" choice instead).

## Motion

- Amount: restrained — state changes and disclosure only.
- Durations: 150 ms for row insert/remove and disclosure; popover open/close is the
  system's. The running indicator on the status item changes symbol variant, it does not
  spin continuously.
- Reduced motion: every animation becomes an instant change; the running indicator stays
  static (filled variant).

## Language and copy

- UI languages: English (development language) and Japanese, following the system
  language via the String Catalog; no in-app language switch. Adding Japanese owes an
  ADR (template rule for any language beyond English). RTL: no.
- Text expansion: no fixed-width buttons or labels; the detail pane's label column sizes
  to the longest localized label.
- Formatting: times, dates, relative days ("Today", "Tomorrow"), durations, and currency
  (`$0.12`, always USD as reported by the agent) through platform formatters.
- Register: English sentence case, second person, no exclamation marks; Japanese です/ます調.
- Buttons: verb + object ("Delete Job…", "Run Now", "Check Again").
- Glossary:

| Use | Don't use | For |
|---|---|---|
| Job | Task, schedule, routine | a saved prompt + directory + schedule |
| Run | Execution, session | one invocation of a job |
| Agent | Tool, CLI, model | Claude Code (later Codex CLI) |
| Skipped | Missed, cancelled | a scheduled time that did not run (reason shown) |
| Keep awake | Caffeinate, prevent sleep | idle-sleep prevention |
| Paused | Disabled, off | a job whose Enabled toggle is off |

## Accessibility targets

| Target | This product |
|---|---|
| Level | WCAG 2.2 AA equivalent + 2.4.13 focus appearance |
| Focus ring | System focus ring on standard controls; custom controls (weekday chips, timeline rows) use `.focusable()` with the system ring, never a custom outline |
| Minimum target size | 24×24 pt floor for every clickable element (weekday chips, row Stop buttons, [−] time buttons); standard control sizes otherwise |
| Keyboard | Every function reachable with Full Keyboard Access; focus order = visual order; weekday chips toggle with Space; time rows delete with ⌫ when focused |
| Live regions | Run start/finish announced politely via accessibility notification when the main window or popover is open; no per-second elapsed announcements |
| Color use | Never the only carrier: outcome = glyph + color + text label (`ux-flows.md` glyph set); bypass badge = ⚠ + "Bypass" text |
| Text scaling | Follows system text size where SwiftUI supports it; no fixed-height rows in lists |
| Reduced motion / increased contrast | See Motion; honor Increase Contrast via semantic colors |
| Contrast | Measured in the design direction's "Measured contrast" table — `docs/design/design-direction.md` |

Verification for the implementing session: VoiceOver pass through F1 and F4
(`ux-flows.md`), Full Keyboard Access pass through every flow, grayscale check of the
popover timeline.

## App-type rules

- Unattended agent runs show their work after the fact, not live: the run detail keeps
  the prompt snapshot, options, and result — because the user was not watching.
- Status badges (developer-tools pattern): outcome glyph + label in every list, same set
  everywhere (popover, job recent runs, history).
- A stop control is always visible on a running run wherever it is listed.

## Non-goals

| Not doing | Why | Covered instead by |
|---|---|---|
| Toasts | Menu-bar app has no persistent surface to host them | inline errors, notifications, popover banner |
| Live streaming of agent output | Requirements keep only the final result | elapsed time + result on finish |
| In-app language switch | System language is enough | String Catalog |
| Undo for delete | Delete confirms instead; history is kept | S5 confirmation |

## Open items

- Open: exact status-item symbols and outcome colors — settled in the design direction (stage 3).

## Decision log

| Date | Decided | Rejected options | Why |
|---|---|---|---|
| 2026-09-29 | Competitor research skipped | full research | wireframes already fix the structure; options would not change |
| 2026-09-29 | Explicit Save with Revert, unsaved-changes prompt | live apply | a half-edited prompt must never run at a scheduled time |
| 2026-09-29 | Errors by severity, no toasts | alerts for everything | overnight failures would pile up as alerts |
| 2026-09-29 | English + Japanese (system language) | English only; Japanese only | the user works in Japanese; the public repository keeps English |
| 2026-09-29 | Restrained motion, 150 ms | moderate | a resident menu-bar item should not draw the eye |
| 2026-09-29 | Validate on blur, then live; Save stays enabled | disable Save while invalid | a disabled Save does not say what is wrong |
| 2026-09-29 | AA + focus appearance, system focus rings | AA only | custom chips and rows would otherwise drift |
