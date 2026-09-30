import AgentCronCore
import AgentCronTestSupport
import Foundation

/// Fixed inputs for the History suites: "now" is 2026-09-30 10:00 in a UTC calendar.
@MainActor
enum HistoryFixture {
    /// 2026-09-30T10:00:00Z.
    static let nowSeconds: TimeInterval = 1_790_762_400
    /// 2026-09-29T00:00:00Z, the start of yesterday.
    static let yesterdaySeconds: TimeInterval = 1_790_640_000
    /// 2026-09-01T00:00:00Z, an older day.
    static let olderDaySeconds: TimeInterval = 1_788_220_800
    static let year = 2_026
    static let reviewNumber = 2
    /// A duration under a minute, and one of 2m 14s.
    static let shortSeconds = 42
    static let longMinutes = 2
    static let longRemainder = 14
    static let secondsPerMinute = 60

    static let calendar: Calendar = {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC") ?? gregorian.timeZone
        return gregorian
    }()

    static let locale = Locale(identifier: "en_US")
    static let now = Date(timeIntervalSince1970: nowSeconds)
    static let yesterday = Date(timeIntervalSince1970: yesterdaySeconds)
    static let olderDay = Date(timeIntervalSince1970: olderDaySeconds)
    static let digest = job("Digest", number: 1)
    static let review = job("Review", number: reviewNumber)

    /// 2026-`month`-`day` `hour`:`minute`:`second` UTC.
    static func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int) -> Date {
        let components = DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second,
        )
        guard let date = calendar.date(from: components) else {
            preconditionFailure("fixture date \(month)-\(day) is invalid")
        }
        return date
    }

    /// 2026-`month`-`day` `hour`:`minute` UTC.
    static func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        date(month, day, hour, minute, 0)
    }

    static func job(_ name: String, number: Int) -> Job {
        let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number)) ?? UUID()
        return Job(
            name: name,
            directory: Fixture.directory,
            prompt: Fixture.prompt,
            schedule: Fixture.schedule,
            createdAt: Fixture.createdAt,
            id: id,
        )
    }

    /// A run of `job` that started at `start`, ended in `outcome` after `seconds` (still
    /// running when `nil`), and reported `cost`.
    static func run(
        _ job: Job,
        at start: Date,
        _ outcome: RunOutcome,
        seconds: TimeInterval?,
        cost: Decimal?,
    ) -> Run {
        var run = Run(job: job, trigger: .scheduled, startedAt: start, scheduledAt: start)
        run.outcome = outcome
        run.endedAt = seconds.map { start + $0 }
        run.costUSD = cost
        return run
    }

    /// A run of `job` that started at `start` and ended in `outcome` a minute later.
    static func run(_ job: Job, at start: Date, _ outcome: RunOutcome) -> Run {
        run(job, at: start, outcome, seconds: TimeInterval(secondsPerMinute), cost: nil)
    }

    /// A run of `job` that started at `start` and succeeded a minute later.
    static func run(_ job: Job, at start: Date) -> Run {
        run(job, at: start, .succeeded)
    }

    static func model(_ store: any RunStoring, now date: Date) -> HistoryModel {
        HistoryModel(store: store, calendar: calendar, locale: locale) { date }
    }

    static func model(_ store: any RunStoring) -> HistoryModel {
        model(store, now: now)
    }

    static func loaded(_ runs: [Run]) -> (HistoryModel, FakeRunStore) {
        let store = FakeRunStore(runs: runs)
        let history = model(store)
        history.reload()
        return (history, store)
    }
}
