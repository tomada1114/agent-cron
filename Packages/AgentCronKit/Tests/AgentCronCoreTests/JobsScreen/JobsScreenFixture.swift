import AgentCronCore
import AgentCronTestSupport
import Foundation

/// Fixed inputs for the Jobs screen suites: a pinned "now", a UTC calendar, and jobs
/// with hand-worked next runs.
enum JobsScreenFixture {
    /// 2026-09-29T10:00:00Z, a Tuesday.
    static let nowSeconds: TimeInterval = 1_790_676_000
    /// 2026-09-29T12:00:00Z, Tuesday noon.
    static let tuesdayNoonSeconds: TimeInterval = 1_790_683_200
    /// 2026-09-30T09:00:00Z, Wednesday 09:00.
    static let wednesdayNineSeconds: TimeInterval = 1_790_758_800
    /// 2026-10-03T08:00:00Z, Saturday 08:00.
    static let saturdayEightSeconds: TimeInterval = 1_791_014_400
    /// 2026-09-29T08:20:00Z, a last check the store holds, which every write must keep.
    static let lastCheckedSeconds: TimeInterval = 1_790_670_000
    static let nineHour = Fixture.nineOClock
    static let noonHour = 12
    static let sixPMHour = 18
    static let reviewNumber = 2

    static let now = Date(timeIntervalSince1970: nowSeconds)
    static let tuesdayNoon = Date(timeIntervalSince1970: tuesdayNoonSeconds)
    static let wednesdayNine = Date(timeIntervalSince1970: wednesdayNineSeconds)
    static let saturdayEight = Date(timeIntervalSince1970: saturdayEightSeconds)
    static let lastCheckedAt = Date(timeIntervalSince1970: lastCheckedSeconds)
    static let noon = Fixture.time(noonHour, 0)

    /// A Gregorian calendar in UTC, so the dates above are the fire dates.
    static let calendar: Calendar = {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC") ?? gregorian.timeZone
        return gregorian
    }()

    /// Reads ``now``.
    static let clock: @Sendable () -> Date = { now }
    /// A folder check that finds no folder.
    static let folderGone: @Sendable (URL) -> Bool = { _ in false }

    /// Weekdays at 09:00, 12:00, 18:00: next fires Tuesday noon.
    static let digest = job(
        1,
        "RSS digest",
        days: SchedulePreset.weekdays.weekdays,
        times: [nineHour, noonHour, sixPMHour].map { ($0, 0) },
    )
    /// Weekdays at 09:00 only: next fires Wednesday 09:00.
    static let review = job(
        reviewNumber,
        "Dependabot review",
        days: SchedulePreset.weekdays.weekdays,
        times: [(nineHour, 0)],
    )

    /// A document holding `jobs` and ``lastCheckedAt``.
    static func document(_ jobs: [Job]) -> JobsDocument {
        JobsDocument(jobs: jobs, lastCheckedAt: lastCheckedAt)
    }

    /// A list over `store`, reading ``calendar`` and ``now``.
    @MainActor
    static func list(_ store: FakeJobStore) -> JobListModel {
        JobListModel(store: store, calendar: calendar, now: clock)
    }

    /// A list over a store holding `jobs`, already loaded.
    @MainActor
    static func loadedList(_ jobs: [Job]) -> (JobListModel, FakeJobStore) {
        let store = FakeJobStore(document: document(jobs))
        let loaded = list(store)
        loaded.load()
        return (loaded, store)
    }

    /// A valid, enabled job numbered `number` (its identifier) and named `name`, on
    /// `days` at `times`.
    static func job(_ number: Int, _ name: String, days: Set<Weekday>, times: [(Int, Int)]) -> Job {
        Job(
            name: name,
            directory: Fixture.directory,
            prompt: Fixture.prompt,
            schedule: Schedule(weekdays: days, times: times.map { Fixture.time($0.0, $0.1) }),
            createdAt: Fixture.createdAt,
            id: id(number),
        )
    }

    /// `job`, paused.
    static func paused(_ job: Job) -> Job {
        var paused = job
        paused.enabled = false
        return paused
    }

    /// The identifier of job `number`.
    static func id(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number)) ?? UUID()
    }
}
