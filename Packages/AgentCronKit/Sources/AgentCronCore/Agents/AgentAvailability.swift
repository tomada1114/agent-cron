/// Whether an agent's CLI can be run from the user's login shell: what the General
/// screen shows and what the dispatcher's pre-flight skips a run on (requirements §3.7,
/// ADR-0004). ``AgentAvailabilityChecker`` produces it.
public enum AgentAvailability: Sendable, Equatable {
    /// The CLI resolved to `path`, and `--version` answered `version` (empty when it
    /// printed nothing).
    case available(path: String, version: String)
    /// The check itself could not finish — a timeout, a failed `--version`, a shell that
    /// would not start. `reason` is short, fixed text that names no user path.
    case error(String)
    /// The login shell does not find the CLI — a run would be skipped as
    /// ``SkipReason/agentNotFound``.
    case notFound
}
