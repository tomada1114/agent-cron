# AgentCron — Requirements

- **Status:** Signed off 2026-09-29
- **Platform and stack:** macOS menu-bar agent; `tomada1114/macos-app-template` (SwiftUI,
  XcodeGen, `MyAppCore` / `MyAppUI` / `MyAppPlatform` split, Swift 6, strict gates). App
  Sandbox off (a child `claude` process inherits the sandbox and could not reach arbitrary
  repositories).

## 1. Overview

- **What it is:** a menu-bar app that runs a coding agent CLI — Claude Code today, Codex CLI
  later — in one-shot headless mode (`claude -p`) on a schedule, in a chosen directory with
  a stored prompt, and keeps a history of what each run did.
- **Target user:** a single developer on their own Mac who wants recurring agent chores
  (summarize RSS news into an HTML page inside a repository; review Dependabot PRs and
  merge the safe ones) to happen without opening a terminal, and wants to check afterwards
  that they ran and what they decided.
- **Success (MVP done):** a scheduled job produces the same result as running the same
  prompt by hand with `claude -p` in that directory — same files written, same PRs
  merged — and its run appears in the history with the result text.
- **Core interaction:** define a job (directory + prompt + schedule), then glance at the
  menu bar to see what runs next and whether recent runs succeeded.

## 2. Scope

### MVP
- Job definitions with directory, prompt, schedule, agent options (§3.1)
- Weekday + multiple-times-per-day schedule and in-app scheduler (§3.2)
- Headless execution of Claude Code through the login shell (§3.3)
- Run history with the final result text, kept 90 days (§3.4)
- Per-job completion notifications (§3.5)
- Keep-awake: automatic during runs, manual toggle with duration (§3.6)
- Menu-bar popover and a rich settings window (§3.7)

### Later
- Codex CLI (`codex exec`) as a second agent — the job model carries an agent kind from
  day one so adding it does not migrate data. Pulled forward when the user wants a
  Codex job.
- Lid-closed sleep prevention (lidawake's `pmset SleepDisabled` via an admin helper) —
  needs a root helper and sudoers; pulled forward if idle-sleep prevention proves
  insufficient.
- Job chaining ("run B after A succeeds") and job export/import (JSON).
- Duplicate a job (not chosen for MVP).

### Non-goals
- Continuing a previous session (`--continue` / `--resume`) — every run is a fresh
  one-shot.
- Running when the app is not running (launchd plists, a daemon) — the app is the
  scheduler.
- Cron expressions and interval schedules ("every 2 hours") — weekdays + times only.
- Full stream logs of tool calls — only the final result and metadata are kept.
- Tool allow/deny lists, max turns, and budget caps per job — timeout is the only limit.
- Multiple users, accounts, sync across Macs, remote triggers.
- Sandboxed / Mac App Store distribution.
- Prompt files — the prompt is typed in the app.

## 3. Features

### 3.1 Jobs

| Item | Specification |
|---|---|
| Name | required, 1–60 characters |
| Agent | Claude Code (only choice in MVP; stored per job) |
| Working directory | required, an existing directory chosen with an open panel; validated again at run time |
| Prompt | required, non-empty, multi-line text typed in the app (no prompt files; long procedures live in the repository as skills or docs and the prompt invokes them) |
| Schedule | §3.2 |
| Model | "Default (Claude Code setting)" or `opus` / `sonnet` / `haiku` / `fable`; default: Default (flag omitted) |
| Effort | "Default" or `low` / `medium` / `high` / `xhigh` / `max`; default: Default (flag omitted) |
| Permission mode | `auto` (default) / `acceptEdits` / `dontAsk` / `plan` / `default` / `bypassPermissions`; choosing `bypassPermissions` shows a red warning in the editor and a badge on the job in every list |
| Timeout | minutes, default 30 |
| Notification | none / failures only / every run; default failures only |
| Enabled | on/off; default on |

Operations: add, edit, delete, enable/disable, run now, stop a running job.
Deleting a job keeps its history (shown as a deleted job) until the 90-day retention
removes it.

### 3.2 Schedule and scheduler

| Item | Specification |
|---|---|
| Days | any subset of Mon–Sun; presets "Every day", "Weekdays" |
| Times | one or more HH:mm times per day, local time zone |
| Firing | the app fires jobs itself while running; launch at login keeps it running |
| Missed run | when the Mac was asleep or the app was not running at a scheduled time: run once on wake/launch if within 60 minutes of the scheduled time; beyond it, record as skipped. Several missed times coalesce to one run |
| Overlap | if the same job is still running when its next time arrives, that time is recorded as skipped (still running) |
| Different jobs | run in parallel, no limit |
| Time zone | system local time; a change of system time zone reschedules from the new local time. A time skipped by a DST change runs at the next valid minute; a time repeated by DST runs once |

### 3.3 Execution

- Launched through the user's login shell (`zsh -l -c …`) so PATH, `gh`, `mise`, and
  other user tools match the terminal.
- Command shape: `claude -p --output-format json --permission-mode <mode>
  [--model …] [--effort …] -- <prompt>`, working directory = the job's directory.
- Timeout: the process is terminated at the job's timeout and the run recorded as timed
  out.
- Stop: the user can stop a running job; recorded as stopped.
- Failure before start (directory missing, `claude` not found): recorded as skipped with
  its reason (`directoryMissing` / `agentNotFound`); follows the job's notification setting.

### 3.4 Run history

Each run records: job (name kept even after deletion), trigger (scheduled / missed-run
catch-up / manual), scheduled time, start and end time, duration, outcome (succeeded /
failed / timed out / stopped / skipped with reason), exit code, cost in USD when reported,
session id, and the final result text (or the error output on failure).
Retention: 90 days, then deleted automatically.

### 3.5 Notifications

Per job: none / failures only / every run. "Failure" covers failed, timed out, and
skipped. Clicking a notification opens that run in the history.

### 3.6 Keep-awake

- Mechanism: an IOPMAssertion preventing idle system sleep (no admin rights). Closing
  the lid still sleeps the Mac.
- Automatic: held while any job is running, released when none is.
- Manual toggle from the menu bar: off / until turned off / 1 hour / 4 hours (durations
  TBC in UX); the remaining time is shown while active.

### 3.7 Menu bar and settings window

- Menu-bar icon reflects state (idle / running / keep-awake on / last run failed —
  visual treatment decided in the UX and design stages).
- Popover: upcoming runs, running jobs with stop, recent outcomes, keep-awake toggle,
  entry points to settings and history.
- Settings window: job list and job editor, history viewer, general settings.
- Launch at login: registered on first launch (default on), can be turned off in
  general settings.
- Agent check: general settings shows where `claude` resolves in the login shell and its
  version (checked at launch and on a "Check again" button), with a warning when it is
  not found. Login state is not probed; "Run now" reveals it.

## 4. Cross-cutting rules

- The app never shows or stores credentials; it relies on the user's existing Claude Code
  login.
- Prompts and result text are stored locally only.

## 5. Data

- Job: fields in §3.1, plus a stable id and created/updated times.
- Run: fields in §3.4.
- Location: the user's Application Support directory; format decided in stage 7 (ADR).
- Uninstall: removing the app leaves the data directory; no uninstaller in MVP.

## 6. Open questions

- Whether `zsh -l -c` gives the same environment as the user's terminal (`.zshrc` is not
  read by a non-interactive login shell) — settle with a parity run during implementation.
- Whether Claude Code's `auto` mode lets a Dependabot job run `gh pr merge` unattended —
  to verify with a real run during implementation.

## 7. Decision log

- 2026-09-29 Title AgentCron / `agent-cron` (rejected: AgentClock, Nightshift, HeadlessRunner — AgentCron says what it does and is agent-neutral).
- 2026-09-29 SwiftUI template kept (rejected: tauri-template, because every integration is a native macOS API and the app is macOS-only).
- 2026-09-29 In-app scheduler (rejected: launchd LaunchAgents, because of double bookkeeping between plists and app settings and indirect result collection).
- 2026-09-29 Idle-sleep prevention only (rejected: lidawake-style lid-closed prevention, because it needs a root helper and sudoers).
- 2026-09-29 Missed runs catch up once within a grace window (rejected: always skip; always run).
- 2026-09-29 History keeps the final result text (rejected: full stream log; status only).
- 2026-09-29 Notifications chosen per job (rejected: failures only globally; every run; none).
- 2026-09-29 Weekdays + multiple times (rejected: intervals; cron expressions).
- 2026-09-29 Overlapping run of the same job is skipped and recorded (rejected: queue; parallel).
- 2026-09-29 Timeout is the only extra per-job limit, default 30 min (rejected: budget, max turns, tool lists).
- 2026-09-29 Launch through the login shell (rejected: direct exec with a configured PATH, because `gh` and other tools go missing).
- 2026-09-29 History kept 90 days (rejected: 30 days; last N per job; forever).
- 2026-09-29 Job ops: enable/disable, run now, stop (duplicate deferred to Later).
- 2026-09-29 Manual keep-awake with durations (rejected: on/off only; "until next job").
- 2026-09-29 Deleting a job keeps its history (rejected: delete together).
- 2026-09-29 Later: Codex CLI, lid-closed sleep prevention, chaining/export. Non-goal: session continuation.
- 2026-09-29 All permission modes including `bypassPermissions`, with a warning and badge (rejected: hide bypass; only auto and dontAsk).
- 2026-09-30 A failure before start is recorded as skipped with its reason (`directoryMissing` / `agentNotFound`), matching the run model and the dispatcher (rejected: a failed outcome) (#51).
- 2026-09-29 Missed-run grace window 60 minutes, global (rejected: per job; 15 minutes).
- 2026-09-29 Different jobs run in parallel (rejected: serialize per directory; serialize all).
- 2026-09-29 Prompt typed in the app only (rejected: also a prompt file in the repository).
- 2026-09-29 Launch at login on by default from first launch (rejected: ask on first job; off).
- 2026-09-29 Agent check in general settings (rejected: none).
- 2026-09-29 Success = parity with a hand-run `claude -p` (rejected: a week of two real jobs).
