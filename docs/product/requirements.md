# agent-cron — Requirements

- **Status:** Signed off 2026-10-11
- **Platform and stack:** macOS-only CLI, open source, installed from source with `cargo install`; built from `tomada1114/rust-template` (Rust)
- **Command-line design:** [cli.md](cli.md)
- **Design:** [design.md](design.md)

## 1. Overview

- **What it is:** A CLI that registers and manages Claude Code's `claude -p` (one-shot headless run) as jobs that run in a given folder at set times. Each run sends its result to Discord, and pasting the command in the notification resumes that session interactively in your own terminal.
- **Target user:** Developers who want Claude Code to do routine work (checks, research, summaries) on their own Mac on a schedule. Published as open source so other developers with the same need can use it.
- **Operated by people and programs alike:** People use interactive prompts; agents such as Claude Code, scripts, and a future Raycast extension can do every operation with flags and JSON output (§3.6).
- **Core interaction:** Read results in notifications, and for the runs worth a look, paste `cd '<dir>' && claude -r <id>` to continue the conversation. As the groundwork for that: create jobs interactively inside a repository, and list and adjust that folder's jobs.
- **Success (MVP done):** A real job created interactively inside a repository runs at its scheduled time, and pasting the command from the Discord notification is all it takes to continue. Failures are notified too, and nothing runs on waking from sleep. In addition, Claude Code can create and inspect jobs with flags and `--json` alone.

## 2. Scope

### MVP
- Create, list, change, disable/enable, and delete jobs (§3.1)
- Per-folder use: a new job's folder defaults to the current one, and listing centers on the current folder's jobs (§3.1)
- Scheduled runs (only while the Mac is on and the user is logged in; times passed during sleep are not run) (§3.2)
- Run now as a trial, and stop a running job (§3.3)
- Review run history (§3.4)
- A notification for every run (success and failure), to a Discord webhook (§3.5)
- An interface for programs: every operation runs without questions, and state is available as JSON (§3.6)
- Setup diagnostics: a command that checks the webhooks, where `claude` is, and the scheduler's state (§3.7)

### Later
- A Homebrew tap and prebuilt binaries — once open-source users grow and installing from source becomes a barrier
- More notification targets: Slack Incoming Webhook first, then macOS Notification Center and a generic webhook (JSON POST). The MVP keeps adding a target a local change (§3.5)
- A Raycast extension (browsing, editing prompts and settings) — expected in a separate repository. The tool itself is shaped to support it through §3.6
- A full-screen TUI (browsing the list and history) — once interactive prompts and flags are not enough. The MVP is CLI only and does not carry over the template's ratatui `tui` subcommand or its sample
- Detecting and importing `claude -p` entries set up by hand in crontab or LaunchAgents — when needed
- Duplicating jobs, export/import

### Non-goals
- Scheduling commands other than `claude -p` (not a general-purpose scheduler)
- Support for other agent CLIs such as Codex CLI
- Running alongside the AgentCron app, or importing its jobs
- Running while the Mac is off or logged out, or catching up missed runs on waking from sleep
- Resuming a session from another Mac (session records are stored locally)
- Operating systems other than macOS, such as Linux (it would mean maintaining two schedulers and two sleep behaviors)
- Listing or editing scheduled runs the tool did not create (hand-written crontab entries or plists)
- Saving the tool-call log during a run (resume the session to read it if needed)
- Per-job limits such as a budget cap, a maximum turn count, or a tool allowlist (timeout only)
- Multiple users, syncing across Macs, or starting runs remotely

## 3. Features

### 3.1 Job management

#### Specifications

| Item | Specification |
|---|---|
| Where definitions are stored | One file per job in a central configuration directory (path and format decided in design) |
| Name | Required. Identifies the job in commands (for example `agent-cron run daily-review`). Lowercase letters, digits, and hyphens, 1–40 characters, unique across all jobs |
| Folder | Required, absolute path. Defaults to the current directory itself at creation (not adjusted to the git root). Its existence is checked again at run time |
| Renaming | Allowed. History carries over |
| Prompt | Required, not empty, may span lines. Interactively, always entered and edited by opening `$EDITOR` (behavior when `$EDITOR` is unset decided in design). Non-interactively, passed by flag, file, or standard input |
| Schedule | §3.2 |
| model | "Default (follow Claude Code's settings)" / `opus` / `sonnet` / `haiku` / `fable`. Default passes no flag |
| effort | "Default" / `low` / `medium` / `high` / `xhigh` / `max`. Default passes no flag |
| Permission mode | `auto` (default) / `acceptEdits` / `dontAsk` / `plan` / `default` / `bypassPermissions`. Choosing `bypassPermissions` warns at creation and marks the job in the list. Choosing `default` shows a caution, since an unattended run would stall waiting for permission |
| Timeout | In minutes, default 30 |
| Notification | §3.5. Defaults to the global settings |
| Enabled/disabled | Enabled by default |
| Creating and changing | Run with no arguments, it asks one question at a time with choices. Every field can also be given by flag, and when the required fields are all present it asks nothing |
| List | By default, jobs whose folder exactly matches the current one. `--all` shows every folder. Shows name, folder, schedule (human-readable), next run, latest result, and enabled/disabled |
| Operations | Create, list, show, change, disable, enable, delete |

#### Edge Cases
- **No jobs**: the list says there are no jobs in this folder, points to the create command, and gives the number of jobs in other folders with a pointer to `--all`
- **No notification target set**: warns at creation but still creates the job. At run time, history records "no notification target"
- **Duplicate name**: refused on create and change
- **Delete**: deletes the definition, so the scheduler no longer runs it. History is deleted too; interactively it asks to confirm (non-interactively `--yes` is required)
- **Folder later removed**: recorded and notified as a failure at run time (§3.3)

### 3.2 Schedule and execution platform

| Item | Specification |
|---|---|
| When runs happen | Only while the Mac is on and the user is logged in |
| Schedule format | Stored internally as a cron expression (5 fields, local time). Interactively, chosen from presets: daily / weekdays / chosen days × times (several allowed), or every N hours. A cron expression can also be typed directly. The list shows it in human-readable form (for example: weekdays 9:00, 18:00) |
| Times passed during sleep | Not run. When started more than 5 minutes after the scheduled time, it is recorded in history only, as "skipped (past scheduled time)", and not notified. Several missed times collapse into one record |
| Overlap of the same job | If the next time arrives while the previous run is still going, that occurrence is recorded as "skipped (running)" |
| Different jobs at once | Run in parallel (no limit) |
| Sleep during a run | Idle sleep is prevented while a run is in progress (released when it ends). Sleep from closing the lid is not prevented |
| Time zone | The system's local time. A time that does not exist because of daylight saving time is not run, and a repeated time runs once |
| Platform | Favor a design that is easy to understand and maintain as open source. launchd is an option (decided in design) |

### 3.3 Running

- Launch: through the user's login shell (`$SHELL -l -c`, zsh by default on macOS), so that PATH for gh, mise, and the like is close to the terminal's
- Command shape: `claude -p --output-format json --session-id <pre-generated UUID> [--model …] [--effort …] --permission-mode <mode> -- <prompt>`, with the job's folder as the working directory
- The session ID is a UUID generated before the run and passed in, so the resume command can be notified even when a failure or timeout leaves no JSON output
- `--no-session-persistence` is not passed (it would prevent resuming)
- Timeout: past the limit, the process is terminated and the run is recorded and notified as "timed out"
- Trial run: runs the given job once now, in the foreground, regardless of its schedule. Waits until it ends and shows the result and the resume command on the spot. Sends the same notification as a scheduled run (suppressed with `--no-notify`). Refused if the same job is already running. Recorded in history as "manual"
- Stop: a running job can be stopped. Recorded as "stopped"
- Failure before launch (folder missing, `claude` not found): recorded and notified as "failed" with the reason, stating that there is no session

### 3.4 Run history

| Item | Specification |
|---|---|
| Recorded fields | Job name, trigger (scheduled / manual), scheduled time, start and end times, duration, result (succeeded / failed / timed out / stopped / skipped, with the reason), exit code, cost (when reported), session ID, the full `result`, stderr on failure |
| How many are kept | The latest 100 per job (configurable). Older ones beyond that are deleted oldest first |
| Browsing | A job's run list and one run's details (full text, resume command) can be shown |

### 3.5 Notifications

| Item | Specification |
|---|---|
| Targets | Discord Webhook. Every target sits behind one notifier interface, so adding one (Slack first) adds a target value, a service for stored webhooks, and its sender, and changes nothing a user or a `--json` consumer already relies on |
| How URLs are supplied | Only from the tool's own webhook store (a mode 600 file), where `agent-cron webhook` commands set, replace, list, and remove named URLs. No environment variable is read, so a scheduled run and a run from a terminal see the same URLs. When none is stored, diagnostics report the missing setting (§3.7) |
| Global settings | Default: "every configured target, every time" |
| Per-job override | Target (the global setting, a listed target, or none) and condition (every time / failures only) can be overridden. A job can also name a webhook for a different channel (by the name of a stored webhook; the URL itself is never written in the definition) |
| Content | Success or failure, job name, folder, run date and time and duration, Claude Code's output (`result`), resume command |
| Resume command | `cd '<folder>' && claude -r <session ID>` in a code block, ready to copy and paste |
| Long output | Truncated within each service's limit, always keeping at the end "Full text: `agent-cron history <job> <n>`" and the resume command (1 run = 1 message) |
| On failure | A clear failure marker and the reason (failed / timed out / stopped). A failure before launch has no session, so it carries no resume command and says so |
| Send failure | A failed notification never loses the run's result. History records the send failure. No retry |

### 3.6 Interface for programs

- Every operation (create, change, disable, enable, delete, trial run, stop, show history) runs with flags alone, without questions
- List, show, and history print JSON with `--json`. The JSON shape is documented and kept compatible (removing a field or changing its meaning is a breaking change)
- Long text such as the prompt can be passed by flag, file, or standard input
- Errors are distinguishable by exit code, which stays 0, 1, or 2. Under `--json`, an error is one JSON document on stdout, and error kinds are told apart by its `code`
- When not on a terminal (no TTY), no questions are asked; missing fields are reported as an error
- Intended users: Claude Code setting up schedules on the user's behalf, and a future Raycast extension browsing and editing

### 3.7 Setup diagnostics

- Checks and shows whether the notification URLs are found, where `claude` resolves in the login shell (with its version), and that the single scheduler agent is loaded and points at the current binary
- Can send a test notification

## 4. Cross-cutting rules

- Secrets such as webhook URLs are never written to history, logs, notification bodies, or job definitions.
- The tool does not handle Claude Code's credentials. It relies on the existing Claude Code login.
- Prompts and output are stored only locally (apart from the output sent to notification targets).
- All of the tool's wording, including notification templates, is English.

## 5. Data

- Job definitions: a central configuration directory, one file per job (path and format decided in design)
- Run history: local, the latest 100 per job (location and format decided in design)
- Uninstall: `agent-cron uninstall` removes the scheduler agent. The data directory is kept

## 6. Open questions

- `zsh -l -c` does not read `.zshrc`, so PATH may differ from the terminal's (in AgentCron, `claude` once resolved to a mise shim) — setup diagnostics (§3.7) show where it resolves, and a fix is decided if a problem shows up in real use
