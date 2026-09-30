import Foundation

/// Which day a popover row falls on, relative to today (`docs/product/ux-flows.md` S1).
public enum PopoverDay: Sendable, Equatable {
    /// Today; the row carries no day label.
    case today
    /// The day after today.
    case tomorrow
    /// A later day, named by its weekday.
    case weekday(Weekday)

    /// The day's label, or `nil` for today, whose rows show only a time.
    public var label: LocalizedStringResource? {
        switch self {
        case .today:
            nil

        case .tomorrow:
            LocalizedStringResource(
                "popover.day.tomorrow",
                defaultValue: "Tomorrow",
                bundle: .module,
                comment: "Day label of the menu-bar popover's next run when it is tomorrow.",
            )

        case let .weekday(day):
            day.shortName
        }
    }
}

/// One line of the popover's timeline: a finished or running run, or an upcoming fire
/// date (plan P22).
public struct PopoverRow: Sendable, Equatable, Identifiable {
    /// The run's identifier, or for an upcoming row the job's identifier and fire date.
    public let id: String
    /// When the run started, or when the upcoming run fires.
    public let date: Date
    /// ``date`` as `HH:mm` on a 24-hour clock in the model's calendar.
    public let timeText: String
    /// Which day ``date`` falls on.
    public let day: PopoverDay
    /// The outcome badge: the run's outcome, or ``OutcomeBadgeKind/upcoming``.
    public let badge: OutcomeBadgeKind
    /// The job the row is for.
    public let jobID: UUID
    /// The job's name — for a run, the name it had when the run started.
    public let jobName: String
    /// How long a finished run took; `nil` while running or upcoming.
    public let duration: Duration?
    /// What a finished run cost in US dollars, when the agent reported it.
    public let costUSD: Decimal?
    /// Whether the run skips every permission check, which the row flags.
    public let usesBypassPermissions: Bool

    /// Makes a row; the model builds them, and a preview or test may too.
    public init(
        id: String,
        date: Date,
        timeText: String,
        day: PopoverDay,
        badge: OutcomeBadgeKind,
        jobID: UUID,
        jobName: String,
        duration: Duration?,
        costUSD: Decimal?,
        usesBypassPermissions: Bool,
    ) {
        self.id = id
        self.date = date
        self.timeText = timeText
        self.day = day
        self.badge = badge
        self.jobID = jobID
        self.jobName = jobName
        self.duration = duration
        self.costUSD = costUSD
        self.usesBypassPermissions = usesBypassPermissions
    }
}
