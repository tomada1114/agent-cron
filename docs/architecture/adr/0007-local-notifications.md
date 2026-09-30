# ADR-0007: Local notifications for run outcomes

- **Status:** Accepted 2026-09-29
- **Date:** 2026-09-29
- **Deciders:** the owner

## Context

Each job chooses none / failures only / every run (requirements §3.5). Posting a
notification needs the user's authorization — a privacy grant `AGENTS.md` asks an ADR
for.

## Decision drivers

- Notify only when a job opts in; failures are also visible without notifications
  (popover banner, history).

## Considered options

1. **UserNotifications local notifications** — the system framework.
2. **No notifications** — rejected by the owner.

## Decision

Option 1. A Core `RunNotifying` port decides nothing; Core's policy decides whether a
finished run notifies (job setting × outcome; "failure" = failed, timed out, skipped).
The Platform adapter requests authorization the first time a job's setting is not
None, posts title "<job> <outcome> · <time>" and a one-line body, and routes a click to
the run in History. Denied authorization shows the inline note in
`docs/design/ux-guidelines.md` › States.

## Consequences

### Positive

- Uses the system's own Focus and notification settings.

### Negative

- One authorization prompt, at first opt-in rather than at launch.

### Follow-ups

- Notification policy, adapter, click routing (issues).

## Open questions

- None.

## Sources

- <https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/requestauthorization(options:completionhandler:)> — call before scheduling any local notification — checked 2026-09-29
- <https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate/usernotificationcenter(_:didreceive:withcompletionhandler:)> — delivered when the user opens the app from a notification — checked 2026-09-29

## Related

- None.
