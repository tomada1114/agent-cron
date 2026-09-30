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

    public static func < (lhs: Self, rhs: Self) -> Bool {
        // Every case is in `allCases`, so neither fallback is ever taken.
        (allCases.firstIndex(of: lhs) ?? 0) < (allCases.firstIndex(of: rhs) ?? 0)
    }
}
