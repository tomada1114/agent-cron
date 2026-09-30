import Foundation

/// What to do about the fire dates a schedule passed while nothing was watching.
public struct CatchUpPlan: Sendable, Equatable {
    /// The one missed date to run now, or `nil` when none is recent enough.
    public let runOnce: Date?
    /// Every other missed date, ascending, to record as skipped.
    public let skipped: [Date]

    /// Makes a plan.
    public init(runOnce: Date?, skipped: [Date]) {
        self.runOnce = runOnce
        self.skipped = skipped
    }
}

/// The fire dates of a ``Schedule`` in an injected calendar.
///
/// The calendar carries the time zone, so a time-zone change is a new `ScheduleCalendar`,
/// and tests pin DST transitions without touching the system zone. A wall time a DST gap
/// skips fires at the next valid minute; one a DST overlap repeats fires once, at its
/// first occurrence.
public struct ScheduleCalendar: Sendable {
    /// How long after a missed fire date it still runs on wake or launch (req §3.2).
    public static let defaultGrace: TimeInterval = 3_600

    /// Foundation numbers weekdays 1 (Sunday) to 7 (Saturday) in every calendar.
    private static let byCalendarWeekday: [Weekday] = [
        .sunday,
        .monday,
        .tuesday,
        .wednesday,
        .thursday,
        .friday,
        .saturday,
    ]

    /// The schedule whose dates are computed.
    public let schedule: Schedule
    /// The calendar, with its time zone, the schedule's wall times are read in.
    public let calendar: Calendar

    /// Makes a calculator for `schedule` read in `calendar`.
    public init(schedule: Schedule, calendar: Calendar) {
        self.schedule = schedule
        self.calendar = calendar
    }

    /// The earliest fire date strictly after `date`, or `nil` when the schedule has no
    /// day or no time.
    public func nextFireDate(after date: Date) -> Date? {
        guard !schedule.weekdays.isEmpty, !schedule.times.isEmpty else {
            return nil
        }
        let firstDay = calendar.startOfDay(for: date)
        // A full week past today, so every weekday is met at least once after `date`.
        for offset in 0 ... Weekday.allCases.count {
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else {
                continue
            }
            let dayStart = calendar.startOfDay(for: day)
            guard schedule.weekdays.contains(weekday(of: dayStart)) else {
                continue
            }
            for time in schedule.times {
                if let fire = fireDate(on: dayStart, at: time), fire > date {
                    return fire
                }
            }
        }
        return nil
    }

    /// Every fire date in `(lastChecked, now]`, ascending.
    public func missedFireDates(from lastChecked: Date, to now: Date) -> [Date] {
        var missed: [Date] = []
        var cursor = lastChecked
        while let next = nextFireDate(after: cursor), next <= now {
            missed.append(next)
            cursor = next
        }
        return missed
    }

    /// Coalesces the dates missed in `(lastChecked, now]` into at most one run: the
    /// latest, when it is at most `grace` old; everything else is skipped.
    public func catchUpPlan(
        lastChecked: Date,
        now: Date,
        grace: TimeInterval = defaultGrace,
    ) -> CatchUpPlan {
        var missed = missedFireDates(from: lastChecked, to: now)
        guard let latest = missed.last, now.timeIntervalSince(latest) <= grace else {
            return CatchUpPlan(runOnce: nil, skipped: missed)
        }
        missed.removeLast()
        return CatchUpPlan(runOnce: latest, skipped: missed)
    }

    private func fireDate(on dayStart: Date, at time: TimeOfDay) -> Date? {
        let fire = calendar.nextDate(
            after: dayStart.addingTimeInterval(-1),
            matching: DateComponents(hour: time.hour, minute: time.minute, second: 0),
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
        )
        guard let fire, calendar.isDate(fire, inSameDayAs: dayStart) else {
            return nil
        }
        return fire
    }

    private func weekday(of date: Date) -> Weekday {
        let index = calendar.component(.weekday, from: date) - 1
        return Self.byCalendarWeekday[index % Self.byCalendarWeekday.count]
    }
}
