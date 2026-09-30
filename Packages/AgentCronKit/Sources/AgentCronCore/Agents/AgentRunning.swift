import Foundation

/// A port: "run this command line in this directory for at most this long, and tell me
/// how it ended" (ADR-0004, requirements §3.3).
///
/// Core declares it, `AgentCronPlatform`'s `ProcessAgentRunner` answers it by launching
/// `/bin/zsh -l -c 'exec "$@"' agentcron <argv…>` — the user's login shell, so the agent
/// sees the PATH and tools Terminal sees — tests substitute `FakeAgentRunner`, and `App/`,
/// the composition root, decides which one the dispatcher gets. The port knows no agent:
/// `argv` is a complete command line a per-agent builder produced (`claude -p …` today).
/// Whether and when to run, and what an outcome means for the run's record, are Core's
/// decisions, made where the coverage floor sees them.
///
/// It is one-shot — one answer when the process has ended, no stream — because only the
/// final result is kept (`AGENTS.md` › Product). Stop is task cancellation: cancelling the
/// task that awaits ``run(argv:directory:timeout:)`` is how a caller stops a run, so the
/// port needs no handle and no second method.
///
/// The promises every implementation keeps — `AgentRunningContract` in
/// `AgentCronTestSupport` checks them against the fake (`just test`) and the real adapter
/// (`just test-local`); a new clause is stated here first, then added there:
///
/// 1. A process that exits on its own before `timeout` answers
///    ``ProcessOutcome/Termination/exit`` with its exit status, every byte it wrote to
///    stdout, and what it wrote to stderr. It runs with `directory` as its working
///    directory.
/// 2. Each element of `argv` reaches the process as exactly one argument, unchanged:
///    spaces, quotes, `$`, and `*` in it are never re-parsed by a shell.
/// 3. A process still running when `timeout` passes is terminated — SIGTERM, then
///    SIGKILL if it is still alive 10 seconds later — and the run answers
///    ``ProcessOutcome/Termination/timeout`` with a non-zero status.
/// 4. Cancelling the task that awaits the run terminates the process the same way, and
///    the run answers ``ProcessOutcome/Termination/stopped`` with a non-zero status.
/// 5. A process that cannot be started — `directory` does not exist — answers
///    ``ProcessOutcome/Termination/exit`` with ``ProcessOutcome/notLaunchedExitCode`` and
///    the reason on stderr, rather than throwing or trapping.
///
/// A run never throws, and it answers only once the process has ended, so a caller that
/// has its answer has nothing left running on its behalf.
public protocol AgentRunning: Sendable {
    /// Runs `argv` — non-empty, its first element the program, found on the login shell's
    /// PATH or given as a path — in `directory`, terminating it once `timeout` passes.
    func run(argv: [String], directory: URL, timeout: Duration) async -> ProcessOutcome
}
