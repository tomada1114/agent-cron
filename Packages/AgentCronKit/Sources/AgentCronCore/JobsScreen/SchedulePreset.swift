import Foundation

/// A one-click choice of days in the job editor's Days row (`docs/product/ux-flows.md`
/// S2), and the name a schedule on exactly those days is summarized with.
public enum SchedulePreset: Sendable, CaseIterable {
    /// All seven days.
    case everyDay
    /// Monday to Friday.
    case weekdays
    /// Saturday and Sunday.
    case weekends

    /// The days the preset selects.
    public var weekdays: Set<Weekday> {
        switch self {
        case .everyDay:
            Set(Weekday.allCases)

        case .weekdays:
            [.monday, .tuesday, .wednesday, .thursday, .friday]

        case .weekends:
            [.saturday, .sunday]
        }
    }

    /// The preset's button title, which is also how a schedule on exactly its days
    /// names them in a summary.
    public var title: LocalizedStringResource {
        switch self {
        case .everyDay:
            LocalizedStringResource(
                "schedulePreset.everyDay",
                defaultValue: "Every day",
                bundle: .module,
                comment: "Days preset in the job editor, and a schedule summary's name for all seven days.",
            )

        case .weekdays:
            LocalizedStringResource(
                "schedulePreset.weekdays",
                defaultValue: "Weekdays",
                bundle: .module,
                comment: "Days preset in the job editor, and a schedule summary's name for Monday to Friday.",
            )

        case .weekends:
            LocalizedStringResource(
                "schedulePreset.weekends",
                defaultValue: "Weekends",
                bundle: .module,
                comment: "Days preset in the job editor, and a schedule summary's name for Saturday and Sunday.",
            )
        }
    }
}
