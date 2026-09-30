import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// The times one check records missed notify once per job, not once per time (issue #50),
/// while every other skip and every failure still notifies on its own.
@MainActor
@Suite("Missed-run notifications")
struct MissedRunNotificationTests {
    private static let daySeconds: TimeInterval = 86_400
    private static let weekAway = 7

    private static func controller(over notifier: FakeRunNotifier) -> RunNotificationController {
        RunNotificationController(
            notifier: notifier,
            locale: .english,
            calendar: NotificationFixture.calendar,
        )
    }

    private static func authorized() -> FakeRunNotifier {
        FakeRunNotifier(authorization: .authorized, promptAnswer: .authorized)
    }

    /// `count` runs of `job` skipped for `reason`, an hour apart from 22:00 back.
    private static func skipped(
        _ count: Int,
        of job: Job,
        reason: SkipReason,
    ) -> [Run] {
        (0 ..< count).map { index in
            var run = NotificationFixture.finishedRun(
                of: job,
                outcome: .skipped,
                startedAt: NotificationFixture.tenPM.addingTimeInterval(-3_600 * Double(index)),
                id: UUID(),
            )
            run.skipReason = reason
            return run
        }
    }

    // MARK: - The close condition

    @Test
    func `one wake after a week away posts at most one notification for the job`() async {
        let fixture = DispatcherFixture(DispatcherScenario(
            times: [(DispatcherFixture.nineHour, 0), (DispatcherFixture.tenHour, 0)],
            now: DispatcherFixture.at(12, 0),
            lastCheckedAt: DispatcherFixture.at(12, 0)
                .addingTimeInterval(-Self.daySeconds * Double(Self.weekAway)),
            agent: DispatcherFixture.exits(0, ClaudeCodeResultSamples.success),
        ) { job in
            job.notify = .failuresOnly
            job.updatedAt = .distantPast
        })
        defer { fixture.cleanUp() }
        let reports = DispatchReports(listeningTo: fixture.dispatcher)
        var batches: [[Run]] = []
        fixture.dispatcher.onRunsMissed = { batches.append($0) }

        fixture.dispatcher.didWake(now: DispatcherFixture.at(12, 0))
        await fixture.dispatcher.waitForRuns()

        let notifier = Self.authorized()
        let controller = Self.controller(over: notifier)
        for run in reports.finished {
            await controller.runFinished(run)
        }
        for batch in batches {
            await controller.runsMissed(batch)
        }

        let missed = fixture.recorded.filter { $0.skipReason == .missed }
        #expect(missed.count > 1)
        #expect(batches.count == 1)
        #expect(batches.first?.count == missed.count)
        #expect(notifier.posted.count == 1)
        #expect(notifier.posted.first?
            .title == "Missed \(missed.count) runs of \(fixture.job.name)")
    }

    @Test
    func `a check that misses nothing reports no missed batch`() async {
        let fixture = DispatcherFixture(DispatcherScenario(
            agent: DispatcherFixture.exits(0, ClaudeCodeResultSamples.success),
        ))
        defer { fixture.cleanUp() }
        var batches: [[Run]] = []
        fixture.dispatcher.onRunsMissed = { batches.append($0) }

        fixture.dispatcher.didWake(now: DispatcherFixture.at(DispatcherFixture.tenHour, 0))
        await fixture.dispatcher.waitForRuns()

        #expect(batches.isEmpty)
    }

    // MARK: - Coalescing

    @Test
    func `many missed runs of one job read as one notification about the latest`() async throws {
        let notifier = Self.authorized()
        let runs = Self.skipped(
            14,
            of: NotificationFixture.job(named: "Nightly review", notify: .failuresOnly),
            reason: .missed,
        )
        await Self.controller(over: notifier).runsMissed(runs)

        let content = try #require(notifier.posted.first)
        #expect(notifier.posted.count == 1)
        #expect(content.title == "Missed 14 runs of Nightly review")
        #expect(content.subtitle == "· 22:00")
        #expect(content.runID == runs.first?.id)
    }

    @Test
    func `one missed run reads like any skipped run`() async {
        let notifier = Self.authorized()
        let runs = Self.skipped(
            1,
            of: NotificationFixture.job(named: "Nightly review", notify: .failuresOnly),
            reason: .missed,
        )
        await Self.controller(over: notifier).runsMissed(runs)
        #expect(notifier.posted.map(\.title) == ["Nightly review was skipped"])
    }

    @Test
    func `missed runs of two jobs post one notification each`() async {
        let notifier = Self.authorized()
        var second = Job(
            name: "RSS digest",
            directory: Fixture.directory,
            prompt: Fixture.prompt,
            schedule: Fixture.schedule,
            createdAt: Fixture.createdAt,
            id: NotificationFixture.otherRunID,
        )
        second.notify = .failuresOnly
        let runs = Self.skipped(
            3,
            of: NotificationFixture.job(named: "Nightly review", notify: .failuresOnly),
            reason: .missed,
        )
            + Self.skipped(2, of: second, reason: .missed)
        await Self.controller(over: notifier).runsMissed(runs)
        #expect(notifier.posted.map(\.title) == [
            "Missed 3 runs of Nightly review",
            "Missed 2 runs of RSS digest",
        ])
    }

    @Test
    func `missed runs of a job that never notifies post nothing`() async {
        let notifier = Self.authorized()
        await Self.controller(over: notifier).runsMissed(
            Self.skipped(3, of: NotificationFixture.job(notify: .never), reason: .missed),
        )
        #expect(notifier.posted.isEmpty)
        #expect(NotificationPolicy.missedContent(
            for: [],
            locale: .english,
            calendar: NotificationFixture.calendar,
        ) == nil)
    }

    @Test
    func `a missed run reported one by one posts nothing, since its batch notifies`() async {
        let notifier = Self.authorized()
        let controller = Self.controller(over: notifier)
        for run in Self.skipped(
            3,
            of: NotificationFixture.job(notify: .failuresOnly),
            reason: .missed,
        ) {
            await controller.runFinished(run)
        }
        #expect(notifier.posted.isEmpty)
    }

    // MARK: - Everything else stays one by one

    @Test(arguments: [SkipReason.stillRunning, .directoryMissing, .agentNotFound])
    func `every other skip still notifies one by one`(reason: SkipReason) async {
        let notifier = Self.authorized()
        let controller = Self.controller(over: notifier)
        let runs = Self.skipped(
            3,
            of: NotificationFixture.job(notify: .failuresOnly),
            reason: reason,
        )
        for run in runs {
            await controller.runFinished(run)
        }
        await controller.runsMissed(runs)
        #expect(notifier.posted.map(\.runID) == runs.map(\.id))
    }

    @Test(arguments: [RunOutcome.failed, .timedOut])
    func `failures still notify one by one`(outcome: RunOutcome) async {
        let notifier = Self.authorized()
        let controller = Self.controller(over: notifier)
        let job = NotificationFixture.job(notify: .failuresOnly)
        let runs = (0 ..< 3).map { index in
            NotificationFixture.finishedRun(
                of: job,
                outcome: outcome,
                startedAt: NotificationFixture.tenPM.addingTimeInterval(Double(index) * 60),
                id: UUID(),
            )
        }
        for run in runs {
            await controller.runFinished(run)
        }
        #expect(notifier.posted.map(\.runID) == runs.map(\.id))
    }
}
