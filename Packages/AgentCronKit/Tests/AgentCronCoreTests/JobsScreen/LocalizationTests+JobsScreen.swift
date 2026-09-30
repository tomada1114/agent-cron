import AgentCronCore
import AgentCronTestSupport
import Foundation

extension LocalizationTests {
    /// Every resource the Jobs screen's models return, once per key, with the English
    /// arguments each takes.
    static func jobsScreenCases() -> [Case] {
        let weekdays = Schedule(
            weekdays: SchedulePreset.weekdays.weekdays,
            times: Fixture.schedule.times + [JobsScreenFixture.noon],
        )
        let custom = Schedule(weekdays: [.monday, .friday], times: Fixture.schedule.times)
        let running = JobEditorModel(
            editing: Fixture.job(),
            store: FakeJobStore(),
            now: JobsScreenFixture.clock,
        )
        running.runningStateChanged(isRunning: true)
        let confirmation = JobDeleteConfirmation(job: Fixture.job(), isRunning: false)
        let runningConfirmation = JobDeleteConfirmation(job: Fixture.job(), isRunning: true)

        var cases = SchedulePreset.allCases.map { Case(resource: $0.title, arguments: []) }
        cases += Weekday.allCases.map { Case(resource: $0.shortName, arguments: []) }
        let optionalCases: [(LocalizedStringResource?, [any CVarArg])] = [
            (weekdays.summary, ["Weekdays", "09:00, 12:00"]),
            (custom.compactSummary, ["Mon, Fri", "09:00"]),
            (weekdays.compactSummary, ["Weekdays", "09:00", 1]),
            (custom.daysName, ["Mon, Fri"]),
            (running.runningNote, []),
        ]
        for (resource, arguments) in optionalCases {
            if let resource {
                cases.append(Case(resource: resource, arguments: arguments))
            }
        }
        return cases + [
            Case(resource: confirmation.title, arguments: [Fixture.name]),
            Case(resource: confirmation.message, arguments: []),
            Case(resource: runningConfirmation.message, arguments: []),
        ]
    }
}
