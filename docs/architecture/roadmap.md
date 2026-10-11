# Roadmap

This page records the app's direction: the outcomes it is working toward now, the ones
that come next, and the ones only intended for later. It sits between two other homes
and repeats neither:

- `AGENTS.md`'s `## Product` says what the app is, its core interaction, and its
  non-goals. Nothing here contradicts a non-goal; moving one is the owner's call, made
  in that section first.
- The issue tracker holds the units of work, their priority labels, and their `blocked:`
  and `on hold` labels (`triaging-issues`). This page links issues and never copies
  their bodies.

It records direction and authorizes nothing. An issue is implemented because it is
filed, prioritized, and picked, never because a line here names it. Nor does it record
the design: a design change a line depends on is described in `AGENTS.md`,
`docs/architecture.md`, and the skill that owns the subject once it lands, and named
here only until then. What has shipped is in
`CHANGELOG.md`, not on this page.

The owner decides what the page says; an agent proposes a change to it in a pull
request, and the change lands only once the owner has approved it.

- **Last reviewed:** 2026-10-11

## Now

The outcomes being worked on, one to three of them. Each has its issues filed.

- **The codebase is agent-cron, not the template's sample** — every later change builds
  on it, and the sample's counter, TUI, and OpenRouter layer and the Linux paths would
  otherwise be carried and tested for nothing. Issues: tracked in #3 (#6, #7, #12).
  Done when: `agent-cron --help` lists none of `counter`, `tui`, or `llm`, the
  workspace has no `ratatui` or `dotenvy` dependency, `just check` passes on macOS, and
  no CI job builds or tests the tool on Linux.
- **A job made in a repository runs on time, and its Discord message resumes it** —
  this is the core interaction in `AGENTS.md` › Product. Issues: tracked in #4 (#8–#11,
  #13–#17, #21–#26). Done when, on the owner's Mac: `agent-cron add` asked inside a
  repository creates a job; at its scheduled time the tick runs it; Discord receives the
  result with `cd '<dir>' && claude -r <id>`, and pasting that resumes the session; a
  failing job is notified as failed; and a time missed during sleep shows in
  `agent-cron history <job>` as `skipped (late)` and is not run.
- **Claude Code can drive every operation with flags and `--json`** — the same command
  line has to serve programs before a Raycast extension can exist. Issues: tracked in
  #5 (#18, #19, #20). Done when: `add`, `edit`, `enable`, `disable`, `rm --yes`, `run`,
  `stop`, `list`, `show`, and `history` run with no terminal and no question, each
  `--json` output matches `docs/product/cli.md` §6, and
  `crates/agent-cron/tests/cli.rs` asserts those shapes.

## Next

The outcomes that follow once Now's are done. An issue may already exist for one, often
parked as `on hold`; none is required.

- **Slack notifications** — the first target after Discord, and the reason the notifier
  sits behind one interface. Before it moves up: the Discord outcome in Now lands, and
  the owner wants a second channel in daily use.
- **A Raycast extension can browse and edit jobs** — it lives in a separate repository
  and reads this tool's `--json`. Before it moves up: the `--json` outcome in Now lands,
  and the JSON shapes have held through daily use.

## Later

Direction the app intends to take but has not ordered. No issue is filed for a line
here, apart from a parked one that a line names.

- **Install without building from source (a Homebrew tap and prebuilt binaries)** —
  when open-source users grow and building from source becomes the barrier; a release
  pipeline is a sign-off change.
- **More notification targets: macOS Notification Center and a generic JSON webhook** —
  when a user asks for one.
- **A full-screen TUI for the list and history** — when prompts and flags stop being
  enough.
- **Finding and importing `claude -p` entries set up by hand in crontab or
  LaunchAgents** — when someone moving to the tool needs it.
- **Duplicating jobs, and exporting and importing them** — when jobs are moved between
  folders or Macs often enough to ask for it.
