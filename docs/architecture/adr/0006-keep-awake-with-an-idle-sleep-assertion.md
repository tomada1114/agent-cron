# ADR-0006: Keep the Mac awake with an idle-sleep power assertion

- **Status:** Accepted 2026-09-29
- **Date:** 2026-09-29
- **Deciders:** the owner

## Context

Scheduled runs fail if the Mac idles to sleep mid-run, and the owner wants a manual
"keep awake" toggle with durations (requirements §3.6). The owner's LidAwake app
(`tomada1114/lidawake`) prevents lid-closed sleep with `pmset SleepDisabled` through a
root helper and a sudoers rule.

## Decision drivers

- No admin rights, no helper, no sudoers (owner's choice).
- Held automatically while any run is in progress, and on demand.

## Considered options

1. **IOKit power assertion preventing idle system sleep** — what `caffeinate -i` does.
2. **`pmset SleepDisabled` via a root helper (LidAwake's way)** — also survives lid close.
3. **Spawn `caffeinate`** — works, but a process per hold to track and kill.

## Decision

Option 1. A Core `SleepPreventing` port (`hold(reason:) -> token`, `release(token)`) and
a Platform adapter over `IOPMAssertionCreateWithName` /
`IOPMAssertionRelease` with the idle-system-sleep assertion type. Core's
`KeepAwakeController` holds one assertion while `runningCount > 0 || manualUntil >
now`, so the manual timer and running jobs never fight. Durations: Off / 1 hour /
4 hours / Until turned off. Lid-closed prevention stays in Later (Product non-goals).

## Consequences

### Positive

- No privileges; the assertion is released automatically if the app exits.

### Negative

- Closing the lid still sleeps the Mac, and runs due then are caught up per ADR-0003.

### Follow-ups

- Port, controller, adapter, popover toggle (issues).

## Open questions

- None.

## Sources

- <https://developer.apple.com/documentation/iokit/kiopmassertiontypepreventuseridlesystemsleep> — prevents idle system sleep; the display may still sleep; "the system may still sleep for lid close, Apple menu, low battery, or other sleep reasons" — checked 2026-09-29
- Unverified: that creating the assertion needs no admin rights (it is how `caffeinate -i` works for an ordinary user); confirm on the adapter's local-machine test.

## Related

- [ADR-0003](0003-in-app-scheduler.md) — runs that hold the assertion.
