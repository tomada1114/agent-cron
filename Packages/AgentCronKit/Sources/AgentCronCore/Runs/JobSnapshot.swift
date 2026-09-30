import Foundation

/// What a run was asked to do: the saved job's prompt and options at the moment it
/// started.
///
/// A run uses the last saved job and keeps this copy (docs/architecture.md › Principles),
/// so history still says what ran after the job is edited or deleted.
public struct JobSnapshot: Sendable, Equatable, Codable {
    /// The agent CLI that ran.
    public let agent: AgentKind
    /// The working directory it ran in.
    public let directory: URL
    /// The prompt it was given.
    public let prompt: String
    /// The model it was asked for.
    public let model: ModelChoice
    /// The effort it was asked for.
    public let effort: EffortChoice
    /// What it was allowed to do without asking.
    public let permissionMode: PermissionMode
    /// How long it was allowed to take, in minutes.
    public let timeoutMinutes: Int
    /// Which outcomes post a notification for this run.
    public let notify: NotifyPolicy

    /// Copies what a run needs from `job` as it is now.
    public init(of job: Job) {
        agent = job.agent
        directory = job.directory
        prompt = job.prompt
        model = job.model
        effort = job.effort
        permissionMode = job.permissionMode
        timeoutMinutes = job.timeoutMinutes
        notify = job.notify
    }
}
