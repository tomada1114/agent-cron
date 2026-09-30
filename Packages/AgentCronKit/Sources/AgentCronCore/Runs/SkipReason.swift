import Foundation

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

    /// Why the run was skipped, as the History detail shows it in place of a result
    /// (`docs/product/ux-flows.md` S3).
    public var title: LocalizedStringResource {
        switch self {
        case .agentNotFound:
            LocalizedStringResource(
                "history.skipReason.agentNotFound",
                defaultValue: "Agent not found",
                bundle: .module,
                comment: "History detail: a run was skipped because the agent's command was not found.",
            )

        case .directoryMissing:
            LocalizedStringResource(
                "history.skipReason.directoryMissing",
                defaultValue: "Folder missing",
                bundle: .module,
                comment: "History detail: a run was skipped because the job's folder no longer exists.",
            )

        case .missed:
            LocalizedStringResource(
                "history.skipReason.missed",
                defaultValue: "Missed beyond 60 min",
                bundle: .module,
                comment: "History detail: a run was skipped because its time passed too long ago to catch up.",
            )

        case .stillRunning:
            LocalizedStringResource(
                "history.skipReason.stillRunning",
                defaultValue: "Still running",
                bundle: .module,
                comment: "History detail: a run was skipped because the job was still running from an earlier time.",
            )
        }
    }
}
