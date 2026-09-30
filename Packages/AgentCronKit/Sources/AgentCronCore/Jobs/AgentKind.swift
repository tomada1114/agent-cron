/// Which coding-agent CLI a job runs.
///
/// Stored on every job from the first release so a later agent (Codex CLI) is an added
/// case, not a migration of saved jobs (ADR-0004). Only the per-agent command builder
/// knows what a kind means on the command line. The raw value is what `jobs.json` and
/// each run file store, so changing it is a file-format change.
public enum AgentKind: String, Sendable, Codable, CaseIterable {
    /// Claude Code, run headless as `claude -p`.
    case claudeCode = "claude_code"
}
