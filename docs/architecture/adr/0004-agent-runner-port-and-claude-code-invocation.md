# ADR-0004: An agent-runner port, with Claude Code as its first adapter

- **Status:** Accepted 2026-09-29: the Claude Code invocation (login shell, flags,
  per-job options, timeout). Accepted 2026-09-30: the port's shape.
- **Date:** 2026-09-29
- **Deciders:** the owner

## Context

A run launches a coding-agent CLI headless in the job's directory. Today that is
Claude Code (`claude -p`); the Product section names Codex CLI (`codex exec`) as a later
agent, so nothing outside one adapter may assume Claude Code. The owner chose the
per-job options (model, effort, permission mode, timeout) and launching through the
login shell.

## Decision drivers

- Parity with a hand-run `claude -p` in the same directory (`AGENTS.md` › Product).
- Adding Codex CLI later without migrating stored jobs or touching the scheduler.
- Result text, cost, session id, and exit status recorded per run (requirements §3.4).

## Considered options

1. **A Core `AgentRunning` port + an agent-kind field on every job** — Core builds an
   agent-neutral `RunRequest`; a per-agent `AgentCommandBuilding` in Core turns it into
   argv; one Platform adapter launches processes.
2. **Call `claude` directly from the dispatcher** — fastest now, rewrite for Codex.

## Decision

Option 1.

- `Job.agent: AgentKind` (`claudeCode` only in MVP) is stored from day one.
- **Core — `ClaudeCodeCommand`** builds argv:
  `claude -p <prompt> --output-format json --permission-mode <mode>` plus `--model
  <alias>` and `--effort <level>` only when the job sets them (default: flag omitted, so
  Claude Code's own settings apply). Permission modes offered: `auto` (default),
  `acceptEdits`, `dontAsk`, `plan`, `default`, `bypassPermissions` (with the warning in
  `ux-flows.md` S6). Effort levels offered: `low`, `medium`, `high`, `xhigh`, `max`,
  filtered to the levels the chosen model supports; `ultracode` is not offered (it turns
  on a multi-agent workflow, not a plain effort level).
- **Core — `ClaudeCodeResultParser`** decodes the JSON result object into
  `RunResult` from the documented fields `subtype`, `is_error`, `result`,
  `total_cost_usd`, `session_id`, `duration_ms`, `num_turns`. Error subtypes
  (`error_max_turns`, `error_during_execution`, …) may carry no `result`; the subtype
  and stderr become the failure text. A non-JSON stdout is kept verbatim with outcome
  failed.
- **Platform — `ProcessAgentRunner`** (behind `AgentRunning`) launches `/bin/zsh -l -c
  'exec "$@"' agentcron <argv…>` with the job directory as the working directory, so
  argv is never re-parsed by the shell; captures stdout/stderr; on timeout or Stop sends
  SIGTERM, then SIGKILL after 10 s; reports exit code and signal.
- **Pre-flight in Core**: directory exists; the agent resolves in the login shell
  (`command -v claude`, also used by General's agent check) — failures recorded as
  `failed` with the reason, never thrown past the dispatcher.
- Codex CLI later adds `AgentKind.codexCLI` and a `CodexCommand` builder (`codex exec`
  with `-m`, `-s/--sandbox`, `-c model_reasoning_effort=…`, `--json`); the runner and
  scheduler do not change. Its permission vocabulary differs (sandbox modes, no
  `--ask-for-approval` in `exec`), so the per-agent option set lives with the builder.

## Consequences

### Positive

- Parity by construction: the same binary, same environment, same flags a user types.
- Codex CLI is an additive change.

### Negative

- `zsh -l` reads `.zprofile` but not `.zshrc`; a PATH set only in `.zshrc` will not
  apply (requirements § Open questions). The parity check settles it.
- The JSON result shape is the CLI's, not ours; a CLI update can change it. The parser
  keeps the raw stdout on any decode failure.

### Follow-ups

- Command builder + result parser in Core; process runner adapter with timeout and
  stop; agent check; a parity run of `claude -p` by hand vs. AgentCron (issues).
- Verify with a real run whether `auto` lets a Dependabot job run `gh pr merge`
  unattended (requirements § Open questions).

## Open questions

- The port's exact shape (streaming vs. one-shot result) — one-shot is enough for MVP;
  revisit if live output is ever wanted (a Product non-goal today).

## Sources

- <https://code.claude.com/docs/en/cli-reference> — `-p/--print`; `--model` aliases `sonnet`, `opus`, `haiku`, `fable` or a full name; `--effort` `low|medium|high|xhigh|max|ultracode` (model-dependent); `--permission-mode` `default|acceptEdits|plan|auto|dontAsk|bypassPermissions` (`manual` aliases `default`); `--output-format text|json|stream-json` — checked 2026-09-29
- <https://code.claude.com/docs/en/headless> — the JSON result object and its fields (`type`, `subtype`, `session_id`, `duration_ms`, `is_error`, `num_turns`, `result`, `total_cost_usd`, …) and error subtypes — checked 2026-09-29
- <https://learn.chatgpt.com/docs/non-interactive-mode> and <https://learn.chatgpt.com/docs/cli/reference> — `codex exec`, `-m`, `-s/--sandbox` (`exec` defaults to read-only), `--json`, `-c key=value`; no `--ask-for-approval` in `exec` — checked 2026-09-29
- <https://learn.chatgpt.com/docs/config-file/config-reference> — `model_reasoning_effort` — checked 2026-09-29

## Related

- [ADR-0002](0002-app-sandbox-off.md) — the child process needs it.
- [ADR-0003](0003-in-app-scheduler.md) — the dispatcher that calls the runner.
