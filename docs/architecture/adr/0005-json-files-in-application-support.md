# ADR-0005: Keep jobs and runs as versioned JSON files in Application Support

- **Status:** Accepted 2026-09-30
- **Date:** 2026-09-29
- **Deciders:** the owner

## Context

The app keeps job definitions, the scheduler's last-checked instant, and run history
for 90 days, including each run's result text and prompt snapshot (requirements §3.4,
§5; `docs/design/ux-guidelines.md` › Principles). Files on a user's disk are contract
(`docs/architecture.md` › What is contract and what is private). The template ships
zero dependencies and no persistence.

## Decision drivers

- Zero new dependencies (README › Design Philosophy).
- Testable in Core with a temporary directory; a format version and migration test from
  day one.
- Volume: tens of jobs, at most a few thousand runs inside 90 days.

## Considered options

1. **Versioned JSON files** — `jobs.json` for jobs and scheduler state; one JSON file
   per run under `runs/YYYY-MM/`.
2. **SwiftData** — Apple framework, no dependency, but model macros and its own
   concurrency rules pull persistence types into Core's public API, and a store
   migration is harder to test from a sample file.
3. **SQLite via GRDB** — strongest querying, but a new dependency for a volume a
   directory scan handles.
4. **`UserDefaults`** — not meant for history-sized data.

## Decision

Option 1, proposed.

- Location: `~/Library/Application Support/io.github.tomada1114.AgentCron/` (unsandboxed,
  ADR-0002).
- `jobs.json`: `{ "schemaVersion": 1, "lastCheckedAt": <ISO-8601>, "jobs": [ … ] }`;
  written atomically (write to a temp file, then replace).
- `runs/YYYY-MM/<ISO-8601 start>-<run id>.json`: one immutable record per run, holding
  the job id and name at run time, prompt and option snapshot, trigger, outcome and
  reason, times, exit code, cost, session id, and result text; `schemaVersion` in each.
  A running run is written at start and replaced at finish.
- Retention: on launch and daily, delete run files older than 90 days.
- Encoding and decoding live in Core behind `JobStoring` / `RunStoring` ports; a
  Foundation `FileManager` implementation is acceptable in Core (no banned import), with
  a fake in `AgentCronTestSupport`.
- A decode failure of `jobs.json` stops the app with an alert (ux-guidelines › Feedback),
  never an overwrite; a bad run file is skipped and logged.

## Consequences

### Positive

- Plain files the owner can inspect and back up; no dependency.

### Negative

- Filtering history means reading run files; fine at this volume, revisit past ~10,000
  runs.

### Follow-ups

- Stores, migration-from-sample test, retention sweep (issues).

## Open questions

- None.

## Sources

- `docs/architecture.md` › What is contract and what is private (in-repo).

## Related

- [ADR-0003](0003-in-app-scheduler.md) — stores the last-checked instant.
