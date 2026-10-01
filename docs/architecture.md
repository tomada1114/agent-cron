# Architecture

This page describes the layers every app cut from this template starts with. What an
app decides on top of them — its shape, sandbox posture, persistence, dependencies,
distribution, macOS floor, and permissions — is recorded as ADRs under
[`docs/architecture/`](architecture/README.md), whose `README.md` is the index.

## Layers

```
┌───────────────────────────────────────────────────┐
│ App/                                  (app shell) │  @main, scenes — wiring
│                                                   │  only; composition root
├─────────────────────────┬─────────────────────────┤
│ AgentCronUI     (SwiftUI)   │ AgentCronPlatform     (OS)  │  siblings — neither one
│ thin views, no business │ adapters behind Core    │  imports the other
│ logic                   │ ports; AppKit and co.   │
├─────────────────────────┴─────────────────────────┤
│ AgentCronCore                                 (logic) │  models, view models, ports;
│                                                   │  no UI/OS-framework import —
│                                                   │  enforced by lint and test;
│                                                   │  80% line-coverage floor,
│                                                   │  75% function-coverage floor
└───────────────────────────────────────────────────┘
```

The dependency direction is strictly one-way: `AgentCronCore` ← `AgentCronUI` and
`AgentCronCore` ← `AgentCronPlatform`, and both ← `App`.

Beside those layers sits one target that ships nothing: `AgentCronTestSupport`
(`Packages/AgentCronKit/Tests/AgentCronTestSupport`), the test code both test targets share —
each port's fake and its contract function (see Ports and adapters below). It depends on
`AgentCronCore` alone and is a library target only because SwiftPM lets no target depend on
a test target. No product exports it, so `App/` cannot link it; `ArchitectureBoundaryTests`
fails if `AgentCronCore`, `AgentCronUI`, or `AgentCronPlatform` imports it; and its sources sit
under `Tests/`, outside `scripts/coverage.sh`'s `Sources/AgentCronCore` filter, so it never
counts toward the coverage floors.

`AgentCronCore` must stay free of UI frameworks so it also serves an iOS target
(`docs/adding-ios.md`). SwiftPM's target graph cannot stop `import SwiftUI` — a system
framework is not a package dependency — so the boundary is enforced twice, by text
match: `.swiftlint.yml`'s `no_ui_import_in_core` custom rule (the pre-commit hook,
`just lint`, CI's `lint` job) and the `ArchitectureBoundaryTests` suite in
`AgentCronCoreTests` (`just test`, CI's `test` job). Both reject the UI frameworks
`SwiftUI`, `AppKit`, `UIKit`, and `Cocoa` (which re-exports AppKit), and the
OS-integration frameworks an adapter reaches for first — `ApplicationServices`
(accessibility), `Carbon` (hotkeys), and `ServiceManagement` (login items) — including
attributed
(`@preconcurrency import AppKit`) and kind-qualified (`import struct SwiftUI.Color`)
imports. A `//`-commented import is ignored, but one that starts a line inside a
`/* … */` block or a multi-line string literal is still flagged — delete it instead.
"Platform-agnostic" here means free of those frameworks, not buildable on Linux:
Apple-only frameworks such as Combine stay allowed, and so does Foundation — and so do
`os` and `OSLog`, deliberately, so Core can log (see Logging below).

## Ports and adapters

Code that talks to the OS — `NSWorkspace`, accessibility, a Carbon hotkey, an event tap,
an `NSPanel` overlay, a login item — lives in `AgentCronPlatform`, never in Core, a view, or
the shell. It is always the same five pieces, and the keep-awake port is the worked
example of them to copy (ADR-0006):

1. **The port**, in Core — a `Sendable` protocol taking and returning value types Core
   owns: `SleepPreventing` in
   `Packages/AgentCronKit/Sources/AgentCronCore/KeepAwake/SleepPreventing.swift`.
2. **The adapter**, in Platform — the OS framework import, translating the OS type into
   the Core value and doing nothing else: `PowerAssertionSleepPreventer` in
   `Packages/AgentCronKit/Sources/AgentCronPlatform/PowerAssertionSleepPreventer.swift`.
3. **The fake**, in `AgentCronTestSupport` — a real implementation answering from data the
   test hands it, used by the Core tests of whatever consumes the port
   (`.claude/rules/testing.md` › Fakes, not mocks): `FakeSleepPreventer` in
   `Packages/AgentCronKit/Tests/AgentCronTestSupport/FakeSleepPreventer.swift`.
4. **The local-machine test**, in `Packages/AgentCronKit/Tests/AgentCronPlatformTests` — the
   adapter against the *real* OS, which the fake by construction cannot check:
   `PowerAssertionSleepPreventerTests` holds and releases a real IOKit power assertion. Every suite there
   carries the `.requiresLocalMachine` trait, so it runs only with
   `RUN_LOCAL_MACHINE_TESTS=1` — what `just test-local` sets — and is reported as
   *skipped* under `just test` and in CI. It has to be: a runner has no logged-in GUI
   session and cannot be granted Accessibility, Input Monitoring, or Screen Recording,
   so such a test could only ever fail there. A skip is the honest outcome, and a human
   runs `just test-local` when an adapter changes and puts the output in the pull
   request (`.claude/rules/testing.md` › Where a Test Goes).
5. **The contract suite**, in `AgentCronTestSupport` — one function over the protocol that
   checks every promise the port's `///` states, so the fake cannot quietly promise
   something the adapter does not: `SleepPreventingContract` in
   `Packages/AgentCronKit/Tests/AgentCronTestSupport/SleepPreventingContract.swift`.
   `SleepPreventingContractTests` in `AgentCronCoreTests` runs it against the fake on
   every `just test` and in CI, and `PowerAssertionSleepPreventerTests` runs the same
   function against the adapter under `.requiresLocalMachine` (`just test-local`)
   (`.claude/rules/testing.md` › One Contract Suite per Port).

`App/` is the composition root: the only place that constructs an adapter and hands it
to a Core view model, so nothing below it knows which implementation answered. A test
substitutes the fake at that same seam.

`AgentCronPlatform` is deliberately **outside the coverage floor** — `scripts/coverage.sh`
measures `Sources/AgentCronCore` only. That is a constraint on adapters rather than a
licence: an adapter carries translation, so it has no branch worth a test. The moment
one needs a decision, the decision moves into Core behind the port, where the floor
sees it. What the floor cannot hold is the translation itself — whether the OS really
answers what the adapter assumes — and that is what the fourth and fifth pieces are for.

## Logging

**`AgentCronCore` imports `os` directly, and that does not break the boundary.** The ban
list above is UI frameworks and the OS-integration frameworks an adapter reaches for;
`os` is neither. It pulls in no AppKit, it is available on every Apple platform Core is
meant to serve (`docs/adding-ios.md`), and it writes to the unified log rather than
touching the screen or the OS on Core's behalf. So logging is *not* modelled as a port:
a `LoggingPort` would buy no testability — a log line is not an outcome a test asserts —
and would cost every Core type an injected dependency it does not otherwise need. `os`
and `OSLog` are therefore absent from both halves of the ban list, `.swiftlint.yml`'s
`no_ui_import_in_core` and `ArchitectureBoundaryTests`, and a test case pins their
absence so narrowing that list later fails loudly.

Every logger lives in `AppLog` (`Packages/AgentCronKit/Sources/AgentCronCore/AppLog.swift`), the
one place the subsystem is spelled. It is a literal — the app's bundle identifier — and
not `Bundle.main.bundleIdentifier`, which answers for the test runner under `swift test`
and for the preview agent inside an Xcode preview; `scripts/bootstrap.sh` rewrites the
literal with the same placeholder replacement that rewrites `project.yml`, and
`AppLogTests` fails if the two disagree. `AgentCronUI`, `AgentCronPlatform`, and `App/` log
through the same loggers, which they already see by importing `AgentCronCore`, so one
`just logs` stream shows the whole app.

The conventions that go with it — one category per concern, a privacy annotation on
anything user-derived, and never `print`/`debugPrint`/`NSLog` under `Sources/` or `App/`
(`.swiftlint.yml`'s `no_print_in_sources` rejects them) — are in
`.claude/rules/swift.md` › Logging. `KeepAwakeController` is the worked example: it
logs its app-chosen hold reason and a refused hold's `IOReturn` `.public`, since
neither carries user data; a value that does is logged `.private`.

## Where new code goes

| You are adding… | It goes in… | Tested by… |
|---|---|---|
| Domain logic, state, view models | `Packages/AgentCronKit/Sources/AgentCronCore` | Swift Testing in `Tests/AgentCronCoreTests` (coverage-gated) |
| Words a person reads | A Core view model returning `LocalizedStringResource`, with its key in `Packages/AgentCronKit/Sources/AgentCronCore/Resources/Localizable.xcstrings` (`localizing-the-app`) | The view model's tests + `LocalizationTests` in `Tests/AgentCronCoreTests` |
| Views, view modifiers | `Packages/AgentCronKit/Sources/AgentCronUI` | Core view-model tests + the launch UI test |
| OS integration: AppKit, accessibility, hotkeys, login items, the file system beyond Foundation | `Packages/AgentCronKit/Sources/AgentCronPlatform`, as an adapter behind a Core port | Core tests through a fake of the port in `Tests/AgentCronTestSupport` (coverage-gated), the port's contract suite against that fake, plus an opt-in local-machine test of the adapter and the same contract against it in `Tests/AgentCronPlatformTests` — `just test-local` |
| App lifecycle, scenes, menus, wiring an adapter to a view model | `App/` | `LaunchUITests` + `just smoke` |

That last row carries one decision the table cannot: the app's *shape*. The template
ships a regular windowed app — `WindowGroup`, a Dock tile, a launch test that waits for
a window. AgentCron is a menu-bar agent instead (ADR-0001): `LSUIElement`, a
`MenuBarExtra` status item with a `.window`-style popover, one `Window(id: "main")`
scene, and a launch test that waits for the status item. That shape lives in
`project.yml`, `App/AgentCronApp.swift`, and `LaunchUITests/LaunchTests.swift`, and
nothing below them.
`.agents/skills/starting-an-app/references/app-shapes.md` gives both shapes as proven
code, including where an `NSApplicationDelegateAdaptor`'s delegate lives when
`MenuBarExtra` is not enough (`AgentCronPlatform`, never `App/`).

Keeping logic out of views is what makes the coverage floor honest: the gate
measures the code that can regress silently, not SwiftUI layout. The same reasoning
keeps decisions out of adapters — see "Ports and adapters" above.

## What is contract and what is private

Nothing here is published, so the contract is not a package's export list. It is what
something outside the change can observe: another module of this package, a user's Mac
that ran an earlier build, or the user themselves. Four things are contract; everything
else is private.

| Contract | What depends on it | What changing it requires |
|---|---|---|
| **Core's public API** — every `public` declaration in `AgentCronCore` | `AgentCronUI`, `AgentCronPlatform`, `App/`, and the tests, which all import `AgentCronCore` as a separate module; `Package.swift` declares the library products so `App/` can link them, and nothing outside this repository does | Update every caller in the same pull request — the compiler finds them (`just build`, `just test`). A new public declaration carries a `///` saying why (the Review Checklist in `AGENTS.md`); a new port is an ADR (`AGENTS.md` › "Before changing the architecture") |
| **The bundle identifier** — `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml`, set by `scripts/bootstrap.sh` | Everything macOS keys by it on a user's Mac: the sandbox container that holds the app's `UserDefaults` and Application Support files, and its permission (TCC) grants; the log subsystem (`AppLog.subsystem`); and `just run`, `just logs`, and `just reset-permissions`, which read it through `scripts/bundle-id.sh` | Treat it as fixed once a build has left your machine: a new identifier is a new app to macOS, so the user's settings, files, and grants stay behind under the old one. Changing it is a human's decision, recorded as an ADR; `project.yml` and `AppLog.subsystem` change together (`AppLogTests` fails otherwise), and a signing or entitlements change that goes with it needs the sign-off in `AGENTS.md` › "Security and human approval" |
| **`UserDefaults` keys** — each key the app stores, and the type of its value | A user's saved preferences, read back by every later version | Renaming, removing, or retyping a key silently resets the user's value, because the old one is left unread. Read the old key and migrate it in Core, with a test that starts from the old value. Choosing `UserDefaults` at all is the persistence ADR |
| **File formats** — anything the app writes and reads back in a later version: a config file, saved state, a document | Files already on a user's disk, and for a hand-edited config ("A human-editable config file" below), the user who edits it | A new version still reads the old format — a version field and a migration in Core, with a test that decodes a sample of the previous format. The format and where it lives are the persistence ADR. A cache the app can rebuild from scratch is private |

The template ships no `UserDefaults` key and no file format; the first one an app adds
is where its persistence ADR starts (`AGENTS.md` › "Before changing the architecture").

**Private** is everything else: `internal` and `private` declarations, how an adapter
talks to the OS behind its port, view structure, file and type layout, test helpers, and
log categories and messages. Changing any of it needs only the gates that already run
(`AGENTS.md` › "Validating a change").

No gate notices a broken contract item except where one is named above — the compiler
for Core's public API, `AppLogTests` for the log subsystem. A renamed key or a changed
format passes every check and fails on the user's Mac, so review is what catches it, and
a user-visible change to any of the four owes a `CHANGELOG.md` entry.

## Recommended optional dependencies

The template ships with zero. When a real need appears, these are vetted
starting points.

### For tests and distribution

- [ViewInspector](https://github.com/nalexn/ViewInspector) — unit-test SwiftUI
  view hierarchies when view-model tests stop being enough.
- [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)
  — pixel/structure regression tests for complex custom views.
- [Sparkle](https://sparkle-project.org/) — in-app updates once you distribute
  outside the App Store and users ask for auto-update (see docs/distribution.md).

### What a utility app reaches for first

Four needs turn up in nearly every hotkey-driven or menu-bar app, and each one's
zero-dependency answer is stated first on purpose. In this layout that answer is an
adapter in `AgentCronPlatform` behind a Core port ("Ports and adapters" above) — usually
less code than integrating a package, and it keeps the decision in Core where the
coverage floor sees it. Reach for a package only when the "worth it when" sentence
describes your app.

Every package named below was checked against `.claude/rules/project.md`'s dependency
checklist on **2026-09-21**: license, latest release, whether the repository is
archived, the `platforms:` floor in its `Package.swift`, and whether that manifest
declares a binary target or a build plugin. Re-check before you add one — these facts
go stale, and the checklist's Need, Weight, and Advisories items are still yours to
answer for your app.

**Global hotkeys.** Carbon's `RegisterEventHotKey` is still the supported API for a
system-wide shortcut, and wrapping it costs roughly sixty lines: an adapter in
`AgentCronPlatform` that installs one `EventHandlerUPP`, keeps an id→handler dictionary,
and hands Core a `Sendable` port. `Carbon` is one of the frameworks Core may not
import, which is why the adapter is the shape rather than a workaround. A package is
worth it when your users rebind shortcuts in the UI — the recorder control, its
conflict detection against system shortcuts, and persistence are the tedious part, not
the registration.

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — passes:
  MIT; 3.1.0 released 2026-09-11; not archived; floor `.macOS(.v10_15)`, at or below
  this package's `.macOS(.v14)`; one Swift target, no binary target, no build plugin,
  no package dependencies. It ships AppKit and SwiftUI recorder views, so it belongs to
  `AgentCronUI` and `AgentCronPlatform` — its types must not reach Core.

**Launch at login.** No package. `SMAppService.mainApp.register()` (ServiceManagement,
macOS 13+, below this package's macOS 14 floor) is the entire API, with
`SMAppService.mainApp.status` to read it back; it lives in a `AgentCronPlatform` adapter
because `ServiceManagement` is also on Core's blocked-import list. Do not add
`sindresorhus/LaunchAtLogin`: that repository now redirects to `LaunchAtLogin-Legacy`
and is archived (last release v5.0.2, 2024-06-25), so it fails the checklist's
Continuity item outright. Its successor,
[LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) (MIT,
v1.1.0 released 2023-12-21, floor `.macOS(.v13)`), is a few lines around that same
call and fails the Need item instead — Foundation and one system framework already do
the job.

**A human-editable config file.** `Codable` plus `JSONEncoder`/`JSONDecoder` from
Foundation covers it: set `outputFormatting` to `[.prettyPrinted, .sortedKeys]` so the
file diffs cleanly, decode into a Core value type, and let a `AgentCronPlatform` adapter
own the path under `~/Library/Application Support`. A package is worth it when the file
is a contract with the user rather than an implementation detail — when they are
expected to edit it by hand and want comments and trailing commas, which JSON has
neither of. That format is TOML.

- [TOMLDecoder](https://github.com/dduan/TOMLDecoder) — passes: MIT; 0.4.5 released
  2026-07-11; not archived; floor `.macOS(.v10_15)`; a pure-Swift library target with
  no binary target, and no package dependency in the default configuration (its
  benchmark, docs, and formatting dependencies sit behind `TOMLDECODER_*` environment
  opt-ins). It decodes only — rendering the file back out is yours to write, which
  usually fits, since the app writes a commented default once and the user owns it
  afterwards.
- [TOMLKit](https://github.com/LebJe/TOMLKit) reads *and* writes, but did not pass as
  checked: its manifest appends `apple/swift-docc-plugin` unconditionally, and a build
  plugin is build-time code the checklist routes to explicit human approval. Its latest
  release, 0.6.0, is also from 2024-01-03, with the last commit 2025-01-18. It wraps
  the toml++ C++ sources in a `CTOML` source target — that is not a binary target, so
  that item is fine; the build plugin and the release age are what stop it.

**Settings window.** Nothing is vetted here, and that is the finding rather than a gap
to fill later. SwiftUI's `Settings` scene (macOS 11+) already gives the ⌘, item, the
standard window, and its own scene phase; put a `TabView` in it, keep the state in a
Core view model, and persist it through a port exactly as above.
[Settings](https://github.com/sindresorhus/Settings) was checked and would pass on
license and shape (MIT, floor `.macOS(.v10_13)`, one resource-bearing target, no binary
target or build plugin), but its latest release, 3.1.1, is from 2024-05-07, and what it
buys is a toolbar-tab preferences window that the `Settings` scene now gives for free.
Add it only if you need that exact pre-Ventura look.

Before adding any dependency, apply the checklist in `.claude/rules/project.md`
(maintenance, license, transitive weight) and commit `Package.resolved` with it.

## AgentCron on these layers

The sections above are the template's ground; this one is AgentCron's own map onto it.
The reasoning behind each choice is in the ADR it links.

### Principles

- **The app is the scheduler** — nothing runs while it is quit; no launchd, no daemon
  ([ADR-0003](architecture/adr/0003-in-app-scheduler.md)). Rules out background
  helpers and plists.
- **A run is a hand-run `claude -p`** — same binary, same login-shell environment, same
  flags ([ADR-0004](architecture/adr/0004-agent-runner-port-and-claude-code-invocation.md)).
  Rules out bundling or wrapping the agent, and the App Sandbox
  ([ADR-0002](architecture/adr/0002-app-sandbox-off.md)).
- **Agent-neutral above one adapter** — only `ClaudeCodeCommand` and
  `ClaudeCodeResultParser` know Claude Code; jobs store an `AgentKind`. Rules out
  `claude`-specific fields on `Job` or in the scheduler.
- **Nothing runs that was not saved** — a run uses the last saved job and records a
  snapshot of it. Rules out live-applied edits to a job.
- **Decisions in Core, translation in Platform** — schedule math, dispatch, catch-up,
  keep-awake policy, notification policy are Core with injected time; adapters only
  launch, observe, and post.

### Shape

| Domain | Layer | Module path (planned) | Port |
|---|---|---|---|
| Jobs, schedules, next-fire math | Core | `AgentCronCore/Jobs/`, `Scheduling/` | — |
| Dispatcher, catch-up, overlap | Core decides; Platform delivers timer, sleep/wake, clock and time-zone events | `AgentCronCore/Scheduling/`; `AgentCronPlatform/WorkspaceSystemEvents.swift` | `SystemEventsProviding` |
| Run execution | Core builds argv and parses the result; Platform launches | `AgentCronCore/Agents/`; `AgentCronPlatform/ProcessAgentRunner.swift` | `AgentRunning` |
| Persistence | Core (Foundation file I/O) | `AgentCronCore/Storage/` | `JobStoring`, `RunStoring` |
| Keep-awake | Core policy; Platform IOKit | `AgentCronCore/KeepAwake/`; `AgentCronPlatform/PowerAssertionSleepPreventer.swift` | `SleepPreventing` |
| Notifications | Core policy; Platform UserNotifications | `AgentCronCore/Notifications/`; `AgentCronPlatform/UserNotificationPoster.swift` | `RunNotifying` |
| Launch at login, activation policy | Platform | `AgentCronPlatform/` | `LoginItemControlling`, `ActivationPolicyControlling` |
| Popover, main window, editor, history | UI over Core view models | `AgentCronUI/` | — |
| The object graph and how its parts talk | Core | `AgentCronCore/AppEnvironment/` | — |
| Scenes, menus, building the adapters | `App/` | `App/AgentCronApp.swift` | — |

### Data

`Job` (id, name, agent, directory, prompt, schedule, model, effort, permission mode,
timeout, notify policy, enabled) and `Run` (id, job id + name snapshot, prompt and
option snapshot, trigger, scheduled time, start/end, outcome + reason, exit code,
cost, session id, result text), stored as versioned JSON in Application Support and
kept 90 days ([ADR-0005](architecture/adr/0005-json-files-in-application-support.md)).

The file format is contract, and version 1 is fixed by the checked-in samples in
`Packages/AgentCronKit/Tests/AgentCronCoreTests/Fixtures/` — the stores must decode them
and write them byte for byte. Under
`~/Library/Application Support/io.github.tomada1114.AgentCron/` (`StorageLocation`),
`jobs.json` holds `schemaVersion`, `jobs`, and `lastCheckedAt` (left out until the
scheduler first checks), and each run is
`runs/<YYYY-MM>/<start to the second>Z-<run id>.json` — its UTC month and start — holding
the run's fields beside `schemaVersion`. Keys are the Swift property names, sorted and
pretty-printed; enum values are the snake_case raw values; dates are ISO-8601 in UTC
with milliseconds. `FileJobStore` throws `StorageError.corruptJobs` for a `jobs.json` it
cannot decode and `.newerJobsVersion` for one a newer build wrote, leaving the file as
it is, and the app stops rather than saving over it; `FileRunStore` skips such a run
file and logs its month and reason to `AppLog.storage`. A format change bumps
`StorageFormat.currentSchemaVersion`, keeps decoding the version-1 sample, and adds a
sample of its own.

### Core flows

- **Scheduled run:** timer tick → dispatcher (Core) picks due jobs → pre-flight → hold
  keep-awake → `AgentRunning` launches `zsh -l -c` → result parsed (Core) → `Run`
  written → keep-awake released if idle → notification per policy → popover and
  history update.
- **Wake or launch:** sleep/wake event → dispatcher computes missed times since
  `lastCheckedAt` → one catch-up within 60 min, the rest recorded as skipped.
- **Edit a job:** editor (UI) → view model validates → Save writes `jobs.json` → next
  fire date recomputed and the timer re-armed.

`AppEnvironment` (Core) owns the graph these flows run through and every connection
between its parts; `App/` only builds the `AgentCronPlatform` adapters, hands them in as
`AppPorts`, and calls `launch()`. Its Core tests drive each flow above against the
ports' fakes.

### Quality targets

| Target | Check |
|---|---|
| Next-fire, catch-up, overlap, and DST rules are exact | Core tests with a fake clock (`just test`, coverage floor) |
| A run matches a hand-run `claude -p` in the same directory | parity run recorded in the runner issue's PR (`just test-local` + `just run`) |
| A bad `jobs.json` is never overwritten | Core store test decoding a corrupt sample |
| Previous file format still decodes | migration test from a checked-in v1 sample |
| Keep-awake assertion released when no job runs and no manual hold | Core controller tests; `pmset -g assertions` in the adapter's local test |
| The status item appears at launch | `just uitest`, `just smoke` |

### Decisions

The ADR index is [`architecture/README.md`](architecture/README.md).
