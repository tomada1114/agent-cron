# AgentCron — UX flows and wireframes

- **Source:** `docs/product/requirements.md` (signed off 2026-09-29); app-wide policy (navigation
  rules, state handling, validation timing, motion, accessibility targets) lives in
  `docs/design/ux-guidelines.md` and is cited, not restated.
- **Platform:** macOS menu-bar agent (`LSUIElement`, `MenuBarExtra` window style) with one
  main window. No Dock icon while only the status item is up; while the main window is
  open the app becomes a regular app (Dock icon, main menu) — ADR-0001.

## 1. Screen inventory

| # | Screen | Kind | Serves |
|---|---|---|---|
| S1 | Status item + popover | `MenuBarExtra` `.window`, 340pt wide | §3.2, §3.3, §3.6, §3.7 |
| S2 | Main window — Jobs (list + detail) | window, sidebar section 1 | §3.1, §3.2, §3.3 |
| S3 | Main window — History (list + run detail) | window, sidebar section 2 | §3.4 |
| S4 | Main window — General | window, sidebar section 3 | §3.6, §3.7 |
| S5 | Delete job confirmation | alert on S2 | §3.1 |
| S6 | Bypass-permissions warning | inline in S2 + confirmation alert | §3.1 |
| S7 | Notification | system notification | §3.5 |

## 2. Wireframes

### S1 Status item and popover

```
   ◷ ← status item: template SF Symbol, 18pt; variants below
 ┌────────────────────────────────────────────┐
 │ ⚠ 1 failed run since you last looked  [View]│ ← only when unseen failures exist
 │ ────────────────────────────────────────── │
 │ Today · Tue 29 Sep                         │
 │  09:00 ✓ RSS digest            2m   $0.12  │ ← click: opens S3 on that run
 │  12:00 ◌ Dependabot review   4:12   [■]    │ ← running: elapsed + Stop
 │  18:00 ○ RSS digest                        │ ← upcoming
 │  22:00 ○ Nightly review          ⚠bypass   │
 │ Tomorrow                                   │
 │  09:00 ○ RSS digest                        │ ← at least the next run is always shown
 │ ────────────────────────────────────────── │
 │ ☕ Keep awake    [ Off ▾ ]   (2:41 left)    │ ← Off / 1 hour / 4 hours / Until turned off
 │ ────────────────────────────────────────── │
 │ [＋ New Job]      Open AgentCron…  ⌘,       │
 │                   Quit             ⌘Q       │
 └────────────────────────────────────────────┘
 Width 340pt fixed, height fits content up to 520pt then the timeline scrolls.
 Closes on focus loss; Esc closes.
```

Timeline row outcome glyphs: ✓ succeeded · ✗ failed · ⏱ timed out · ■ stopped ·
⤼ skipped · ◌ running · ○ upcoming. Glyph and color treatment: stage 3.

Status item variants: idle ◷ · running (animated/filled variant) · keep-awake on (cup
badge) · unseen failure (dot badge). Exact symbols: stage 3.

States:
- **No jobs:** timeline area shows "No jobs yet" + [Create your first job] → S2 with a new
  draft job.
- **No runs today:** "Nothing scheduled today" + the next scheduled run ("Next: Thu 09:00
  RSS digest").
- **All jobs disabled:** "All jobs are paused" + [Open Jobs].
- **Agent not found:** banner "claude was not found in your login shell" + [Open General].

### S2 Main window — Jobs

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ ● ● ●                                        [＋]  [▶ Run Now] [⌕ Search    ] │ ← ⌘N / ⌘R
├──────────────┬──────────────────────┬────────────────────────────────────────┤
│ ▸ Jobs     3 │ ● RSS digest         │ RSS digest                 [ On ● ]    │
│   History    │   Weekdays 09:00 +2  │ Next: today 18:00 · Last: ✓ 09:00      │
│   General    │   Next 18:00   ✓     │ ── Task ──────────────────────────────  │
│              │ ● Dependabot review  │ Name       [RSS digest              ]  │
│              │   Every day 12:00    │ Directory  ~/ghq/…/news-digest [Choose…]│
│              │   Running 4:12  ◌    │ Prompt     ┌─────────────────────────┐ │
│              │ ○ Nightly review ⚠   │            │/rss-digest を実行して…   │ │
│              │   Paused             │            │                         │ │
│              │                      │            └─────────────────────────┘ │
│              │                      │ ── Schedule ──────────────────────────  │
│              │                      │ Days  [Mon][Tue][Wed][Thu][Fri][Sat][Sun]│
│              │                      │       Every day · Weekdays · Weekends  │
│              │                      │ Times 09:00 [−]  12:00 [−]  18:00 [−]  │
│              │                      │       [＋ Add time]                     │
│              │                      │ → Weekdays at 09:00, 12:00, 18:00      │
│              │                      │ ── Agent ─────────────────────────────  │
│              │                      │ Agent       Claude Code (only option)  │
│              │                      │ Model       [Default (Claude Code) ▾]  │
│              │                      │ Effort      [Default ▾]                │
│              │                      │ Permission  [auto ▾]                   │
│              │                      │ Timeout     [ 30 ] minutes             │
│              │                      │ ── Notifications ─────────────────────  │
│              │                      │ Notify      [Failures only ▾]          │
│              │                      │ ── Recent runs ───────────────────────  │
│              │                      │ ✓ Today 09:00   2m  $0.12              │
│              │                      │ ✗ Mon 18:00     timed out              │
│              │                      │ …up to 5            [Show all in History]│
│              │                      │ ───────────────────────────────────────│
│              │                      │                        [Delete Job…]   │
└──────────────┴──────────────────────┴────────────────────────────────────────┘
Sidebar 180pt · list min 240pt · detail min 420pt, flexible. Window min 860×560.
Shrinking: sidebar collapses first (⌃⌘S restores); list and detail never collapse.
```

- Sidebar sections: ⌘1 Jobs, ⌘2 History, ⌘3 General.
- List row: enabled dot, name, schedule summary, next run or running state, last outcome,
  ⚠ badge for `bypassPermissions`. Sorted by next run; paused jobs last.
- Header: enable toggle; "Run Now" (⌘R) turns into "Stop" (⌘.) while this job runs.
- Agent row is shown read-only with one value so the Codex CLI option has a place later.
- Effort choices show only the levels the selected model supports (source: Claude Code
  CLI reference); "Default" omits the flag.
- Save model (explicit Save vs apply immediately) and field validation: ux-guidelines.md.

States:
- **No jobs:** list empty state "No jobs yet — a job runs an agent prompt in a folder on
  a schedule" + [New Job ⌘N]; detail pane blank.
- **No selection:** detail shows "Select a job".
- **Directory missing:** Directory row shows an inline warning "This folder no longer
  exists" + [Choose…]; the job still saves but its runs fail with that reason.
- **Running:** header shows elapsed time; fields stay editable, changes apply from the
  next run (note under the header).

### S3 Main window — History

```
┌──────────────┬──────────────────────────────┬────────────────────────────────┐
│   Jobs     3 │ [All jobs ▾] [All outcomes ▾]│ RSS digest · Today 09:00       │
│ ▸ History    │ ─ Today ──────────────────── │ ✓ Succeeded · Scheduled        │
│   General    │ ✓ 09:00 RSS digest   2m $.12 │ Started 09:00:02 · 2m 14s      │
│              │ ◌ 12:00 Dependabot   4:12    │ Cost $0.12 · Exit 0            │
│              │ ─ Yesterday ──────────────── │ Directory ~/ghq/…/news-digest  │
│              │ ✗ 22:00 Nightly review       │ Model default · Effort default │
│              │ ⤼ 18:00 RSS digest (missed)  │ Permission auto · Session 3f2… │
│              │ ✓ 09:00 RSS digest   2m $.10 │ ── Result ──── [Raw] [Copy] ── │
│              │ …                            │ ## Today's digest              │
│              │                              │ - Swift 6.2 released …         │
│              │                              │ - …                            │
│              │                              │ (Markdown rendered, selectable)│
└──────────────┴──────────────────────────────┴────────────────────────────────┘
List min 280pt · detail min 420pt.
```

- Grouped by day, newest first. Filters: job (includes deleted jobs, labelled "(deleted)"),
  outcome (All / Failures / Succeeded / Skipped).
- Run detail fields: requirements §3.4. Failed runs show the error output in the Result
  section; skipped runs show the reason (missed beyond 60 min / still running / agent not
  found / folder missing) instead of a result.
- Prompt used by the run is shown collapsed under Result ("Prompt ▸") since the job may
  have been edited since.
- [Raw] toggles monospaced raw text; [Copy] copies the result.

States:
- **Empty:** "No runs yet — runs appear here after a job runs" + [Open Jobs].
- **Filter has no match:** "No runs match" + [Clear filters].
- **Running run selected:** detail shows elapsed time, Stop button, "Result appears when
  the run finishes".

### S4 Main window — General

```
┌──────────────┬────────────────────────────────────────────────────────┐
│   Jobs     3 │ ── Startup ──────────────────────────────────────────── │
│   History    │ Launch at login                 [ On ● ]               │
│ ▸ General    │ ── Agents ───────────────────────────────────────────── │
│              │ Claude Code   ✓ /Users/…/.local/bin/claude  v2.1.x     │
│              │                resolved via login shell   [Check Again]│
│              │ ── Keep awake ───────────────────────────────────────── │
│              │ Keep awake while jobs run       always on (info text)  │
│              │ ── History ──────────────────────────────────────────── │
│              │ Runs are kept for 90 days.                              │
└──────────────┴────────────────────────────────────────────────────────┘
```

- Agent not found: ✗ "claude was not found in your login shell (zsh -l)" with a short
  hint and [Check Again].
- Checking: inline spinner on the Claude Code row only.

### S5 Delete job confirmation

```
┌──────────────────────────────────────────────┐
│ Delete "RSS digest"?                          │
│ Its past runs stay in History for up to       │
│ 90 days.                                      │
│                       [Cancel]  [Delete]      │ ← Delete is destructive style
└──────────────────────────────────────────────┘
```
If the job is running: text adds "The running job will be stopped." Shortcut ⌘⌫ from the list.

### S6 Bypass-permissions warning

- Choosing `bypassPermissions` in the Permission menu opens a confirmation alert:
  "Run without any permission checks? The agent can run any command and change any file
  without asking, while nobody is watching." [Cancel] [Use Bypass].
- While set: a red inline note under the Permission row, and the ⚠ badge on the job in
  the list and the popover timeline.

### S7 Notification

```
AgentCron
✗ Nightly review failed · 22:00
Timed out after 30 minutes
```
Title = job name + outcome; body = first line of the reason or of the result. Click opens
S3 on that run. Sent per the job's Notify setting.

## 3. Flows

### F1 Create a job and try it

1. Popover [＋ New Job] or ⌘N in the main window → S2 with a new draft job selected.
2. Enter name, choose directory, type prompt, pick days and times.
3. Save (per ux-guidelines.md) → job appears in the list with its next run.
4. [▶ Run Now] → header shows running; popover timeline shows it.
5. Run ends → Recent runs row appears; notification per setting.

```
[Popover ＋] -> [S2 draft] -> [Fill fields] -> [Save] -> [Run Now] -> [Run done]
                                   |                          |
                                   v                          v
                     [Validation message inline]     [✗ Failed -> S3 detail
                      (ux-guidelines.md)               -> fix prompt/dir -> Run Now]
```

### F2 Scheduled run

```
[Time reached] -> [Same job running?] --yes--> [Record ⤼ skipped: still running]
                        | no
                        v
               [Keep-awake assertion held] -> [zsh -l -c claude -p …]
                        |
     +------------------+-------------------+------------------+
     v                  v                   v                  v
 [exit 0: ✓]     [exit ≠0: ✗]     [timeout: ⏱ terminate]   [pre-start: dir missing /
                                                            claude not found: ✗]
     \__________________\_________________/___________________/
                        v
       [Record run] -> [Release assertion if no job runs] -> [Notify per job]
```

### F3 Missed run catch-up

```
[Wake or app launch] -> [For each enabled job: missed times since last check?]
        | none -> [idle]
        v
[Latest missed time ≤ 60 min ago?] --yes--> [Run once (trigger: catch-up)]
        | no                                   older missed times -> [⤼ skipped: missed]
        v
[All missed times recorded ⤼ skipped: missed]
```

### F4 Check a failure

1. Notification "✗ Nightly review failed" (or popover banner "1 failed run") → click.
2. Main window opens on S3 with that run selected.
3. Read the error output → [Open Jobs] link in the detail header selects the job in S2.
4. Fix and [Run Now].

### F5 Keep the Mac awake manually

1. Popover → Keep awake [▾] → 1 hour / 4 hours / Until turned off.
2. Status item gains the cup badge; popover shows remaining time.
3. Timer ends or user selects Off → assertion released unless a job is running.

### F6 First launch

1. App launches → registers launch at login (on by default) → status item appears.
2. Agent check runs in the background.
3. Popover (on first click) shows the no-jobs state + [Create your first job]; if the
   agent check failed, the agent banner shows above it.

## 4. Menu commands (while the main window is key)

| Menu | Command | Shortcut |
|---|---|---|
| AgentCron | Settings… (opens General) | ⌘, |
| AgentCron | Quit AgentCron | ⌘Q |
| File | New Job | ⌘N |
| Job | Run Now | ⌘R |
| Job | Stop | ⌘. |
| Job | Enable / Disable | ⌘E |
| Job | Delete… | ⌘⌫ |
| View | Jobs / History / General | ⌘1 / ⌘2 / ⌘3 |
| View | Toggle Sidebar | ⌃⌘S |
| Window | Close | ⌘W |
