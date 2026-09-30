import Foundation

/// A day of the week a job may fire on.
///
/// Cases are declared alphabetically (SwiftLint's `sorted_enum_cases`); ``allCases``
/// and the ordering both run Monday to Sunday, the order the editor shows its day chips
/// in. The raw value is what `jobs.json` stores, so changing it is a file-format change.
public enum Weekday: String, Sendable, Codable, CaseIterable, Comparable {
    /// Friday.
    case friday
    /// Monday.
    case monday
    /// Saturday.
    case saturday
    /// Sunday.
    case sunday
    /// Thursday.
    case thursday
    /// Tuesday.
    case tuesday
    /// Wednesday.
    case wednesday

    /// Every day, Monday first.
    public static let allCases: [Self] = [
        .monday,
        .tuesday,
        .wednesday,
        .thursday,
        .friday,
        .saturday,
        .sunday,
    ]

    /// The day's abbreviated name, as a day chip and a summary of custom days show it.
    public var shortName: LocalizedStringResource {
        switch self {
        case .monday:
            LocalizedStringResource(
                "weekday.short.monday",
                defaultValue: "Mon",
                bundle: .module,
                comment: "Abbreviated Monday, on a job editor day chip and in a schedule summary.",
            )

        case .tuesday:
            LocalizedStringResource(
                "weekday.short.tuesday",
                defaultValue: "Tue",
                bundle: .module,
                comment: "Abbreviated Tuesday, on a job editor day chip and in a schedule summary.",
            )

        case .wednesday:
            LocalizedStringResource(
                "weekday.short.wednesday",
                defaultValue: "Wed",
                bundle: .module,
                comment: "Abbreviated Wednesday, on a job editor day chip and in a schedule summary.",
            )

        case .thursday:
            LocalizedStringResource(
                "weekday.short.thursday",
                defaultValue: "Thu",
                bundle: .module,
                comment: "Abbreviated Thursday, on a job editor day chip and in a schedule summary.",
            )

        case .friday:
            LocalizedStringResource(
                "weekday.short.friday",
                defaultValue: "Fri",
                bundle: .module,
                comment: "Abbreviated Friday, on a job editor day chip and in a schedule summary.",
            )

        case .saturday:
            LocalizedStringResource(
                "weekday.short.saturday",
                defaultValue: "Sat",
                bundle: .module,
                comment: "Abbreviated Saturday, on a job editor day chip and in a schedule summary.",
            )

        case .sunday:
            LocalizedStringResource(
                "weekday.short.sunday",
                defaultValue: "Sun",
                bundle: .module,
                comment: "Abbreviated Sunday, on a job editor day chip and in a schedule summary.",
            )
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        // Every case is in `allCases`, so neither fallback is ever taken.
        (allCases.firstIndex(of: lhs) ?? 0) < (allCases.firstIndex(of: rhs) ?? 0)
    }
}
