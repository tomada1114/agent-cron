/// Where a run ended up — or that it has not ended yet.
///
/// The raw value is what a run file stores, so changing it is a file-format change.
public enum RunOutcome: String, Sendable, Codable, CaseIterable {
    /// The agent finished and reported an error, or could not be started.
    case failed
    /// The agent is still running; the only outcome a run can leave.
    case running
    /// The run never started; ``Run/skipReason`` says why.
    case skipped
    /// The user stopped the agent.
    case stopped
    /// The agent finished and reported success.
    case succeeded
    /// The agent was stopped because the job's timeout passed.
    case timedOut = "timed_out"
}
