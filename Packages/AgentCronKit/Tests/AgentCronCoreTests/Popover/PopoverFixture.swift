import AgentCronCore
import AgentCronTestSupport
import Foundation

/// The issue's worked examples: Tuesday 2026-09-29 in UTC, "RSS digest" on weekdays at
/// 09:00 and 18:00, "Dependabot review" on weekdays at 12:00.
enum PopoverFixture {
    /// 2026-09-29T00:00:00Z, a Tuesday.
    static let tuesdayMidnightSeconds: TimeInterval = 1_790_640_000
    static let secondsPerHour: TimeInterval = 3_600
    static let secondsPerDay: TimeInterval = 86_400
    static let secondsPerMinute: TimeInterval = 60
    static let digestNumber = 1
    static let reviewNumber = 2
    static let nightlyNumber = 3
    static let nineHour = 9
    static let noonHour = 12
    static let sixPMHour = 18

    static let calendar: Calendar = {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC") ?? gregorian.timeZone
        return gregorian
    }()

    static let digest = JobsScreenFixture.job(
        digestNumber,
        "RSS digest",
        days: SchedulePreset.weekdays.weekdays,
        times: [(nineHour, 0), (sixPMHour, 0)],
    )
    static let review = JobsScreenFixture.job(
        reviewNumber,
        "Dependabot review",
        days: SchedulePreset.weekdays.weekdays,
        times: [(noonHour, 0)],
    )

    /// Tuesday at `hour`:`minute`.
    static func tuesday(_ hour: Int, _ minute: Int) -> Date {
        tuesday(hour, minute, plusDays: 0)
    }

    /// Tuesday at `hour`:`minute`, `days` later.
    static func tuesday(_ hour: Int, _ minute: Int, plusDays days: Int) -> Date {
        Date(timeIntervalSince1970: tuesdayMidnightSeconds
            + TimeInterval(days) * secondsPerDay
            + TimeInterval(hour) * secondsPerHour
            + TimeInterval(minute) * secondsPerMinute)
    }

    /// A run of `job` started at `start`, still running.
    static func run(of job: Job, at start: Date) -> Run {
        Run(job: job, trigger: .scheduled, startedAt: start, scheduledAt: start)
    }

    /// A run of `job` from `start` to `end` that ended as `outcome`, with no cost.
    static func run(of job: Job, at start: Date, ended end: Date, outcome: RunOutcome) -> Run {
        run(of: job, at: start, ended: end, outcome: outcome, cost: nil)
    }

    /// A run of `job` from `start` to `end` that ended as `outcome` and cost `cost`.
    static func run(
        of job: Job,
        at start: Date,
        ended end: Date,
        outcome: RunOutcome,
        cost: Decimal?,
    ) -> Run {
        var finished = run(of: job, at: start)
        finished.endedAt = end
        finished.outcome = outcome
        finished.costUSD = cost
        return finished
    }

    /// A loaded model over `jobs` and no runs, reading `now`.
    @MainActor
    static func model(jobs: [Job], now: Date, defaults: UserDefaults) -> PopoverModel {
        model(jobs: jobs, runs: [], now: now, defaults: defaults)
    }

    /// A loaded model over `jobs` and `runs`, reading `now`.
    @MainActor
    static func model(jobs: [Job], runs: [Run], now: Date, defaults: UserDefaults) -> PopoverModel {
        model(
            jobStore: FakeJobStore(document: JobsDocument(jobs: jobs)),
            runs: runs,
            now: now,
            defaults: defaults,
            keepAwake: KeepAwakeController(preventer: FakeSleepPreventer()),
        )
    }

    /// A loaded model over `jobs` and no runs that drives `keepAwake`.
    @MainActor
    static func model(
        jobs: [Job],
        now: Date,
        defaults: UserDefaults,
        keepAwake: KeepAwakeController,
    ) -> PopoverModel {
        model(
            jobStore: FakeJobStore(document: JobsDocument(jobs: jobs)),
            runs: [],
            now: now,
            defaults: defaults,
            keepAwake: keepAwake,
        )
    }

    /// A loaded model over `jobStore` and `runs`.
    @MainActor
    static func model(
        jobStore: any JobStoring,
        runs: [Run],
        now: Date,
        defaults: UserDefaults,
        keepAwake: KeepAwakeController,
    ) -> PopoverModel {
        let model = PopoverModel(
            jobStore: jobStore,
            runStore: FakeRunStore(runs: runs),
            keepAwake: keepAwake,
            calendar: calendar,
            defaults: defaults,
            locale: .english,
        ) { now }
        model.load()
        return model
    }
}
