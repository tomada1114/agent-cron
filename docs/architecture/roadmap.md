# Roadmap

This page records the app's direction: the outcomes it is working toward now, the ones
that come next, and the ones only intended for later. It sits between two other homes
and repeats neither:

- `AGENTS.md`'s `## Product` says what the app is, its core interaction, and its
  non-goals. Nothing here contradicts a non-goal; moving one is the owner's call, made
  in that section first.
- The issue tracker holds the units of work, their priority tiers, and their `blocked:`
  and `on hold` labels (`triaging-issues`). This page links issues by number and never
  copies their bodies.

It records direction and authorizes nothing. An issue is implemented because it is
filed, tiered, and picked, never because a line here names it. It is not an ADR either:
it takes no status and no number, and a decision a line depends on is recorded as an
ADR ([the index](README.md)) and linked from here. What has shipped is in
`CHANGELOG.md`, not on this page.

The owner decides what the page says; an agent proposes a change to it in a pull
request, and the change lands only once the owner has approved it.

- **Last reviewed:** 2026-09-30

## Now

The outcomes being worked on, one to three of them. Each has its issues filed.

- **A saved job runs on schedule and leaves a record** — the core interaction in
  `AGENTS.md` › Product; nothing else matters until a scheduled `claude -p` run happens
  and its result can be read afterwards. Issues: (filled when the backlog is created).
  Done when: a job saved in the main window fires at its next weekday time under
  `just run`, its run appears in History with the result text, and a hand-run
  `claude -p` in the same directory produces the same outcome.
- **The menu bar tells you what runs next and what went wrong** — the glance half of the
  core interaction. Issues: (filled when the backlog is created). Done when: the popover
  shows today's timeline with outcomes, a running job can be stopped from it, and a
  failed run raises the banner and (per job) a notification.
- **The Mac stays awake for runs and on demand** — runs die if the Mac idles to sleep.
  Issues: (filled when the backlog is created). Done when: `pmset -g assertions` shows
  AgentCron's assertion exactly while a job runs or a manual hold is active.

## Next

The outcomes that follow once Now's are done. An issue may already exist for one, often
parked as `on hold`; none is required.

- **Codex CLI as a second agent** — the job model already stores an agent kind
  (ADR-0004). Before it moves up: the owner moves it out of Product's Later list and a
  `CodexCommand` builder is designed (`codex exec` flags differ).
- **Job duplication** — cheap once the editor exists. Before it moves up: the owner asks
  for it after daily use.

## Later

Direction the app intends to take but has not ordered. No issue is filed for a line
here, apart from a parked one that a line names.

- **Lid-closed sleep prevention** (LidAwake's `pmset` helper) — brought forward if
  idle-sleep prevention proves insufficient for real jobs.
- **Job chaining and export/import** — brought forward when the owner has several jobs
  that depend on each other or a second Mac.
- **Developer ID distribution** — brought forward when a second person installs the app
  (ADR-0011).
