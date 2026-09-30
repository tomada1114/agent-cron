# ADR-0002: Turn the App Sandbox off

- **Status:** Accepted 2026-09-30
- **Date:** 2026-09-29
- **Deciders:** the owner

## Context

The template ships `App/AgentCron.entitlements` with `com.apple.security.app-sandbox`
on. AgentCron's whole job is to launch the user's `claude` CLI through their login
shell (ADR-0004) in any repository they pick, and that CLI reads and writes files in
the repository, runs `git` and `gh`, reads `~/.claude`, and reaches the network.

## Decision drivers

- The core interaction: a scheduled run must produce the same result as running the
  same prompt by hand with `claude -p` (`AGENTS.md` › Product).
- `AGENTS.md` › Security and human approval: an entitlement change needs the owner's
  sign-off.

## Considered options

1. **Sandbox off** — remove `com.apple.security.app-sandbox`; keep Hardened Runtime.
2. **Sandbox on with security-scoped bookmarks** — the app can reach picked folders,
   but a process it launches does not run as the user's terminal would: Apple documents
   that a helper launched from a sandboxed app runs in the parent's sandbox only when
   signed with `com.apple.security.app-sandbox` + `com.apple.security.inherit`, which
   the user's own `claude` install is not; either way the run could not be the
   unconfined `claude -p` the success criterion compares against.
3. **Sandbox on with an XPC helper outside it** — a second target and a privileged
   design for a single-user local tool.

## Decision

Option 1. The capability that forces it: launching an arbitrary user CLI in
an arbitrary directory with the user's environment. Hardened Runtime stays on. The app
can never ship on the Mac App Store, which the Product non-goals already exclude.

## Consequences

### Positive

- Runs behave like the user's terminal, which is the success criterion.

### Negative

- No sandbox containment for the app itself; its own file access is limited by code
  review, not the OS.

### Follow-ups

- Remove the sandbox entitlement (issue, needs the owner's sign-off on the PR per
  `AGENTS.md`).

## Open questions

- Unverified: exactly what happens when a sandboxed app launches a binary not signed
  for sandbox inheritance (refused, or confined). It does not change the decision —
  neither outcome gives terminal parity.

## Sources

- <https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app> — a helper tool must be signed with exactly `com.apple.security.app-sandbox` and `com.apple.security.inherit` to run inside the parent's sandbox — checked 2026-09-29
- `docs/distribution.md` › Sandboxed or not (in-repo)

## Related

- [ADR-0004](0004-agent-runner-port-and-claude-code-invocation.md) — the child process
  that forces this.
