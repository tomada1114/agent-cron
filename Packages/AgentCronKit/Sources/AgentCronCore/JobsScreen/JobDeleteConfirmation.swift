import Foundation

/// The alert that asks before a job is deleted (`docs/product/ux-flows.md` S5).
///
/// Built from the saved job, not an editor's draft, so the alert names the job the list
/// shows even while a rename is unsaved.
public struct JobDeleteConfirmation: Sendable, Equatable {
    /// The job the alert would delete.
    public let jobID: UUID
    /// The saved name the alert quotes.
    public let jobName: String
    /// Whether the job is running, which deleting it would stop.
    public let isRunning: Bool

    /// The alert's title: `Delete “RSS digest”?`
    public var title: LocalizedStringResource {
        LocalizedStringResource(
            "jobDelete.title",
            defaultValue: "Delete “\(jobName)”?",
            bundle: .module,
            comment: "Title of the alert that confirms deleting a job. The argument is the job's name.",
        )
    }

    /// The alert's message: what survives the deletion, and, when the job is running,
    /// that it will be stopped. One whole message per state so a translation can word
    /// each freely.
    public var message: LocalizedStringResource {
        guard isRunning else {
            return LocalizedStringResource(
                "jobDelete.message",
                defaultValue: "Its past runs stay in History for up to 90 days.",
                bundle: .module,
                comment: "Message of the alert that confirms deleting a job that is not running.",
            )
        }
        return LocalizedStringResource(
            "jobDelete.messageRunning",
            defaultValue: "Its past runs stay in History for up to 90 days. The running job will be stopped.",
            bundle: .module,
            comment: "Message of the alert that confirms deleting a job while it is running.",
        )
    }

    /// Makes the confirmation for deleting `job`.
    public init(job: Job, isRunning: Bool) {
        jobID = job.id
        jobName = job.name
        self.isRunning = isRunning
    }
}
