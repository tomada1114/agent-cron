import Foundation

/// A main-menu command only the Jobs screen can carry out, because it acts on the job
/// list and editor the screen owns.
public enum JobsScreenCommand: Sendable, Equatable {
    /// Job › Delete… (⌘⌫) on the saved job `jobID`: the delete alert (S5).
    case delete(jobID: UUID)
    /// File › New Job (⌘N): an empty draft.
    case newJob
    /// Job › Enable / Disable (⌘E) on the saved job `jobID`.
    case toggleEnabled(jobID: UUID)
}

/// One command the main menu handed to the Jobs screen, waiting in
/// ``MainNavigationModel/pendingJobsScreenRequest`` until the screen reports it handled.
///
/// Each request is numbered, so choosing the same command twice is two requests a view
/// sees change, not one value that stayed the same.
public struct JobsScreenRequest: Sendable, Equatable {
    /// What was asked for.
    public let command: JobsScreenCommand
    /// Which request this is, counting from one per navigation model.
    public let sequence: Int
}
