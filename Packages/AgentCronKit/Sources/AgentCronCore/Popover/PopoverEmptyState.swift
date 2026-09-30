import Foundation

/// The one empty state the popover shows instead of, or above, its timeline
/// (`docs/design/ux-guidelines.md` › States).
public enum PopoverEmptyState: Sendable, Equatable {
    /// Every saved job is paused; no upcoming run is listed.
    case allPaused
    /// No job is saved.
    case noJobs
    /// Nothing is finished, running, or due today; `next` is the next run.
    /// `dayText` is `next`'s day label already rendered in the model's locale.
    case nothingToday(next: PopoverRow, dayText: String)

    /// The sentence the popover shows.
    public var message: LocalizedStringResource {
        switch self {
        case .noJobs:
            LocalizedStringResource(
                "popover.empty.noJobs",
                defaultValue: "No jobs yet",
                bundle: .module,
                comment: "Menu-bar popover empty state when no job is saved.",
            )

        case .allPaused:
            LocalizedStringResource(
                "popover.empty.allPaused",
                defaultValue: "All jobs are paused.",
                bundle: .module,
                comment: "Menu-bar popover empty state when every job is paused.",
            )

        case let .nothingToday(next, dayText):
            LocalizedStringResource(
                "popover.empty.nothingToday",
                defaultValue: "Nothing scheduled today. Next: \(dayText) \(next.timeText) \(next.jobName).",
                bundle: .module,
                comment: "Menu-bar popover empty state; arguments: the next run's day, time, and job name.",
            )
        }
    }
}
