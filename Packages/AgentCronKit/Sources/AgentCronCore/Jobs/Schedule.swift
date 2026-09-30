/// When a job fires: at each of ``times`` on each of ``weekdays``, in local time.
///
/// Weekdays and times only — no cron expression or interval (a Product non-goal). The
/// type does not enforce the rules a saved job must meet (at least one day and one time,
/// no time twice); ``Job/validate()`` reports those, so an editor can hold an
/// incomplete schedule while the user fills it in.
public struct Schedule: Sendable, Equatable, Codable {
    private enum CodingKeys: String, CodingKey {
        case times
        case weekdays
    }

    /// The days the job fires on.
    public var weekdays: Set<Weekday>

    /// The times the job fires at on each of those days, always in ascending order
    /// however they were given. A duplicate is kept, not dropped, so validation can tell
    /// the user about it.
    public var times: [TimeOfDay] {
        didSet {
            times.sort()
        }
    }

    /// Makes a schedule; `times` are put in ascending order.
    public init(weekdays: Set<Weekday>, times: [TimeOfDay]) {
        self.weekdays = weekdays
        self.times = times.sorted()
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            weekdays: Set(container.decode([Weekday].self, forKey: .weekdays)),
            times: container.decode([TimeOfDay].self, forKey: .times),
        )
    }

    /// Writes the weekdays Monday first, so the same schedule always writes the same
    /// bytes whatever order the set iterates in.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(weekdays.sorted(), forKey: .weekdays)
        try container.encode(times, forKey: .times)
    }
}
