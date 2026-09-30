import AgentCronCore
import Foundation
import Testing

@Suite("ScheduleCalendar")
struct ScheduleCalendarTests {
    private static let weekdaysOnly: Set<Weekday> = [
        .monday,
        .tuesday,
        .wednesday,
        .thursday,
        .friday,
    ]
    private static let everyDay = Set(Weekday.allCases)

    private static func calendar(_ zone: String) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: zone))
        return calendar
    }

    private static func date(
        _ calendar: Calendar,
        day ymd: [Int],
        time hms: [Int],
    ) throws -> Date {
        let components = DateComponents(
            year: ymd[0],
            month: ymd[1],
            day: ymd[2],
            hour: hms[0],
            minute: hms[1],
            second: hms.count > 2 ? hms[2] : 0,
        )
        return try #require(calendar.date(from: components))
    }

    private static func tokyoWorkday() throws -> ScheduleCalendar {
        try ScheduleCalendar(
            schedule: Schedule(
                weekdays: weekdaysOnly,
                times: [Fixture.time(9, 0), Fixture.time(12, 0), Fixture.time(18, 0)],
            ),
            calendar: calendar("Asia/Tokyo"),
        )
    }

    private static func dailyAtTen() throws -> ScheduleCalendar {
        try ScheduleCalendar(
            schedule: Schedule(weekdays: everyDay, times: [Fixture.time(10, 0)]),
            calendar: calendar("Asia/Tokyo"),
        )
    }

    /// REQ-001
    @Test
    func `the next fire after Friday's last slot is Monday 09:00`() throws {
        let subject = try Self.tokyoWorkday()
        let after = try Self.date(subject.calendar, day: [2_026, 10, 2], time: [18, 0, 1])
        let expected = try Self.date(subject.calendar, day: [2_026, 10, 5], time: [9, 0])
        #expect(subject.nextFireDate(after: after) == expected)
    }

    @Test
    func `an instant exactly on a fire time yields the following slot`() throws {
        let subject = try Self.tokyoWorkday()
        let after = try Self.date(subject.calendar, day: [2_026, 10, 1], time: [9, 0])
        let expected = try Self.date(subject.calendar, day: [2_026, 10, 1], time: [12, 0])
        #expect(subject.nextFireDate(after: after) == expected)
    }

    @Test
    func `a schedule with no day or no time never fires`() throws {
        let calendar = try Self.calendar("Asia/Tokyo")
        let now = try Self.date(calendar, day: [2_026, 10, 1], time: [8, 0])
        let noDays = ScheduleCalendar(
            schedule: Schedule(weekdays: [], times: [Fixture.time(9, 0)]), calendar: calendar,
        )
        let noTimes = ScheduleCalendar(
            schedule: Schedule(weekdays: Self.everyDay, times: []), calendar: calendar,
        )
        #expect(noDays.nextFireDate(after: now) == nil)
        #expect(noTimes.missedFireDates(from: now, to: now.addingTimeInterval(86_400 * 8)).isEmpty)
    }

    /// REQ-002
    @Test
    func `missed dates are every fire in (lastChecked, now], ascending`() throws {
        let subject = try Self.tokyoWorkday()
        let cal = subject.calendar
        let lastChecked = try Self.date(cal, day: [2_026, 10, 1], time: [9, 0])
        let now = try Self.date(cal, day: [2_026, 10, 2], time: [12, 0])
        let expected = try [
            Self.date(cal, day: [2_026, 10, 1], time: [12, 0]),
            Self.date(cal, day: [2_026, 10, 1], time: [18, 0]),
            Self.date(cal, day: [2_026, 10, 2], time: [9, 0]),
            Self.date(cal, day: [2_026, 10, 2], time: [12, 0]),
        ]
        #expect(subject.missedFireDates(from: lastChecked, to: now) == expected)
    }

    /// REQ-003
    @Test
    func `a missed time within grace runs once`() throws {
        let subject = try Self.dailyAtTen()
        let cal = subject.calendar
        let plan = try subject.catchUpPlan(
            lastChecked: Self.date(cal, day: [2_026, 10, 1], time: [9, 55]),
            now: Self.date(cal, day: [2_026, 10, 1], time: [10, 30]),
            grace: 3_600,
        )
        #expect(try plan == CatchUpPlan(
            runOnce: Self.date(cal, day: [2_026, 10, 1], time: [10, 0]),
            skipped: [],
        ))
    }

    @Test
    func `several missed times coalesce: the latest runs, earlier ones are skipped`() throws {
        let subject = try Self.dailyAtTen()
        let cal = subject.calendar
        let plan = try subject.catchUpPlan(
            lastChecked: Self.date(cal, day: [2_026, 9, 29], time: [9, 0]),
            now: Self.date(cal, day: [2_026, 10, 1], time: [10, 30]),
        )
        let expected = try CatchUpPlan(
            runOnce: Self.date(cal, day: [2_026, 10, 1], time: [10, 0]),
            skipped: [
                Self.date(cal, day: [2_026, 9, 29], time: [10, 0]),
                Self.date(cal, day: [2_026, 9, 30], time: [10, 0]),
            ],
        )
        #expect(plan == expected)
    }

    @Test
    func `a missed time exactly 60 minutes old still runs`() throws {
        let subject = try Self.dailyAtTen()
        let cal = subject.calendar
        let plan = try subject.catchUpPlan(
            lastChecked: Self.date(cal, day: [2_026, 10, 1], time: [9, 55]),
            now: Self.date(cal, day: [2_026, 10, 1], time: [11, 0]),
        )
        #expect(ScheduleCalendar.defaultGrace == 3_600)
        #expect(try plan.runOnce == Self.date(cal, day: [2_026, 10, 1], time: [10, 0]))
        #expect(plan.skipped.isEmpty)
    }

    /// REQ-004
    @Test
    func `a missed time older than grace is skipped`() throws {
        let subject = try Self.dailyAtTen()
        let cal = subject.calendar
        let plan = try subject.catchUpPlan(
            lastChecked: Self.date(cal, day: [2_026, 10, 1], time: [9, 55]),
            now: Self.date(cal, day: [2_026, 10, 1], time: [11, 30]),
            grace: 3_600,
        )
        #expect(try plan == CatchUpPlan(
            runOnce: nil,
            skipped: [Self.date(cal, day: [2_026, 10, 1], time: [10, 0])],
        ))
    }

    @Test
    func `nothing missed yields an empty plan`() throws {
        let subject = try Self.dailyAtTen()
        let cal = subject.calendar
        let plan = try subject.catchUpPlan(
            lastChecked: Self.date(cal, day: [2_026, 10, 1], time: [10, 5]),
            now: Self.date(cal, day: [2_026, 10, 1], time: [11, 0]),
        )
        #expect(plan == CatchUpPlan(runOnce: nil, skipped: []))
    }

    /// REQ-005
    @Test
    func `a wall time in the spring-forward gap fires at the next valid minute`() throws {
        let calendar = try Self.calendar("America/New_York")
        let subject = ScheduleCalendar(
            schedule: Schedule(weekdays: Self.everyDay, times: [Fixture.time(2, 30)]),
            calendar: calendar,
        )
        let after = try Self.date(calendar, day: [2_026, 3, 7], time: [12, 0])
        let fire = try #require(subject.nextFireDate(after: after))
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        #expect(parts == DateComponents(year: 2_026, month: 3, day: 8, hour: 3, minute: 0))
    }

    @Test
    func `a wall time the fall-back overlap repeats fires once`() throws {
        let calendar = try Self.calendar("America/New_York")
        let subject = ScheduleCalendar(
            schedule: Schedule(weekdays: Self.everyDay, times: [Fixture.time(1, 30)]),
            calendar: calendar,
        )
        let missed = try subject.missedFireDates(
            from: Self.date(calendar, day: [2_026, 10, 31], time: [12, 0]),
            to: Self.date(calendar, day: [2_026, 11, 2], time: [0, 0]),
        )
        let onFirst = missed.filter { fire in
            calendar.dateComponents([.month, .day], from: fire) == DateComponents(month: 11, day: 1)
        }
        #expect(onFirst.count == 1)
        #expect(missed.count == 1)
    }
}
