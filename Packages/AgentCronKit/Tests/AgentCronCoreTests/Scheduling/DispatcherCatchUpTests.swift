import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// A wake or a launch: times missed since the last check coalesce into at most one
/// catch-up run, the rest are recorded missed, and the last check moves on (issue #13
/// REQ-004, REQ-007; requirements §3.2; docs/product/ux-flows.md F3).
@MainActor
@Suite("Dispatcher — catch-up and the last check")
struct DispatcherCatchUpTests {
    private static let success = DispatcherFixture.exits(0, ClaudeCodeResultSamples.success)

    @Test
    func `a time missed less than an hour ago runs once as a catch-up`() async {
        // Issue #13's first example.
        let fixture = DispatcherFixture(DispatcherScenario(
            now: DispatcherFixture.at(10, 30),
            agent: Self.success,
        ))
        defer { fixture.cleanUp() }

        fixture.dispatcher.didWake(now: DispatcherFixture.at(10, 30))
        await fixture.dispatcher.waitForRuns()

        #expect(fixture.recorded.count == 1)
        let run = fixture.recorded.first
        #expect(run?.trigger == .catchUp)
        #expect(run?.scheduledAt == DispatcherFixture.at(10, 0))
        #expect(run?.startedAt == DispatcherFixture.at(10, 30))
        #expect(run?.outcome == .succeeded)
        #expect(fixture.launches.count == 1)
    }

    @Test
    func `a time missed more than an hour ago is recorded missed and not run`() async {
        // Issue #13's second example.
        let fixture = DispatcherFixture(DispatcherScenario(
            now: DispatcherFixture.at(11, 30),
            agent: Self.success,
        ))
        defer { fixture.cleanUp() }

        fixture.dispatcher.didWake(now: DispatcherFixture.at(11, 30))
        await fixture.dispatcher.waitForRuns()

        #expect(fixture.recorded.count == 1)
        let run = fixture.recorded.first
        #expect(run?.outcome == .skipped)
        #expect(run?.skipReason == .missed)
        #expect(run?.trigger == .catchUp)
        #expect(run?.scheduledAt == DispatcherFixture.at(10, 0))
        #expect(run?.startedAt == DispatcherFixture.at(11, 30))
        #expect(run?.endedAt == DispatcherFixture.at(11, 30))
        #expect(fixture.runner.requests.isEmpty)
        #expect(fixture.dispatcher.runningRuns.isEmpty)
    }

    @Test
    func `several missed times coalesce into one run of the latest`() async {
        let fixture = DispatcherFixture(DispatcherScenario(
            times: [(9, 0), (10, 0), (10, 30)],
            now: DispatcherFixture.at(11, 0),
            lastCheckedAt: DispatcherFixture.at(8, 55),
            agent: Self.success,
        ))
        defer { fixture.cleanUp() }

        fixture.dispatcher.didWake(now: DispatcherFixture.at(11, 0))
        await fixture.dispatcher.waitForRuns()

        let byTime = fixture.recorded
            .sorted { ($0.scheduledAt ?? .distantPast) < ($1.scheduledAt ?? .distantPast) }
        #expect(byTime.map(\.scheduledAt) == [
            DispatcherFixture.at(9, 0),
            DispatcherFixture.at(10, 0),
            DispatcherFixture.at(10, 30),
        ])
        #expect(byTime.map(\.outcome) == [.skipped, .skipped, .succeeded])
        #expect(byTime.map(\.skipReason) == [.missed, .missed, nil])
        #expect(fixture.launches.count == 1)
    }

    /// Seconds after the 10:00 time the wake happens at, and whether it still runs:
    /// the grace is an hour, inclusive.
    @Test(arguments: [
        (3_599, true),
        (3_600, true),
        (3_601, false),
    ])
    func `the grace is an hour, inclusive`(secondsLate: Int, runs: Bool) async {
        let wake = DispatcherFixture.at(10, 0).addingTimeInterval(TimeInterval(secondsLate))
        let fixture = DispatcherFixture(DispatcherScenario(now: wake, agent: Self.success))
        defer { fixture.cleanUp() }

        fixture.dispatcher.didWake(now: wake)
        await fixture.dispatcher.waitForRuns()

        #expect(fixture.recorded.map(\.outcome) == [runs ? .succeeded : .skipped])
        #expect(fixture.launches.count == (runs ? 1 : 0))
    }

    /// Seconds after the 10:00 time a check happens at, and the trigger the run gets: a
    /// time found within a minute ran on schedule, a later one is a catch-up, whether a
    /// tick or a wake found it.
    @Test(arguments: [
        (0, RunTrigger.scheduled),
        (60, .scheduled),
        (61, .catchUp),
    ])
    func `a time found within a minute is on schedule`(
        secondsLate: Int,
        trigger: RunTrigger,
    ) async {
        let now = DispatcherFixture.at(10, 0).addingTimeInterval(TimeInterval(secondsLate))
        let ticked = DispatcherFixture(DispatcherScenario(now: now, agent: Self.success))
        let woken = DispatcherFixture(DispatcherScenario(now: now, agent: Self.success))
        defer {
            ticked.cleanUp()
            woken.cleanUp()
        }

        ticked.dispatcher.tick(now: now)
        woken.dispatcher.didWake(now: now)
        await ticked.dispatcher.waitForRuns()
        await woken.dispatcher.waitForRuns()

        #expect(ticked.recorded.map(\.trigger) == [trigger])
        #expect(woken.recorded.map(\.trigger) == [trigger])
    }

    @Test
    func `a disabled job has no missed times recorded`() {
        let fixture = DispatcherFixture(DispatcherScenario(now: DispatcherFixture.at(
            11,
            30,
        )) { job in
            job.enabled = false
        })
        defer { fixture.cleanUp() }

        fixture.dispatcher.didWake(now: DispatcherFixture.at(11, 30))

        #expect(fixture.runStore.savedRuns.isEmpty)
        #expect(fixture.runner.requests.isEmpty)
    }

    @Test
    func `a time before the job was last saved is not the job's to catch up`() {
        // Saved at 10:10 with a 10:00 time: that 10:00 passed before the job had it.
        let fixture = DispatcherFixture(DispatcherScenario(
            now: DispatcherFixture.at(10, 30),
            agent: Self.success,
        ) { job in
            job.updatedAt = DispatcherFixture.at(10, 10)
        })
        defer { fixture.cleanUp() }

        fixture.dispatcher.didWake(now: DispatcherFixture.at(10, 30))

        #expect(fixture.runStore.savedRuns.isEmpty)
        #expect(fixture.runner.requests.isEmpty)
    }

    @Test
    func `a check saves the time it looked, keeping the jobs as they are`() {
        let fixture = DispatcherFixture(DispatcherScenario(times: [(11, 0)]))
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        #expect(fixture.dispatcher.lastCheckedAt == DispatcherFixture.at(10, 0))
        #expect(fixture.jobStore.document == JobsDocument(
            jobs: [fixture.job],
            lastCheckedAt: DispatcherFixture.at(10, 0),
        ))

        fixture.dispatcher.didWake(now: DispatcherFixture.at(10, 20))
        #expect(fixture.jobStore.document.lastCheckedAt == DispatcherFixture.at(10, 20))
        #expect(fixture.dispatcher.lastCheckedAt == DispatcherFixture.at(10, 20))
    }

    @Test
    func `a time is never run twice by two checks`() async {
        let fixture = DispatcherFixture(DispatcherScenario(agent: Self.success))
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        await fixture.dispatcher.waitForRuns()
        fixture.dispatcher.didWake(now: DispatcherFixture.at(10, 0).addingTimeInterval(30))
        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 1))
        await fixture.dispatcher.waitForRuns()

        #expect(fixture.recorded.count == 1)
        #expect(fixture.launches.count == 1)
    }

    @Test
    func `the first check ever catches nothing up and starts watching from now`() {
        let fixture = DispatcherFixture(DispatcherScenario(
            now: DispatcherFixture.at(10, 30),
            lastCheckedAt: nil,
        ))
        defer { fixture.cleanUp() }

        fixture.dispatcher.didWake(now: DispatcherFixture.at(10, 30))

        #expect(fixture.runStore.savedRuns.isEmpty)
        #expect(fixture.runner.requests.isEmpty)
        #expect(fixture.jobStore.document.lastCheckedAt == DispatcherFixture.at(10, 30))
    }

    @Test
    func `a clock set back does not move the last check back or rerun a time`() {
        let fixture = DispatcherFixture(DispatcherScenario(
            now: DispatcherFixture.at(9, 58),
            lastCheckedAt: DispatcherFixture.at(10, 0),
        ))
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(9, 58))

        #expect(fixture.runStore.savedRuns.isEmpty)
        #expect(fixture.jobStore.document.lastCheckedAt == DispatcherFixture.at(10, 0))
        #expect(fixture.dispatcher.lastCheckedAt == DispatcherFixture.at(10, 0))
    }

    @Test
    func `a jobs document that cannot be read is neither acted on nor saved over`() {
        let fixture =
            DispatcherFixture(DispatcherScenario(stores: StoreFailures(jobLoad: .corruptJobs)))
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))

        #expect(fixture.dispatcher.storageError == .corruptJobs)
        #expect(fixture.dispatcher.lastCheckedAt == nil)
        #expect(fixture.jobStore.savedDocuments.isEmpty)
        #expect(fixture.runStore.savedRuns.isEmpty)
        #expect(fixture.runner.requests.isEmpty)
    }

    @Test
    func `a last check that cannot be saved is still kept for this session`() {
        let fixture =
            DispatcherFixture(
                DispatcherScenario(stores: StoreFailures(jobSave: .writeFailed(code: 513))),
            )
        defer { fixture.cleanUp() }

        fixture.dispatcher.didWake(now: DispatcherFixture.at(10, 0))

        #expect(fixture.dispatcher.storageError == .writeFailed(code: 513))
        #expect(fixture.dispatcher.lastCheckedAt == DispatcherFixture.at(10, 0))
        #expect(fixture.jobStore.savedDocuments.isEmpty)
    }
}
