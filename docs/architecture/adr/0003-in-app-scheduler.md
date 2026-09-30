# ADR-0003: The app is the scheduler

- **Status:** Accepted 2026-09-29
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

- None.

## Sources

- <https://developer.apple.com/documentation/appkit/nsworkspace/didwakenotification> — posted on `NSWorkspace.shared.notificationCenter` only; another center never receives it — checked 2026-09-29

## Related

- [ADR-0001](0001-menu-bar-agent-with-a-main-window.md) — launch at login keeps the
  scheduler running.
- [ADR-0005](0005-json-files-in-application-support.md) — where the last-checked
  instant lives.
