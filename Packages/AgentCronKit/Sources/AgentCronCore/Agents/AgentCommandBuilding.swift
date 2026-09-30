/// One agent CLI's vocabulary: the command line a ``RunRequest`` becomes, and how that
/// CLI's output reads back as a ``RunResult`` (ADR-0004).
///
/// The only place an agent's flags and output format are known — `ClaudeCodeCommand`
/// today. A caller never names a conforming type: it asks the run's ``AgentKind`` for its
/// ``AgentKind/commandBuilder``, so a second agent (Codex CLI) adds a kind and a builder
/// and no caller changes. Both halves are pure, so they are tested directly, without a
/// fake of ``AgentRunning``.
public protocol AgentCommandBuilding: Sendable {
    /// The agent this builder speaks for.
    var agent: AgentKind { get }

    /// The complete command line for `request`, program first, ready for
    /// ``AgentRunning/run(argv:directory:timeout:)`` — no shell quoting, since the runner
    /// passes each element as one argument.
    func arguments(for request: RunRequest) -> [String]

    /// What `outcome`'s output says about the run. Never throws: output the builder
    /// cannot read is itself a failed result, with the raw output kept.
    func result(of outcome: ProcessOutcome) -> RunResult
}
