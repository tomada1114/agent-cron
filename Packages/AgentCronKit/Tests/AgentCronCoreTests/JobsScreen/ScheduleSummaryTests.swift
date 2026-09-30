import AgentCronCore
import Foundation
import Testing

@Suite("Schedule summary")
struct ScheduleSummaryTests {
    private static let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    private static func schedule(_ days: Set<Weekday>, _ times: [(Int, Int)]) -> Schedule {
        Schedule(weekdays: days, times: times.map { Fixture.time($0.0, $0.1) })
    }

    @Test
    func `presets select every day, Monday to Friday, and the weekend`() {
        #expect(SchedulePreset.allCases == [.everyDay, .weekdays, .weekends])
        #expect(SchedulePreset.everyDay.weekdays == Set(Weekday.allCases))
        #expect(SchedulePreset.weekdays.weekdays == Self.weekdays)
        #expect(SchedulePreset.weekends.weekdays == [.saturday, .sunday])
    }

    @Test(arguments: [
        (SchedulePreset.everyDay, "Every day"),
        (.weekdays, "Weekdays"),
        (.weekends, "Weekends"),
    ])
    func `each preset has its title`(preset: SchedulePreset, title: String) {
        #expect(preset.title.resolved(in: .english) == title)
    }

    @Test(arguments: [
        (Weekday.monday, "Mon"),
        (.tuesday, "Tue"),
        (.wednesday, "Wed"),
        (.thursday, "Thu"),
        (.friday, "Fri"),
        (.saturday, "Sat"),
        (.sunday, "Sun"),
    ])
    func `each weekday has its short name`(day: Weekday, name: String) {
        #expect(day.shortName.resolved(in: .english) == name)
    }

    @Test
    func `weekdays at three times read as the issue's example`() throws {
        let schedule = Self.schedule(Self.weekdays, [(18, 0), (9, 0), (12, 0)])
        let summary = try #require(schedule.summary)
        let compact = try #require(schedule.compactSummary)
        #expect(summary.resolved(in: .english) == "Weekdays at 09:00, 12:00, 18:00")
        #expect(compact.resolved(in: .english) == "Weekdays 09:00 +2")
    }

    @Test
    func `one time has no count of more times`() throws {
        let schedule = Self.schedule(Set(Weekday.allCases), [(12, 0)])
        #expect(try #require(schedule.summary).resolved(in: .english) == "Every day at 12:00")
        #expect(try #require(schedule.compactSummary).resolved(in: .english) == "Every day 12:00")
    }

    @Test
    func `the weekend preset names Saturday and Sunday`() throws {
        let schedule = Self.schedule([.sunday, .saturday], [(7, 5), (23, 59)])
        #expect(
            try #require(schedule.summary).resolved(in: .english) == "Weekends at 07:05, 23:59",
        )
        #expect(try #require(schedule.compactSummary).resolved(in: .english) == "Weekends 07:05 +1")
    }

    @Test
    func `days matching no preset are listed Monday first`() throws {
        let schedule = Self.schedule([.friday, .monday, .wednesday], [(0, 0)])
        #expect(try #require(schedule.summary).resolved(in: .english) == "Mon, Wed, Fri at 00:00")
        #expect(try #require(schedule.compactSummary)
            .resolved(in: .english) == "Mon, Wed, Fri 00:00")
    }

    @Test
    func `one day matching no preset is named alone`() throws {
        let schedule = Self.schedule([.sunday], [(9, 30)])
        #expect(try #require(schedule.summary).resolved(in: .english) == "Sun at 09:30")
    }

    @Test(arguments: [
        Schedule(weekdays: [], times: [Fixture.time(9, 0)]),
        Schedule(weekdays: [.monday], times: []),
        Schedule(weekdays: [], times: []),
    ])
    func `a schedule without a day or a time has no summary`(schedule: Schedule) {
        #expect(schedule.summary == nil)
        #expect(schedule.compactSummary == nil)
    }
}
