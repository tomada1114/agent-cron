import Foundation

/// Where the Jobs screen's detail pane can be asked to go.
public enum JobListTarget: Sendable, Equatable {
    /// A saved job's editor.
    case job(UUID)
    /// A new, empty draft.
    case newJob
    /// No editor: "Select a job".
    case nothing
}
