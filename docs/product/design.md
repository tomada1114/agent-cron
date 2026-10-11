# agent-cron — Design

- **Status:** Signed off 2026-10-11. This page describes the design that still has to be
  built.
- **Implements:** [requirements.md](requirements.md) and [cli.md](cli.md). Section
  numbers written as §n cite the requirements.
- **How this page shrinks:** a pull request that builds a part of this design rewrites
  `AGENTS.md` › Architecture, `docs/architecture.md`, and the skill that owns the subject
  so they describe what was built, in the present tense. It then deletes that part from
  this page. A part not built yet is described only here, and a part already built is
  described only there. The page is removed once nothing on it is left to build.

## 1. Principles

Each principle rules something out.

1. **Core decides; everything else translates.** Cron semantics, which job is due, a
   run's outcome, history retention, notification routing and truncation, and every
   validation live in `agent-cron-core`, under its coverage floor. Two things are
   ruled out: schedule rules split between our code and launchd, and decisions made in
   `agent-cron-platform` or in the binary.
2. **Job files are the only source of truth.** One launchd registration exists, and it
   never changes when a job does. This rules out a plist per job, and rules out
   `doctor` having to audit N registrations.
3. **No resident process.** A tick starts once a minute and exits. This rules out a
   daemon, its sleep detection, and the restart step it would need after
   `cargo install`.
4. **A run's result is never lost to what follows it.** The history record is written
   before the notification is sent, and a failed send is written into that record. This
   rules out a notification step that can drop or block a result.
5. **Secrets have one home.** Webhook URLs live only in `webhooks.json` (mode 600),
   which the `webhook` subcommands manage. They never appear in a job file, a history
   record, a log line, an error message, or `--json` output. This rules out looking
   them up in environment variables and keeping a second copy anywhere.
6. **Nothing the tool does needs a human at a prompt.** It uses no Keychain item and
   requests no privacy (TCC) grant. Its only OS registration is a user LaunchAgent.
7. **macOS only.** Linux is not a target. Linux code paths are removed, not stubbed:
   the XDG directories, the Linux CI job, and `cfg(target_os = "linux")` branches.

## 2. Platform scope

The tool builds, runs, and is tested on macOS only. Core still holds no OS API, because
`crates/agent-cron-core/clippy.toml` bans one and the dependency closure check rejects
platform crates. This keeps core's logic testable with plain values. It no longer means
core runs on Linux.

Removing Linux touches several things:

- the data and log paths, where only the `~/Library/…` mapping stays;
- CI, where the `Rust Core` job moves to a macOS runner or merges with the `macOS` job;
- the `test-platform` recipe's wording;
- `AGENTS.md` and the skills where they say "macOS and Linux".

These are gate changes, so they follow `changing-gates`. The CI change keeps every check
that runs today and only changes the host.

## 3. Shape

| Domain | Layer | Module (planned) | What crosses the boundary |
|---|---|---|---|
| Job definition and validation (name, folder, prompt, schedule, options) | core | `job` | `Job`, `JobId`, `JobName`, `JobError` |
| Cron parsing, next times, DST rules, the schedule's shape for display | core | `schedule` | `Schedule`, `ScheduleShape`, `ScheduleError` |
| Which jobs are due at a tick | core | `tick` | `due(jobs, previous_tick, now, running, zone) -> Vec<TickDecision>` |
| A run: its record, outcome, and history retention | core | `run` | `RunRecord`, `RunStatus`, `RunReason`, `RunService` |
| Notification routing, the message's parts, truncation | core | `notify` | `NotificationView`, `fit_result(text, budget)` |
| Webhook names and URL validation | core | `webhook` | `WebhookName`, `WebhookUrl`, `WebhookError` |
| Global settings | core | `settings` | `Settings` |
| Setup diagnostics: which checks run and their levels | core | `doctor` | `Check`, `CheckLevel` |
| The prompt editor's scissors-line parse | core | `prompt` | `parse_edited_prompt(text) -> Result<Prompt, PromptError>` |
| Files, locks, launchd, processes, HTTPS, randomness, the system time zone | platform | one adapter per port (below) | core's port traits and kinds |
| Arguments, interactive prompts, wording, `--json`, exit codes, Ctrl-C | binary | `crates/agent-cron/src/` | calls into core; wording from `wording.rs` |

### Ports

Each port follows the template's pattern: a synchronous `Send + Sync` trait in core, an
adapter in `agent-cron-platform`, a fake and a `<port>_contract` function in
`agent-cron-test-support`.

| Port | What it promises | Adapter |
|---|---|---|
| `JobStore` | List, load, save atomically, and delete job files. Mutations hold `jobs.lock` | `JsonJobStore` |
| `RunStore` | Allocate the next run number and write, update, list, prune, and delete records. Try to take a job's run lock, returning a guard that releases on drop or on process death. Create, check, and clear a job's stop marker | `JsonRunStore` |
| `SettingsStore` | Load and save `config.json` (core's `Settings`) and `tick.json` | `JsonSettingsStore` |
| `Folders` | Report whether a path is an existing directory. Used when a job is created or changed (`dir_missing`) and before each run (`folder_missing`) | `StdFolders` |
| `WebhookStore` | Get, set, remove, and list named webhook URLs. Report the file's mode | `JsonWebhookStore` |
| `SchedulerAgent` | Install, uninstall, and report the LaunchAgent: loaded, disabled, and which binary it starts. Under a scratch `HOME` it never calls `launchctl` (§5) | `LaunchAgent` |
| `ProcessHost` | Start claude through the login shell in its own process group, under idle-sleep prevention. Wait for it until a deadline, and signal a process group. Locate claude through the login shell and report its path and version, for `doctor` | `ShellProcessHost` |
| `Notifier` | Send one rendered message to one webhook. Return a failure kind, never the URL | `DiscordNotifier` |
| `Clock` | The current instant. This port already exists | `SystemClock` |
| `IdSource` | A new random UUID v4, used for `--session-id` and `JobId` | `RandomIds` |

The local time zone is not a port. The binary asks platform for it once
(`system_time_zone() -> jiff::tz::TimeZone`) and passes it to core as a value. A test
builds one from a POSIX TZ string, which needs no time zone database. Core also turns an
instant into a `LocalStamp` (weekday, date, time, and whether the year differs from
now's) in that zone, so every view carries local times as parts. The binary formats a
`LocalStamp` as `Mon 10-12 09:00` with `wording.rs`, and never needs jiff itself.

### Wording stays out of core

Core returns structure, never a sentence. The binary renders all text from
`wording.rs`:

- **Schedules.** Core returns a `ScheduleShape`: `Daily { times }`,
  `Weekdays { times }`, `Days { days, times }`, `EveryHours(n)`, or `Cron(expr)`. The
  binary renders it as `weekdays 09:00, 18:00`.
- **Notifications.** Core returns a `NotificationView`: status, job, folder, times,
  duration, cost, the result text, the resume command, and the history footer's job
  and run number. The binary renders the header and footer with `wording.rs`. It
  measures their length and calls core's `fit_result(result, budget)`, which truncates
  on a character boundary and reports whether it cut anything. The truncation rule is
  core's: the footer and the resume command are always kept, and only the result
  shrinks. That rule sits under the floor, while the words stay in the binary.

## 4. Data

Everything lives in `~/Library/Application Support/io.github.tomada1114.agent-cron/`.
Logs live in `~/Library/Logs/io.github.tomada1114.agent-cron/`, as they do today.

```text
io.github.tomada1114.agent-cron/
├── config.json          global settings
├── tick.json            the previous tick's instant
├── webhooks.json        named webhook URLs, mode 600
├── jobs/<job-id>.json   one file per job
├── runs/<job-id>/<n>.json
└── locks/
    ├── jobs.lock        held while any job file changes
    ├── <job-id>.run     held for the whole of a run
    ├── <job-id>.hist    held briefly to allocate a run number and prune
    └── <job-id>.stop    present while a stop is requested
```

**Common rules.** Every JSON file has a `"version": 1` field. Every write goes to a
temporary file in the same directory, which is synced, renamed over the old file, and
then the directory is synced. That is the pattern `counter.json` uses today, so a crash
leaves either the old file or the new one. A reader handles versions this way:

- A newer `version` is `data_too_new`, and the reader leaves the file untouched.
- An unreadable file is `storage` with kind `corrupt`.
- A field added later is read with `#[serde(default)]`.
- A renamed or removed field bumps `version`, and the reader keeps accepting the old
  one.

Locks are advisory `std::fs::File` locks (`lock`, `try_lock`). The kernel drops them
when their process exits, so a crashed runner never leaves a job locked. These file
formats, the directory layout, and the data location are contract
(`docs/architecture.md` › "What is contract and what is private").

**Job (`jobs/<job-id>.json`).**

- The file name is the job's `JobId`, a UUID v4 generated at creation. It never
  changes.
- `name` is a field inside the file. A rename therefore rewrites one file, atomically,
  under `jobs.lock`. It is safe while the job is running, and history needs no move.
- Uniqueness of `name` is checked under `jobs.lock`.
- The other fields are the job fields in `cli.md` §3:
  - `dir`;
  - `prompt`;
  - `schedule`, stored as the cron string;
  - `model` and `effort`, where `null` means default;
  - `permission_mode`;
  - `timeout_minutes`;
  - `notify`: `targets`, `on`, and `webhooks`, which maps a target to the name of a
    stored webhook or `null`;
  - `enabled`;
  - `created_at`.

**Run (`runs/<job-id>/<n>.json`).**

- The fields are those of the run JSON in `cli.md` §6, plus `pgid` while the run is
  going.
- **Allocation.** The run number `n` is the largest number in the job's run directory
  plus one, computed under `<job-id>.hist`. Pruning deletes the oldest records first,
  and a job's directory is removed only together with the job. So the largest number
  always survives and `n` is never reused.
- **Pruning.** After each record is finished, the directory is pruned to
  `history.limit` (default 100) under the same lock.
- **A crashed runner.** Suppose a record says `running` but its job's `.run` lock is
  free. The next reader that holds `.hist` rewrites the record as `failed`, reason
  `interrupted`, before using the history.

**`config.json`.** It holds `notify.targets` (`all`, `discord`, or `none`; default
`all`), `notify.on` (`always` or `failure`; default `always`), and `history.limit`
(1–10000; default 100). A missing file means all defaults.

**`tick.json`.** It holds `last_tick`, an instant.

**`webhooks.json`.**

- It holds `{ "version": 1, "webhooks": { "<name>": { "service": "discord", "url":
  "…" } } }`.
- `agent-cron webhook set discord` stores the name `discord` by default. `--name <name>`
  stores another name, for a different channel.
- The file is created with mode 600, and every write keeps that mode.
- If the mode is wider, `doctor` reports `fail`, and the tool refuses to read the file
  until the user runs `webhook set` again. The refusal is the error `webhook_insecure`
  in `cli.md` §7.
- This file is the only place the tool reads a URL from. It reads no environment
  variable.

**Deleting a job** is refused while its `.run` lock is held (`job_running`). Otherwise it
removes the job file, its run directory, and its lock files. `agent-cron uninstall`
removes the LaunchAgent and keeps this whole directory (§5).

## 5. Scheduler

One user LaunchAgent fires every minute and runs `agent-cron tick`.

### The plist

The plist is `~/Library/LaunchAgents/io.github.tomada1114.agent-cron.plist`:

| Key | Value | Why |
|---|---|---|
| `Label` | `io.github.tomada1114.agent-cron` | the bundle identifier, already fixed |
| `ProgramArguments` | `[<absolute path of the agent-cron binary>, "tick"]` | `doctor` compares this path with the running binary |
| `StartCalendarInterval` | `{}` | "Missing arguments are considered to be wildcard", so it fires every minute |
| `AbandonProcessGroup` | `true` | without it, launchd kills the tick's process group, and with it the runs the tick started, when the tick exits |
| `ProcessType` | `Standard` | when the key is left unset, launchd applies "light resource limits" that throttle CPU and I/O. A run is work the user asked for |

The plist's content is a pure function with a golden test. Installing it runs
`launchctl bootstrap gui/<uid> <plist>`, and removing it runs `launchctl bootout
gui/<uid>/<label>`. `doctor` checks three things:

- the agent is loaded (`launchctl print gui/<uid>/<label>`);
- it is not disabled (`launchctl print-disabled gui/<uid>`);
- `ProgramArguments[0]` is the current executable.

No test and no agent check loads the agent into the real `gui/<uid>` domain
(`AGENTS.md` › "Never taking over the developer's Mac"). That is an
`#[ignore = "local machine: loads a LaunchAgent"]` test, run by a human with
`just test-local`.

`agent-cron add` and `agent-cron enable` install the agent when it is missing and say
so. The text is the `note:` line in `cli.md` §4.1.

### The tick

`agent-cron tick` reads every job file and `tick.json`, then asks core for decisions:

```text
due(jobs, previous_tick, now, running, zone) -> [TickDecision]
  for each enabled job, over the scheduled instants in (previous_tick, now]:
    none                         → nothing
    the latest is ≤ 5 min old    → Run { scheduled_at: latest }
                                   (SkipRunning instead when its .run lock is held)
    any older than 5 min         → one SkipLate { scheduled_at: the latest of them,
                                                  missed_count }
```

A job can get both a `SkipLate` and a `Run` from one tick: after a wake, the missed
times collapse into one skip record and the time that is still fresh runs.

**First tick and clock changes.**

- On the first tick, with no `tick.json`, the previous tick counts as now. Nothing is
  backfilled.
- If the clock moved backwards (now is before the previous tick), the tick stores now
  and decides nothing.

**Turning cron times into instants.**

- A cron time is turned into an instant in the system zone.
- A local time that does not exist (the spring-forward gap) yields no instant.
- A local time that happens twice (the autumn fold) yields only its earlier instant.

Core does this through jiff's `TimeZone::to_ambiguous_zoned`, and does not use
`Disambiguation::Compatible`, which would move a gap time later
(<https://docs.rs/jiff/0.2.38/jiff/tz/enum.Disambiguation.html>, checked 2026-10-11).

**Acting on the decisions.**

- Skips are written as history records with no notification.
- Each `Run` starts `agent-cron exec <job-id> --scheduled-at <instant>`, detached,
  with stdin, stdout, and stderr set to null.
- The tick then writes `tick.json` and exits.

**Why one ticking agent.** Three designs were compared:

- A plist per job would translate each cron expression into `StartCalendarInterval`
  dictionaries, which have no ranges or steps. `*/5 9-17 * * 1-5` alone becomes 540
  dictionaries. The rules would then be split between that translation and launchd's
  own: launchd starts a job on wake for missed times, "coalesced into one event". And
  every job edit would become a `launchctl` call.
- A resident daemon would keep running the old binary after `cargo install`, and would
  have to detect sleep itself.
- The minute tick keeps every rule in one tested core function. It has one
  registration that never changes, and it picks up a new binary within a minute.

The cost is one short process a minute, and a start up to about a minute late plus
launchd's timer coalescing. That is acceptable at cron's one-minute resolution.

Sources: `man 5 launchd.plist` on macOS 27.0 (26A428), checked 2026-10-11, entries
`StartCalendarInterval`, `AbandonProcessGroup`, `ProcessType`, and `LegacyTimers`.
`man 1 launchctl`, same system and date: `bootstrap`, `bootout`, `print`, and
`print-disabled`.

## 6. Runner

`agent-cron exec` (scheduled) and `agent-cron run` (manual, in the foreground) share one
core use case, `RunService::run`. The steps:

1. **Take the run lock.** Try to take the job's `.run` lock. If it is held, record
   `skipped`, reason `running`. A manual run instead refuses with `job_running`.
2. **Start the record.** Under `.hist`, allocate `n` and write a `running` record with
   the trigger, `scheduled_at`, `started_at`, and a new session ID from `IdSource`.
3. **Check before launch.** If the folder is missing, the run is `failed` with reason
   `folder_missing` and has no session.
4. **Launch.** `ProcessHost` takes the login shell from `SHELL`. When `SHELL` is unset,
   as it is under launchd, it falls back to the user record,
   `nix::unistd::User::from_uid(getuid()).shell`. On macOS 27.0 (26A428),
   `launchctl print gui/<uid>/<label>` shows only `PATH` in a user agent's default
   environment, checked 2026-10-11. The home directory falls back to the user record
   the same way when `HOME` is unset. It then runs:

   ```sh
   <shell> -l -c 'exec claude "$@"' agent-cron -p --output-format json \
     --session-id <uuid> [--model …] [--effort …] --permission-mode <mode> -- <prompt>
   ```

   - The prompt and every option travel as arguments, never inside the script string,
     so no quoting can break them.
   - The working directory is the job's folder. Stdin is null in both `exec` and
     `run`. In a manual run, claude's process group is not the terminal's foreground
     group, so reading the terminal would stop it with `SIGTTIN`.
   - The process gets its own process group (`CommandExt::process_group(0)`, no
     `unsafe`).
   - `/usr/bin/caffeinate -i -w <runner pid>` holds off idle sleep until the runner
     exits (§3.2).
   - Exit status 127 from the shell means `failed` with reason `claude_not_found`.
5. **Wait.** Core waits in slices of at most one second. Each slice is a
   `ProcessHost` wait that blocks until the child exits or the slice's deadline passes.
   Between slices, core checks the timeout, the stop marker, and the interrupt flag the
   binary passed in, so core itself never sleeps. Stdout is captured whole. Stderr keeps
   only its last 64 KiB.
   - At the deadline, the runner sends `SIGTERM` to the group, waits 10 seconds, then
     sends `SIGKILL` (`nix::sys::signal::killpg`). The run is `timed_out`.
   - `agent-cron stop <job>` creates `locks/<job-id>.stop`, then sends `SIGTERM` to the
     `pgid` in the running record. When the runner sees the marker, it records
     `stopped` and removes the marker.
   - In a manual run, Ctrl-C sets a flag (`signal_hook::flag::register`, safe). The
     runner then stops the group the same way. claude is in its own process group, so
     the terminal's `SIGINT` never reaches it directly.
6. **Record.**
   - Exit 0 is `succeeded`, and a non-zero exit is `failed` with reason
     `exit_nonzero`.
   - From claude's JSON output the runner takes `result` and `total_cost_usd`. When
     the output is not JSON, `result` is the captured text.
   - The record is finished, and the history is pruned.
7. **Notify, then record the notification.** The binary builds the message (§3 of this
   page) and sends it through `Notifier`. It then writes `notification.status` into
   the record: `sent`, `failed`, `not_configured`, `suppressed`, or `not_sent`.

`interrupted` joins the `failed` reasons in `cli.md` §6. It covers a runner that died
before it could finish its record.

## 7. Notifications

- **Discord only, behind one interface.**
  - Routing takes the job's `notify` and the global settings, and yields a list of
    `(target, webhook name)` pairs. Routing is core's.
  - Sending is the `Notifier` port. Discord's adapter posts `{"content": …}` to the
    stored URL with `ureq`.
  - A new target, Slack first, adds three things: a value in `--notify` and
    `notify.targets`, a `service` value in `webhooks.json`, and an adapter. Nothing
    existing changes meaning.
- **Budget.** Discord limits a message's `content` to 2000 characters
  (<https://docs.discord.com/developers/resources/message>, checked 2026-10-11). The
  budget for the result is 2000 minus the rendered header and footer.
- **Validation.** A webhook URL must be HTTPS on `discord.com` or `discordapp.com`,
  with a path under `/api/webhooks/`. The Discord documentation gives the route as
  `POST /webhooks/{webhook.id}/{webhook.token}`
  (<https://docs.discord.com/developers/resources/webhook>, checked 2026-10-11). The
  accepted hosts are this design's choice.
- **Failure.** There is one attempt, with a 10-second timeout and no retry (§3.5).
  - An HTTP 429, any other non-2xx status, or a transport error becomes the record's
    `notification.status: failed` with a kind.
  - The URL never appears in the record, a log, or an error.
- **Unverified until a human sends one.** Whether a fenced code block in `content`
  renders as a copyable block. The first `agent-cron webhook test` against a real
  channel settles it.

## 8. Dependencies

Each new crate needs the owner's sign-off and a review record in the pull request that
adds it (`managing-dependencies`). The owner asked for established crates over
hand-written OS code, and approved each crate below, with its placement and features,
on 2026-10-11.

| Crate | Version (checked 2026-10-11) | Licence | MSRV | Goes in | Features | Why |
|---|---|---|---|---|---|---|
| `jiff` | 0.2.38 | Unlicense OR MIT | 1.70 | core (`std`); platform (`std`, `tz-system`) | default off | Zoned time with explicit DST handling. Core never reads the clock or the zone database |
| `nix` | 0.31.3 | MIT | 1.69 | platform | default off; `signal`, `user` | `killpg`, and the user record's shell and home, without `unsafe` in our code |
| `uuid` | 1.28.0 | Apache-2.0 OR MIT | 1.89 | platform | default off; `v4` | the session ID and `JobId` (through `getrandom` 0.4, which uses `getentropy(2)` on macOS) |
| `signal-hook` | 0.4.x, a release at least 7 days old when added (0.4.5 came out 2026-10-04) | MIT OR Apache-2.0 | 1.66 | binary | default | Ctrl-C during `agent-cron run`, through the safe `flag::register` |
| `dialoguer` | 0.12.0 | MIT | 1.66 | binary | defaults (`editor`, `password`): the prompt editor and the hidden prompt in `webhook set` | interactive prompts on stderr. It looks for an editor in `$VISUAL`, then `$EDITOR`, then `vi` |

Dependencies already in the workspace change like this:

- `ureq` becomes non-optional in platform, for Discord.
- `serde_json` is added to the binary, for `--json`.
- `dotenvy` is removed, because webhook URLs no longer come from an env-format file.
- `ratatui` and the OpenRouter feature are removed with the TUI and the sample.

Core's `clippy.toml` gains jiff's clock and database reads: `jiff::Timestamp::now`,
`jiff::Zoned::now`, `jiff::tz::TimeZone::system`, `jiff::tz::TimeZone::try_system`,
`jiff::tz::TimeZone::get`, `jiff::tz::db`, and `jiff::tz::TimeZoneDatabase::from_env`.
This keeps the rule that time reaches core only as a value. Raising a ban is a
strengthening, so it is not a sign-off item. Core takes `std` rather than only `alloc`
so that every banned path exists in every build that clippy checks. Without it,
`cargo xtask clippy-guard` would fail with `ERR_CLIPPY_BAN_UNRESOLVED`.

Unchecked: whether `tz-system` alone loads the macOS system zone, or whether it also
needs `tzdb-zoneinfo` to resolve the `/etc/localtime` symlink. The platform test for
`system_time_zone` settles it.

Sources:

- crates.io API pages `https://crates.io/api/v1/crates/<name>`;
- the crates' `Cargo.toml` at the release tag;
- <https://docs.rs/jiff/0.2.38/jiff/tz/struct.TimeZone.html>;
- <https://github.com/nix-rust/nix/blob/v0.31.3/src/unistd.rs>, for `User::shell`;
- <https://github.com/vorner/signal-hook/blob/master/src/flag.rs>.

All were checked 2026-10-11. The RustSec database has no advisory for any of these
crates at these versions (<https://rustsec.org/>, checked 2026-10-11). The one nix
advisory, RUSTSEC-2021-0119, was fixed in nix 0.23.

## 9. Quality targets

| Target | How it is shown |
|---|---|
| Every §3.2 rule holds: late skip, several missed times, running skip, DST gap and fold, first tick, clock moved back | table tests of `due()` and of the schedule module, with a fixed clock and POSIX TZ zones (`just test-core`) |
| The cron parser accepts what `cli.md` §5.2 shows and rejects malformed fields with `invalid_schedule` | table tests in core |
| A tick with 100 jobs finishes in under 100 ms on an Apple Silicon Mac | a platform test that times `tick` against 100 job files in a temporary directory (`just test-platform`) |
| No run is left `running` after its runner dies | a platform test that kills a runner and reads its record back as `interrupted` |
| No webhook URL in history, logs, errors, or `--json` | a CLI test that sets a known URL and searches every output and file for it |
| Every file format reads its previous version | a test per format that reads a checked-in sample |
| The LaunchAgent loads and fires every minute | a human-run `just test-local` test, plus `just logs` showing tick lines |

### Test seams

No test reaches the real claude, launchd, or Discord.

- **claude.** A CLI test sets `SHELL` to a fake shell script in its temporary directory.
  The script ignores `-l -c …` and runs a fake `claude`, which prints canned JSON, sleeps,
  or exits with a chosen code. The platform tests construct `ShellProcessHost` with the
  shell and program paths directly.
- **launchd.** A scratch `HOME` never reaches `launchctl`. The `LaunchAgent` adapter
  calls `launchctl` only when `HOME` is the user record's home directory. Otherwise it
  writes the plist under the scratch `HOME`, loads nothing, and reports the agent as
  "not loaded (scratch HOME)". This protects a person's own scratch-`HOME` runs as well
  as the tests. The one test that loads a real agent is the human-run `#[ignore]`d one,
  with a test-only label and a temporary plist.
- **Discord.** A debug build reads `AGENT_CRON_TEST_DISCORD_ORIGIN`, a local
  `http://127.0.0.1:<port>` that replaces the scheme and host of a stored Discord URL, so
  a CLI test posts to a local fixture. A release build never reads it, because the code
  is behind `cfg(debug_assertions)`. It is a test seam, not configuration: the installed
  tool is built in release mode and has no such variable.

## 10. Open questions

Each one is settled by a human-run check on a real Mac. None of them blocks starting
the build.

- **Privacy prompts.** Does a run started from the LaunchAgent prompt for, or get
  denied, access to `~/Documents`, `~/Desktop`, `~/Downloads`, or iCloud Drive? Which
  binary is the "responsible process" there? Apple's staff say the algorithm "is
  complex and evolves over time"
  (<https://developer.apple.com/forums/thread/751802>, checked 2026-10-11). Any grant
  this would need is an OS privacy permission, a design change under `AGENTS.md`.
- **Background Items.** Does installing the plist show "Background Items Added"? Does
  switching the item off in System Settings › Login Items & Extensions appear in
  `launchctl print-disabled`?
- **Environment.** Does launchd give the agent `HOME`? The runner falls back to the
  user record, so this only affects logging paths before that lookup.
- **Non-POSIX shells.** A login shell that is not POSIX-like, such as fish, may not
  accept `-l -c '…' name args`. `doctor` should warn about it once there is a report.
- **Sleep.** Does `caffeinate -i` hold off sleep when the lid closes? §3.2 does not ask
  for that.
