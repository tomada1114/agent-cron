import AgentCronCore
import Foundation
import Testing

@Suite("Job")
struct JobTests {
    /// What `validate()` reports for the fixture job after `change`.
    private func validating(_ change: (inout Job) -> Void) -> [JobValidationError] {
        var job = Fixture.job()
        change(&job)
        return job.validate()
    }

    // MARK: - Defaults

    @Test
    func `a job built from the required fields takes the documented defaults`() {
        let job = Fixture.job()
        #expect(job.id == Fixture.jobID)
        #expect(job.agent == .claudeCode)
        #expect(job.model == .default)
        #expect(job.effort == .default)
        #expect(job.permissionMode == .auto)
        #expect(job.timeoutMinutes == 30)
        #expect(job.notify == .failuresOnly)
        #expect(job.enabled)
        #expect(job.createdAt == Fixture.createdAt)
        #expect(job.updatedAt == Fixture.createdAt)
    }

    @Test
    func `an explicit updatedAt is kept apart from createdAt`() {
        let job = Job(
            name: "Nightly review",
            directory: Fixture.directory,
            prompt: "Review open PRs.",
            schedule: Fixture.schedule,
            createdAt: Fixture.createdAt,
            updatedAt: Fixture.updatedAt,
        )
        #expect(job.createdAt == Fixture.createdAt)
        #expect(job.updatedAt == Fixture.updatedAt)
    }

    @Test
    func `a job that keeps every rule has no validation errors`() {
        #expect(Fixture.job().validate().isEmpty)
    }

    // MARK: - Name

    @Test(arguments: [
        (0, [JobValidationError.nameEmpty]),
        (1, []),
        (60, []),
        (61, [JobValidationError.nameTooLong(characterCount: 61)]),
    ])
    func `name must have 1 to 60 characters`(length: Int, expected: [JobValidationError]) {
        #expect(validating { $0.name = String(repeating: "n", count: length) } == expected)
    }

    @Test(arguments: ["   ", "\n\t "])
    func `a whitespace-only name is reported empty`(name: String) {
        #expect(validating { $0.name = name } == [.nameEmpty])
    }

    @Test
    func `surrounding whitespace does not count toward the name's length`() {
        let name = "  " + String(repeating: "n", count: 60) + "\n"
        #expect(validating { $0.name = name }.isEmpty)
    }

    @Test
    func `name length counts characters a reader sees, not UTF-16 units`() {
        let name = String(repeating: "日", count: 59) + "👩‍💻"
        #expect(validating { $0.name = name }.isEmpty)
    }

    // MARK: - Directory

    @Test
    func `a directory that is not a local file URL is reported`() throws {
        let remote = try #require(URL(string: "https://example.com/repo"))
        #expect(validating { $0.directory = remote } == [.directoryNotLocal])
    }

    // MARK: - Prompt

    @Test(arguments: ["", "   ", "\n\t\n"])
    func `a prompt that is empty after trimming is reported`(prompt: String) {
        #expect(validating { $0.prompt = prompt } == [.promptEmpty])
    }

    @Test
    func `a one-character prompt is valid`() {
        #expect(validating { $0.prompt = " x " }.isEmpty)
    }

    // MARK: - Schedule

    @Test
    func `no weekday is reported`() {
        let schedule = Schedule(weekdays: [], times: [Fixture.time(9, 0)])
        #expect(validating { $0.schedule = schedule } == [.noWeekdays])
    }

    @Test
    func `one weekday is valid`() {
        let schedule = Schedule(weekdays: [.sunday], times: [Fixture.time(9, 0)])
        #expect(validating { $0.schedule = schedule }.isEmpty)
    }

    @Test
    func `no time is reported`() {
        let schedule = Schedule(weekdays: [.monday], times: [])
        #expect(validating { $0.schedule = schedule } == [.noTimes])
    }

    @Test
    func `a time listed twice is reported once, as a duplicate`() {
        let nine = Fixture.time(9, 0)
        let schedule = Schedule(weekdays: [.monday], times: [nine, Fixture.time(12, 0), nine])
        #expect(validating { $0.schedule = schedule } == [.duplicateTimes([nine])])
    }

    @Test
    func `every duplicated time is named, in time order`() {
        let nine = Fixture.time(9, 0)
        let noon = Fixture.time(12, 0)
        let schedule = Schedule(weekdays: [.monday], times: [noon, nine, noon, nine, nine])
        #expect(validating { $0.schedule = schedule } == [.duplicateTimes([nine, noon])])
    }

    @Test
    func `distinct times are valid`() {
        let schedule = Schedule(
            weekdays: [.monday],
            times: [Fixture.time(9, 0), Fixture.time(9, 1), Fixture.time(18, 0)],
        )
        #expect(validating { $0.schedule = schedule }.isEmpty)
    }

    // MARK: - Timeout

    @Test(arguments: [
        (-5, [JobValidationError.timeoutOutOfRange(minutes: -5)]),
        (0, [JobValidationError.timeoutOutOfRange(minutes: 0)]),
        (1, []),
        (1_440, []),
        (1_441, [JobValidationError.timeoutOutOfRange(minutes: 1_441)]),
    ])
    func `timeout must be 1 to 1440 minutes`(minutes: Int, expected: [JobValidationError]) {
        #expect(validating { $0.timeoutMinutes = minutes } == expected)
    }

    // MARK: - Every rule at once

    @Test
    func `validate reports every violated rule, in the editor's field order`() throws {
        let nine = Fixture.time(9, 0)
        let remote = try #require(URL(string: "https://example.com/repo"))
        let errors = validating { job in
            job.name = ""
            job.directory = remote
            job.prompt = " "
            job.schedule = Schedule(weekdays: [], times: [nine, nine])
            job.timeoutMinutes = 0
        }
        #expect(errors == [
            .nameEmpty,
            .directoryNotLocal,
            .promptEmpty,
            .noWeekdays,
            .duplicateTimes([nine]),
            .timeoutOutOfRange(minutes: 0),
        ])
    }

    @Test
    func `validate reports a missing time alongside the other schedule rule`() {
        let errors = validating { job in
            job.name = String(repeating: "n", count: 61)
            job.schedule = Schedule(weekdays: [], times: [])
        }
        #expect(errors == [.nameTooLong(characterCount: 61), .noWeekdays, .noTimes])
    }

    // MARK: - Messages

    @Test(arguments: [
        (JobValidationError.nameEmpty, "Enter a name."),
        (.nameTooLong(characterCount: 61), "Shorten the name to 60 characters or fewer."),
        (.directoryNotLocal, "Choose a folder on this Mac."),
        (.promptEmpty, "Enter a prompt."),
        (.noWeekdays, "Choose at least one day."),
        (.noTimes, "Add at least one time."),
        (.duplicateTimes([Fixture.time(9, 0)]), "Remove the duplicate time."),
        (.timeoutOutOfRange(minutes: 0), "Enter a timeout from 1 to 1,440 minutes."),
    ])
    func `each error says what to fix`(error: JobValidationError, english: String) {
        #expect(error.message.resolved(in: .english) == english)
    }

    // MARK: - Codable

    @Test
    func `a job with default options survives a JSON round trip unchanged`() throws {
        let job = Fixture.job()
        #expect(try Fixture.roundTrip(job) == job)
    }

    @Test
    func `a job with every option set survives a JSON round trip unchanged`() throws {
        let job = Job(
            name: "Dependabot review — 毎日",
            directory: Fixture.directory,
            prompt: "/review-dependabot\nMerge only safe bumps.",
            schedule: Schedule(
                weekdays: [.saturday, .sunday],
                times: [Fixture.time(23, 59), Fixture.time(0, 0)],
            ),
            createdAt: Fixture.createdAt,
            id: Fixture.jobID,
            agent: .claudeCode,
            model: .fable,
            effort: .xhigh,
            permissionMode: .bypassPermissions,
            timeoutMinutes: 1_440,
            notify: .everyRun,
            enabled: false,
            updatedAt: Fixture.updatedAt,
        )
        #expect(try Fixture.roundTrip(job) == job)
    }
}
