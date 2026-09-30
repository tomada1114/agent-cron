import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// A store that answers reads with `runs` and refuses every write.
private struct ReadOnlyRunStore: RunStoring {
    static let code = 13
    let runs: [Run]

    func save(_: Run) throws(StorageError) {
        throw .writeFailed(code: Self.code)
    }

    func runs(in interval: DateInterval) -> [Run] {
        runs.filter { interval.contains($0.startedAt) && $0.startedAt < interval.end }
    }

    func deleteRuns(olderThan _: Date) throws(StorageError) -> Int {
        throw .writeFailed(code: Self.code)
    }
}

/// Runs a quit or crash left recorded as running (issue #49).
@MainActor
@Suite("Dispatcher — recovering interrupted runs")
struct DispatcherRecoveryTests {
    private static let launch = DispatcherFixture.at(10, 0)

    private static func leftRunning(_ job: Job, startedAt: Date, number: Int) -> Run {
        Run(
            job: job,
            trigger: .scheduled,
            startedAt: startedAt,
            scheduledAt: startedAt,
            id: SequentialIDs.id(500 + number),
        )
    }

    private static func dispatcher(over store: any RunStoring) -> Dispatcher {
        let runner = FakeAgentRunner(
            behaviors: [:],
            otherwise: DispatcherFixture.resolved,
            clock: ManualClock(start: launch),
        )
        return Dispatcher(
            jobStore: FakeJobStore(),
            runStore: store,
            runner: runner,
            availability: AgentAvailabilityChecker(
                runner: runner,
                directory: FileManager.default.temporaryDirectory,
            ),
            environment: DispatchEnvironment(
                calendar: DispatcherFixture.calendar,
                now: { DispatcherFixture.at(10, 0) },
                makeRunID: { UUID() },
            ),
        )
    }

    @Test
    func `a run a previous session left running is recorded failed as interrupted`() {
        let fixture = DispatcherFixture(DispatcherScenario())
        defer { fixture.cleanUp() }
        let stale = Self.leftRunning(fixture.job, startedAt: DispatcherFixture.at(2, 0), number: 1)
        try? fixture.runStore.save(stale)

        let recovered = fixture.dispatcher.recoverInterruptedRuns(now: Self.launch)

        #expect(recovered.map(\.id) == [stale.id])
        let run = fixture.recorded.first
        #expect(fixture.recorded.count == 1)
        #expect(run?.outcome == .failed)
        #expect(run?.endedAt == Self.launch)
        #expect(run?.failureReason == Run.interruptedReason)
        #expect(run?.startedAt == stale.startedAt)
        #expect(fixture.dispatcher.storageError == nil)
    }

    @Test
    func `a run left running days ago, beyond the longest timeout, is recovered too`() {
        let fixture = DispatcherFixture(DispatcherScenario())
        defer { fixture.cleanUp() }
        let old = Self.launch.addingTimeInterval(-3 * 86_400)
        try? fixture.runStore.save(Self.leftRunning(fixture.job, startedAt: old, number: 1))

        fixture.dispatcher.recoverInterruptedRuns(now: Self.launch)

        #expect(fixture.recorded.map(\.outcome) == [.failed])
    }

    @Test
    func `a run this session is still running is left alone`() async throws {
        let fixture = DispatcherFixture(DispatcherScenario())
        defer { fixture.cleanUp() }
        try? fixture.runStore.save(
            Self.leftRunning(fixture.job, startedAt: DispatcherFixture.at(2, 0), number: 1),
        )
        let own = try #require(fixture.dispatcher.runNow(jobID: Fixture.jobID))
        let launched = await fixture.until { fixture.launches.count == 1 }
        try #require(launched)

        let recovered = fixture.dispatcher.recoverInterruptedRuns(
            now: Self.launch.addingTimeInterval(1),
        )

        #expect(recovered.count == 1)
        #expect(!recovered.contains { $0.id == own.id })
        #expect(fixture.recorded.first { $0.id == own.id }?.outcome == .running)
        #expect(fixture.dispatcher.runningRuns.map(\.id) == [own.id])
        await fixture.stopAll()
    }

    @Test
    func `finished runs are not touched and nothing is reported as finished`() {
        let fixture = DispatcherFixture(DispatcherScenario())
        defer { fixture.cleanUp() }
        let done = Self.leftRunning(fixture.job, startedAt: DispatcherFixture.at(2, 0), number: 1)
            .skipped(.missed, at: DispatcherFixture.at(2, 0))
        try? fixture.runStore.save(done)
        let reports = DispatchReports(listeningTo: fixture.dispatcher)

        #expect(fixture.dispatcher.recoverInterruptedRuns(now: Self.launch).isEmpty)
        #expect(fixture.runStore.savedRuns.count == 1)
        #expect(reports.finished.isEmpty)
    }

    @Test
    func `a store that cannot be read is logged and kept as the storage error`() {
        let dispatcher = Self.dispatcher(over: ThrowingRunStore())

        #expect(dispatcher.recoverInterruptedRuns(now: Self.launch).isEmpty)
        #expect(dispatcher.storageError == .readFailed(code: ThrowingRunStore.code))
    }

    @Test
    func `a store that refuses the save is kept as the storage error`() {
        let job = DispatcherFixture(DispatcherScenario()).job
        let stale = Self.leftRunning(job, startedAt: DispatcherFixture.at(2, 0), number: 1)
        let dispatcher = Self.dispatcher(over: ReadOnlyRunStore(runs: [stale]))

        let recovered = dispatcher.recoverInterruptedRuns(now: Self.launch)

        #expect(recovered.map(\.id) == [stale.id])
        #expect(dispatcher.storageError == .writeFailed(code: ReadOnlyRunStore.code))
    }
}
