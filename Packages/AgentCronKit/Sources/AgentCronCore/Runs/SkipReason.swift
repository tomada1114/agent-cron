/// Why a scheduled time did not produce a run.
///
/// The raw value is what a run file stores, so changing it is a file-format change.
public enum SkipReason: String, Sendable, Codable, CaseIterable {
    /// The agent's command could not be found in the login shell.
    case agentNotFound = "agent_not_found"
    /// The job's directory no longer exists.
    case directoryMissing = "directory_missing"
    /// The time passed while the Mac slept or the app was not running, and it was too
    /// long ago to catch up, or another missed time was caught up instead.
    case missed
    /// The job was still running from an earlier time.
    case stillRunning = "still_running"
}
