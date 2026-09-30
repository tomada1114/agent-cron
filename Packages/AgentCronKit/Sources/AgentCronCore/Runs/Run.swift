import Foundation

/// One invocation of a job — or one scheduled time that was skipped — as history records
/// it (requirements §3.4).
///
/// Only the final result and run metadata are kept, never the stream of tool calls (a
/// Product non-goal). A run starts ``RunOutcome/running`` and the runner fills in the
/// rest when it ends.
public struct Run: Sendable, Equatable, Codable, Identifiable {
    /// This run's own identity.
    public let id: UUID
    /// The job it ran, which may since have been deleted.
    public let jobID: UUID
    /// The job's name when the run started, kept so history reads after a rename or a
    /// delete.
    public let jobName: String
    /// The prompt and options the run used.
    public let snapshot: JobSnapshot
    /// What started it.
    public let trigger: RunTrigger
    /// The scheduled time it was for; `nil` for a manual run.
    public let scheduledAt: Date?
    /// When it started, or when a skip was recorded.
    public let startedAt: Date
    /// When it ended; `nil` while it runs.
    public var endedAt: Date?
    /// Where it ended up.
    public var outcome: RunOutcome
    /// Why it was skipped; set only when ``outcome`` is ``RunOutcome/skipped``.
    public var skipReason: SkipReason?
    /// What went wrong, for a run that failed: the agent's error subtype and output, or
    /// why it could not start.
    public var failureReason: String?
    /// The agent process's exit status, once it has exited.
    public var exitCode: Int32?
    /// What the agent reported the run cost, in US dollars, when it reported one.
    public var costUSD: Decimal?
    /// The agent's session identifier, when it reported one.
    public var sessionID: String?
    /// The agent's final result text.
    public var resultText: String?

    /// Starts a run of `job` as it is saved now: ``outcome`` is
    /// ``RunOutcome/running`` and every result field is empty.
    /// - Parameter scheduledAt: The scheduled time the run is for; `nil` for a manual run.
    public init(
        job: Job,
        trigger: RunTrigger,
        startedAt: Date,
        scheduledAt: Date? = nil,
        id: UUID = UUID(),
    ) {
        self.id = id
        jobID = job.id
        jobName = job.name
        snapshot = JobSnapshot(of: job)
        self.trigger = trigger
        self.scheduledAt = scheduledAt
        self.startedAt = startedAt
        outcome = .running
    }
}
