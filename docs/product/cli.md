# agent-cron — Command-line design

- **Status:** Signed off 2026-10-11; rewritten in place as the command line changes
- **Implements:** [requirements.md](requirements.md) §3.1–§3.7. Section numbers below cite it.
- **Follows:** the template's `designing-clis` skill. stdout carries data and stderr
  carries everything else. Output is plain text with no color. Exit codes are 0, 1, and
  2. Every sentence comes from `wording.rs`.

## 1. Principles

1. **One command line for people and programs.** Every operation can run without
   questions. A person at a terminal is asked only for what they left out (§3.6).
2. **Flat verbs on the job.** `agent-cron <verb> <job>`. A job is named by its name. A
   run is named by its job and a per-job sequence number `n`. Numbers start at 1, only
   go up, are never reused, and survive a rename.
3. **stdout is the answer, stderr is the conversation.** Questions, notes, hints,
   warnings, and errors go to stderr. A mutating command prints the resulting job on
   stdout, so `agent-cron add … --json` returns what was created.
4. **English only** for every string the tool writes, notification templates included.
   Claude Code's own `result` text is passed through as is.

## 2. Command overview

| Command | Does | §  |
|---|---|---|
| `agent-cron add [<name>]` | Create a job. Asks for anything missing when interactive | 3.1 |
| `agent-cron list` (`ls`) | Jobs whose folder is exactly the current folder. With `--all`, every job | 3.1 |
| `agent-cron show <job>` | One job: its definition, the prompt, the next 5 times, the last run | 3.1 |
| `agent-cron edit <job>` | Change fields with flags. With no flags and a terminal, choose fields from a menu | 3.1 |
| `agent-cron enable <job>` / `disable <job>` | Turn scheduling on or off. Running either twice is harmless | 3.1 |
| `agent-cron rm <job>` (`remove`) | Delete the job and its history. Asks to confirm. Without a terminal, `--yes` is required | 3.1 |
| `agent-cron run <job>` | Run once now, in the foreground, and notify. `--no-notify` suppresses the notification | 3.3 |
| `agent-cron stop <job>` | Stop the job's current run | 3.3 |
| `agent-cron history <job> [<n>]` | List the job's runs, or show one run in full | 3.4 |
| `agent-cron webhook set\|unset\|list\|test` | Manage the stored webhook URLs (mode 600) and send a test message | 3.5, 3.7 |
| `agent-cron config [get <key>\|set <key> <value>]` | Global settings: default notification targets and condition, history size | 3.4, 3.5 |
| `agent-cron doctor` | Check the scheduler agent, `claude`, the webhooks, and each job | 3.7 |
| `agent-cron install` / `uninstall` | Load or remove the scheduler agent. Data is kept. `add` and `enable` install it when it is missing | 3.2, §5 |
| `agent-cron tick` *(hidden)* | Started by launchd every minute. Decides which jobs are due and starts them | 3.2 |
| `agent-cron exec <job> --scheduled-at <time>` *(hidden)* | The detached runner the tick starts | 3.3 |

Every command that prints data accepts `--json`. Global flags: `-h/--help` and
`-V/--version`.

## 3. Job fields and their flags

The same flags work on `add` and `edit`. `edit` also takes `--name <new-name>`.

| Field | Flag | Default | Rule |
|---|---|---|---|
| name | positional `<name>` | — (required) | `^[a-z0-9]+(-[a-z0-9]+)*$`, 1–40 characters, unique among all jobs |
| folder | `--dir <path>` | the current folder, as is | Made absolute. Must exist when the job is created or changed, and is checked again before every run |
| prompt | `--prompt <text>` \| `--prompt-file <path>` (`-` reads stdin) | — (required) | Must not be empty after trimming. May span several lines. Interactive entry always goes through the editor |
| schedule | `--at <HH:MM>[,…]` with `--on <daily\|weekdays\|mon,tue,…>` (default `daily`) \| `--every <N>h` \| `--cron "<expr>"` | — (required) | These three forms exclude each other. Each one compiles to a 5-field cron expression in local time, which is what gets stored. `N` is one of 1, 2, 3, 4, 6, 8, 12, and the run lands on minute 0 |
| model | `--model <default\|opus\|sonnet\|haiku\|fable>` | `default` (no `--model` flag is passed to claude) | |
| effort | `--effort <default\|low\|medium\|high\|xhigh\|max>` | `default` | |
| permission mode | `--permission-mode <auto\|acceptEdits\|dontAsk\|plan\|default\|bypassPermissions>` | `auto` | `bypassPermissions` prints `warning:` and is marked `BYPASS` in `list`. `default` prints a `warning:` that an unattended run may stall waiting for approval |
| timeout | `--timeout <minutes>` | 30 | 1–1440 |
| notification targets | `--notify <default\|discord\|none>` | `default` (the global setting) | One value per target (§9) |
| notification condition | `--notify-on <default\|always\|failure>` | `default` | |
| per-job webhook | `--discord-webhook <name>` | `discord` | The **name** of a webhook stored with `agent-cron webhook set`. A URL is never stored in a job |
| enabled | `--disabled` (on `add` only) | enabled | `enable` and `disable` change it later |

Shared flags:

- `--no-input` never asks a question, even at a terminal.
- `--yes` accepts a confirmation (`rm`, `uninstall`).
- `--json` prints a JSON document and implies `--no-input`.

**When the tool asks.** It asks only when stdin and stderr are both terminals, and
neither `--no-input` nor `--json` is given. Otherwise a missing required field is
`input_required`, and a missing confirmation is `confirmation_required`. Both exit with
2, the usage-error code, and list what is missing.

**The editor.** The tool uses `$VISUAL`, then `$EDITOR`, then `vi`, the same order git
uses. The temporary file starts with the current prompt, or is empty for a new job,
followed by a scissors line:

```
# ------------------------ >8 ------------------------
# Everything below this line is ignored. Save and close to continue;
# leave the prompt empty to cancel.
```

Lines starting with `#` above the line are kept, because prompts are often Markdown.
An empty result cancels with `prompt_empty`.

## 4. Interactive flows

Prompts are drawn on stderr with `dialoguer`: arrow-key selection, text input checked
as you type, and yes/no confirmation. Ctrl-C at any question cancels, writes nothing,
and exits 1 with `error: cancelled`.

### 4.1 `agent-cron add`

```
$ agent-cron add
? Job name › daily-review
? Folder › /Users/me/src/shop            (Enter keeps the current folder)
  Opening vi for the prompt…
? Schedule ›
  > Every weekday
    Every day
    Specific days
    Every N hours
    Cron expression
? Times (HH:MM, comma-separated) › 09:00, 18:00
  weekdays 09:00, 18:00 — next: Mon 10-12 09:00, Mon 10-12 18:00, Tue 10-13 09:00
? Change advanced settings (model, effort, permission mode, timeout, notifications)? › No

  name        daily-review
  folder      /Users/me/src/shop
  schedule    weekdays 09:00, 18:00
  prompt      Review yesterday's merged PRs and list follow-ups… (12 lines)
  model       default    effort  default
  permission  auto       timeout 30 min
  notify      default (discord · every run)
? Create this job? › Yes
note: installed the scheduler agent; macOS may show a "Background Items Added" notification
daily-review  weekdays 09:00, 18:00  next Mon 10-12 09:00  enabled
```

- Choosing **Specific days** opens a multi-select of Mon to Sun, then the times
  question. **Every N hours** offers 1, 2, 3, 4, 6, 8, or 12. **Cron expression** takes
  free text and echoes its description and next 3 times before going on.
- **Advanced settings: Yes** asks model, effort, permission mode, timeout, and
  notifications in that order. Choosing `bypassPermissions` shows its warning and asks
  "Run with all permission checks off?", defaulting to No. Notifications offers "Use the
  global setting" or "Customize". Customize asks for targets, then the condition, then
  an optional stored webhook name per target.
- When no webhook is configured, the summary shows `notify  none configured`. After the
  job is created the tool prints
  `warning: no webhook is configured; runs will be recorded but not notified` and
  `hint: agent-cron webhook set discord` (§3.1 edge case).
- Flags fill in their answers, and those questions are skipped. `agent-cron add
  daily-review --at 09:00 --on weekdays` asks only for the prompt, then shows the
  summary.

### 4.2 `agent-cron edit <job>`

With flags, the change is applied at once and the job is printed. With no flags at a
terminal:

```
$ agent-cron edit daily-review
? What do you want to change? ›
  > Prompt
    Schedule            weekdays 09:00, 18:00
    Folder              /Users/me/src/shop
    Name                daily-review
    Model / effort      default / default
    Permission mode     auto
    Timeout             30 min
    Notifications       default
    Done
```

The menu comes back after each change until **Done**. It then shows the changed fields
as `old → new` and asks "Save these changes?". Renaming checks that the new name is
free. History is kept under the new name.

### 4.3 `agent-cron rm <job>`

`? Delete daily-review and its 42 run records? › No` (the default is No). If the job is
running, the tool refuses with `job_running` and hints at `agent-cron stop`.

## 5. Human output

All of this is plain text. Columns are padded with spaces and never truncated. Times
are local, in the form `Mon 10-12 09:00`, or `Mon 2026-10-12 09:00` when the year
differs. A folder under the home directory is shown with `~`.

### 5.1 `list`

```
$ agent-cron list
NAME           SCHEDULE                NEXT RUN         LAST                  MODE    STATE
daily-review   weekdays 09:00, 18:00   Mon 10-12 09:00  ok      Fri 10-09 18:00  auto    enabled
deps-audit     Mon 08:30               Mon 10-12 08:30  failed  Mon 10-05 08:31  BYPASS  enabled
weekly-notes   cron: 0 7 1-7 * 1       —                —                     auto    disabled
```

- `LAST` is one of: `ok`, `failed`, `timeout`, `stopped`, `skipped`, `running` (since
  09:00), or `—`.
- `--all` adds a `FOLDER` column after `NAME`.
- With no jobs here, stdout stays empty and stderr says:

  ```
  no jobs in this folder
  hint: create one with `agent-cron add`
  hint: 3 jobs in other folders — `agent-cron list --all`
  ```

### 5.2 Schedule descriptions

| Cron | Description |
|---|---|
| `0 9 * * *` | `daily 09:00` |
| `0 9,18 * * 1-5` | `weekdays 09:00, 18:00` |
| `30 8 * * 1,3,5` | `Mon, Wed, Fri 08:30` |
| `0 */3 * * *` | `every 3 hours` |
| anything else | `cron: <expr>` |

### 5.3 `show <job>`

This prints a block of `key  value` lines, as in the summary in §4.1. Then come the
full prompt, set off by a blank line and indented 2 spaces; `next runs` with 5 times;
`last run` as `run 42 ok Fri 10-09 18:00 (3m 12s, $0.42)`; and `running` with the run
number and start time when a run is going.

### 5.4 `history <job>` and `history <job> <n>`

```
$ agent-cron history daily-review
  #  TRIGGER   SCHEDULED        STARTED          DURATION  RESULT              COST
 42  schedule  Fri 10-09 18:00  Fri 10-09 18:00  3m 12s    ok                  $0.42
 41  schedule  Fri 10-09 09:00  —                —         skipped (late ×2)   —
 40  manual    —                Thu 10-08 21:14  0m 48s    failed (exit 1)     $0.05
```

`--limit N` defaults to 20. `history daily-review 42` prints the full record:

```
run          daily-review run 42
trigger      schedule (Fri 10-09 18:00)
started      Fri 10-09 18:00:04
finished     Fri 10-09 18:03:16 (3m 12s)
result       ok (exit 0)
cost         $0.42
session      3f2a…-…
notification sent: discord

resume:
cd '/Users/me/src/shop' && claude -r 3f2a9c1e-…

output:
  <result, in full>
```

On a failure, an indented `stderr:` section is added. A failure before start says
`no session — claude did not start`.

### 5.5 `run <job>`

While the job runs, stderr shows
`running daily-review in ~/src/shop (timeout 30 min)… Ctrl-C stops it`. At the end,
stdout carries the same record as `history <job> <n>`. The exit code is 0 only when
the run succeeded. Ctrl-C stops claude's process group, records the run as `stopped`,
and exits 1.

### 5.6 `doctor`

```
ok    scheduler agent loaded (~/Library/LaunchAgents/<bundle-id>.plist → ~/.cargo/bin/agent-cron)
ok    claude 2.1.296 at ~/.local/bin/claude (via /bin/zsh -l)
ok    webhooks.json is mode 600
ok    discord webhook discord
warn  job deps-audit runs with bypassPermissions
fail  job deps-audit: folder ~/src/old-repo does not exist
ok    3 jobs, next run daily-review Mon 10-12 09:00
```

The tool exits 1 when any line is `fail`, and otherwise 0. A `warn` does not fail the
check. A webhook URL is never printed; only its name.

## 6. JSON output

Every document is one JSON object on stdout. Times are RFC 3339 with the local offset.
The contract:

- Fields are only ever added.
- A removal, a rename, or a change of meaning is a breaking change and goes in
  `CHANGELOG.md`.
- `null` means "not set" or "not applicable". It never means "unknown".

**Job** (`show`, plus every mutating command; `list` omits `prompt`):

```json
{
  "name": "daily-review",
  "dir": "/Users/me/src/shop",
  "enabled": true,
  "schedule": { "cron": "0 9,18 * * 1-5", "description": "weekdays 09:00, 18:00" },
  "next_run": "2026-10-12T09:00:00+09:00",
  "prompt": "Review yesterday's merged PRs…",
  "model": null,
  "effort": null,
  "permission_mode": "auto",
  "timeout_minutes": 30,
  "notify": { "targets": "default", "on": "default", "webhooks": { "discord": null } },
  "running": null,
  "last_run": { "n": 42, "status": "succeeded", "started_at": "2026-10-09T18:00:04+09:00" }
}
```

`running` is `{ "n": 43, "started_at": "…" }` while a run is going. `list` returns
`{ "folder": "/Users/me/src/shop", "jobs": [ … ], "jobs_elsewhere": 3 }`. With `--all`,
`folder` and `jobs_elsewhere` are `null`.

**Run** (`history <job> <n>`, `run`):

```json
{
  "job": "daily-review",
  "n": 42,
  "trigger": "schedule",
  "scheduled_at": "2026-10-09T18:00:00+09:00",
  "started_at": "2026-10-09T18:00:04+09:00",
  "finished_at": "2026-10-09T18:03:16+09:00",
  "duration_ms": 192000,
  "status": "succeeded",
  "reason": null,
  "missed_count": null,
  "exit_code": 0,
  "cost_usd": 0.42,
  "session_id": "3f2a9c1e-…",
  "resume_command": "cd '/Users/me/src/shop' && claude -r 3f2a9c1e-…",
  "result": "…",
  "stderr": null,
  "notification": { "status": "sent", "targets": ["discord"] }
}
```

- `status` is one of `succeeded`, `failed`, `timed_out`, `stopped`, `skipped`, or
  `running`.
- `reason` is `null`, or one of:
  - for `skipped`: `late` or `running`;
  - for `failed`: `folder_missing`, `claude_not_found`, `spawn_failed`, or
    `exit_nonzero`, or `interrupted` (the runner died before finishing the record).
- A late skip that covers several times sets `missed_count`, and `scheduled_at` holds
  the latest of them.
- `notification.status` is one of `sent`, `failed`, `not_configured`, `suppressed`
  (from `--no-notify` or the condition), or `not_sent` (a skip).
- `history <job>` returns `{ "job": "…", "runs": [ … ] }`, and each run omits `result`
  and `stderr`.

**Others:**

- `doctor` returns `{ "checks": [ { "id": "scheduler_agent", "level": "ok", "message":
  "…" } ], "ok": true }`.
- `webhook list` returns `{ "webhooks": [ { "name": "discord", "service": "discord" }
  ] }`. A URL never appears.
- `config` returns `{ "notify": { "targets": "all", "on": "always" }, "history": {
  "limit": 100 } }`.

**Errors under `--json`:** stdout carries
`{ "error": { "code": "job_not_found", "message": "no job named nightly-report" } }`, and
stderr still carries the `error: …` line. A clap usage error (an unknown flag) is
plain clap text with exit 2. It is reported before the tool knows `--json` was given.

## 7. Exit codes and errors

| Code | Meaning |
|---|---|
| 0 | Success. For `run`, the job also succeeded. For `doctor`, nothing failed |
| 1 | The action failed, or `run`'s job did not succeed, or `doctor` found a `fail` |
| 2 | Usage error: clap's own errors, `input_required`, `confirmation_required` |

| `code` | When | Exit |
|---|---|---|
| `job_not_found` | No job has that name | 1 |
| `name_taken` / `invalid_name` | `add` or a rename | 1 |
| `invalid_schedule` | A bad `--at`, `--every`, or `--cron` value | 1 |
| `dir_missing` | `--dir` does not exist | 1 |
| `prompt_empty` | The prompt is empty after editing or reading | 1 |
| `job_running` | `run` or `rm` while a run is going | 1 |
| `not_running` | `stop` when no run is going | 1 |
| `input_required` / `confirmation_required` | No terminal to ask | 2 |
| `cancelled` | Ctrl-C at a question | 1 |
| `editor_failed` | The editor exited non-zero or could not start | 1 |
| `scheduler_failed` | `launchctl` could not load or remove the agent | 1 |
| `storage` / `data_too_new` | A job or history file could not be read or written, or comes from a newer version | 1 |
| `webhook_invalid` / `webhook_not_found` / `notify_failed` | `webhook set` or `webhook test` | 1 |
| `webhook_insecure` | The webhook file's mode is wider than 600; `webhook set` rewrites it | 1 |

A message may name the job. It never contains a path, the prompt, a URL, or claude's
output, so it can be pasted into a public issue. This is a deliberate narrowing of the
template's "nothing the user typed": a job name is an identifier the user chose, and
leaving it out would make errors useless.

## 8. Notifications (§3.5)

There is one message per run. Skips are not notified. The layout is written in Discord
Markdown, and a later target renders the same parts in its own format:

```
✅ daily-review succeeded            (❌ failed · ⏱ timed out · ⏹ stopped)
~/src/shop · Fri 10-09 18:00 · 3m 12s · $0.42

<result, truncated to fit>
… truncated — full output: `agent-cron history daily-review 42`

Resume:
```cd '/Users/me/src/shop' && claude -r 3f2a9c1e-…```
```

- The resume command is the full absolute path, not the `~` form, so it pastes from
  anywhere.
- The truncation budget is each service's limit minus the header and footer, measured
  at implementation. The footer and the resume command are always kept.
- A failure states the reason. A failure before start says
  "no session — claude did not start" instead of a resume block.

## 9. Webhooks and configuration

- `agent-cron webhook set discord [--name <name>]` reads the URL from a hidden prompt,
  or from stdin when there is no terminal. It checks that the URL is a Discord webhook
  (HTTPS on `discord.com` or `discordapp.com`, under `/api/webhooks/`) and stores it
  under the name, `discord` by default, in `webhooks.json` with mode 600. Setting a
  name that exists replaces its URL.
- `webhook unset <name>` removes a stored webhook. `webhook list` shows each name and
  its service. `webhook test [<name>] [--job <job>]` sends a test message, either to
  the global targets, to one stored webhook, or along a job's own routing.
- The stored webhooks are the only place a URL comes from. No environment variable is
  read, so a scheduled run and a run from a terminal always use the same URLs (§3.5).
- **Discord is the only target today, and the command line is shaped for more.** A
  target is a value in `--notify`, `notify.targets`, and `webhook set`, with its own
  `--<target>-webhook` flag, its own key under a job's `notify.webhooks`, and its own
  default webhook name. Adding one, with Slack first, adds those values and a sender
  behind the same notifier interface. No existing flag, field, or default changes
  meaning, so it is not a breaking change for a script.
- `config set notify.targets <all|discord|none>`, `config set notify.on
  <always|failure>`, and `config set history.limit <1–10000>`. A value that does not
  parse fails with exit 1 and names the key.

## 10. Dependencies this design needs

The crates, their versions, and where each goes are in [design.md](design.md) §8. Each is
added with the owner's sign-off, as `managing-dependencies` sets out.
