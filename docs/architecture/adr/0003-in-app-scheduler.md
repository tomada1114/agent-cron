# ADR-0003: The app is the scheduler

- **Status:** Accepted 2026-09-29
- **Amended:** 2026-09-30 — the `SystemEventsProviding` port and its `WorkspaceSystemEvents` adapter landed (#14): its shape and timer clock are recorded under Decision, its local-machine test under Sources, and what only a real sleep or clock change can show under Open questions. Wiring it to the dispatcher is #28.
- **Date:** 2026-09-29
- **Deciders:** the owner

## Context

Jobs run on chosen weekdays at one or more local times (requirements §3.2). Something
must fire them, notice runs missed during sleep or while the app was not running, and
record every outcome in the run history.

## Decision drivers

- One source of truth for job definitions and run history (requirements §3.4).
- Missed-run policy: catch up once within 60 minutes, otherwise record as skipped.
- Testable in Core without waiting for wall-clock time (`designing-core-logic`: inject
  time).

## Considered options

1. **In-app scheduler** — the resident app computes the next fire date and runs jobs.
2. **launchd LaunchAgents** — one plist per job, fired by the OS even when the app is
   not running.
3. **cron / `crontab`** — deprecated on macOS in favor of launchd; no catch-up.

## Decision

Option 1, chosen by the owner.

- **Core** owns the schedule math: `Schedule` (weekday set + sorted unique `HH:mm`
  times) → `nextFireDate(after:in:)` using an injected `Calendar`/`TimeZone`; missed
  times between a last-checked instant and now → one catch-up if the latest is ≤ 60
  minutes old, the rest recorded as skipped (reason `missed`); DST: a skipped wall
  time fires at the next valid minute, a repeated one fires once.
- **Core** owns the dispatcher: given "now" from an injected clock, it decides which
  jobs are due, skips a job whose previous run is still running (reason `stillRunning`),
  and starts others in parallel with no limit.
- **Platform** adapters supply ticks and wake events: a timer armed for the earliest
  next fire date (re-armed after every run, edit, wake, time-zone or clock change) and
  `NSWorkspace` sleep/wake notifications, behind a Core `SystemEventsProviding` port.
- The last-checked instant is persisted with the jobs (ADR-0005), so a relaunch catches
  up the same way a wake does.
- The port is `events() -> AsyncStream<SystemEvent>` plus `armTimer(at:)`, which
  replaces the timer armed before. `SystemEvent` is `fireDateReached`, `willSleep`,
  `didWake`, `clockChanged`, and `timeZoneChanged`; each `events()` stream hears every
  event from then on, and a stream whose consumer stops has its observers removed.
  Choosing the date to arm stays with the caller (#28), in Core.
- The adapter's timer sleeps on `ContinuousClock`, which keeps counting while the Mac is
  asleep, so a date passed during sleep is due on wake rather than one sleep later. It
  does not follow the wall clock; the caller re-arms on `clockChanged` and
  `timeZoneChanged`, as the timer bullet above already requires. The alternative, a
  wall-clock `DispatchSource` timer, would follow a clock change on its own but brings a
  non-`Sendable` source object into a Swift 6 adapter for an event the port reports
  anyway.

Option 2 needs plists kept in step with the app's data and an out-of-process way to
record results; option 3 has neither catch-up nor a future on macOS.

## Consequences

### Positive

- Everything a run touches — scheduling, keep-awake, history, notifications — happens
  in one process and is testable in Core with a fake clock.

### Negative

- Nothing runs while the app is quit; launch at login (ADR-0001) mitigates, the Product
  non-goals accept it.

### Follow-ups

- Schedule model and next-fire computation; dispatcher with catch-up and overlap rules;
  timer and wake adapters (issues).

## Open questions

- Unverified: that a `Task.sleep` on `ContinuousClock` whose deadline passed during
  system sleep resumes promptly on wake. The clock's own documentation (Sources) says it
  keeps counting; the resume on wake is owed to a human-run check with a real sleep.
- Unverified: that the OS posts `NSSystemClockDidChange` and `NSSystemTimeZoneDidChange`
  on `NotificationCenter.default` of an app process. Their documentation (Sources) does
  not name a center; the adapter's test posts them there in-process, and a real clock or
  time-zone change is owed to a human-run check.

## Sources

- <https://developer.apple.com/documentation/appkit/nsworkspace/didwakenotification> — posted on `NSWorkspace.shared.notificationCenter` only; another center never receives it — checked 2026-09-29
- <https://developer.apple.com/documentation/appkit/nsworkspace/willsleepnotification> — posted before the device sleeps, on `NSWorkspace`'s `notificationCenter` only — checked 2026-09-30
- <https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/nssystemclockdidchange> — posted whenever the system clock is changed; the page names no center — checked 2026-09-30
- <https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/nssystemtimezonedidchange> — posted when the time zone changes; the page names no center — checked 2026-09-30
- <https://developer.apple.com/documentation/swift/continuousclock> — a clock that does not stop incrementing while the system is asleep — checked 2026-09-30
- `WorkspaceSystemEventsTests` (`just test-local`, 2026-09-30) — each notification posted in-process on its center came out as its event, sleep and wake posted on the default center were not heard, and the adapter kept `SystemEventsProvidingContract` on the real clock. It did not sleep the Mac or change its clock.

## Related

- [ADR-0001](0001-menu-bar-agent-with-a-main-window.md) — launch at login keeps the
  scheduler running.
- [ADR-0005](0005-json-files-in-application-support.md) — where the last-checked
  instant lives.
