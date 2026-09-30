import AgentCronCore
import Foundation

/// Fixed inputs for the notification suites: the issue's worked examples, a UTC
/// calendar, and English, so no test reads the clock, the Mac's time zone, or its
/// language.
enum NotificationFixture {
    /// 2023-11-14 22:00:00 UTC — "22:00" in the worked examples.
    static let tenPMSince1970: TimeInterval = 1_699_999_200
    /// 2023-11-15 09:00:00 UTC.
    static let nineAMSince1970: TimeInterval = 1_700_038_800
    /// How long every finished run below took, unless a test says otherwise.
    static let runLength: TimeInterval = 60
    /// The 30-minute timeout of the first worked example, in seconds.
    static let thirtyMinutes: TimeInterval = 1_800

    static let tenPM = Date(timeIntervalSince1970: tenPMSince1970)
    static let nineAM = Date(timeIntervalSince1970: nineAMSince1970)
    static let otherRunID = UUID(uuidString: "0000AAAA-BBBB-CCCC-DDDD-EEEEFFFF0000") ?? UUID()

    static let calendar: Calendar = {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return utc
    }()

    /// ``Fixture/job()`` with its finished runs notifying per `notify`.
    static func job(notify: NotifyPolicy) -> Job {
        job(named: Fixture.name, notify: notify)
    }

    /// A job named `name` whose finished runs notify per `notify`.
    static func job(named name: String, notify: NotifyPolicy) -> Job {
        var job = Fixture.job()
        job.name = name
        job.notify = notify
        return job
    }

    /// A scheduled run of `job` for 22:00 that ended with `outcome`.
    static func finishedRun(of job: Job, outcome: RunOutcome) -> Run {
        finishedRun(of: job, outcome: outcome, startedAt: tenPM, id: Fixture.runID)
    }

    /// A scheduled run of `job` for `startedAt` that ended with `outcome`.
    static func finishedRun(of job: Job, outcome: RunOutcome, startedAt: Date, id: UUID) -> Run {
        var run = Run(
            job: job,
            trigger: .scheduled,
            startedAt: startedAt,
            scheduledAt: startedAt,
            id: id,
        )
        run.outcome = outcome
        if outcome != .running {
            run.endedAt = startedAt.addingTimeInterval(runLength)
        }
        return run
    }

    /// The first worked example: "Nightly review" (failures only) times out at 22:00.
    static func nightlyReviewTimedOut() -> Run {
        var run = finishedRun(
            of: job(named: "Nightly review", notify: .failuresOnly),
            outcome: .timedOut,
        )
        run.endedAt = tenPM.addingTimeInterval(thirtyMinutes)
        run.failureReason = "Timed out after 30 minutes"
        return run
    }

    /// The second worked example: "RSS digest" (failures only) succeeds at 09:00.
    static func rssDigestSucceeded() -> Run {
        var run = finishedRun(
            of: job(named: "RSS digest", notify: .failuresOnly),
            outcome: .succeeded,
            startedAt: nineAM,
            id: Fixture.runID,
        )
        run.resultText = "Wrote news.html with 12 stories."
        return run
    }
}
