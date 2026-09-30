import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// Stop, the timeout, and Run Now (issue #13 REQ-006; requirements §3.3).
@MainActor
@Suite("Dispatcher — stop, timeout, and Run Now")
struct DispatcherStopTests {
    private static let success = DispatcherFixture.exits(0, ClaudeCodeResultSamples.success)

    @Test
    func `stopping a launched run cancels it and records it stopped`() async throws {
        let fixture = DispatcherFixture(DispatcherScenario())
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        let launched = await fixture.until { fixture.launches.count == 1 }
        try #require(launched)
        let runID = try #require(fixture.dispatcher.runningRuns.first?.id)
        fixture.wallClock.advance(by: .seconds(40))

        #expect(fixture.dispatcher.stop(runID: runID))
        await fixture.dispatcher.waitForRuns()

        #expect(fixture.runStore.savedRuns.map(\.outcome) == [.running, .stopped])
        let run = fixture.recorded.first
        #expect(run?.id == runID)
        #expect(run?.outcome == .stopped)
        #expect(run?.exitCode == FakeAgentRunner.terminatedExitCode)
        #expect(run?.endedAt == DispatcherFixture.at(10, 0).addingTimeInterval(40))
        #expect(run?.failureReason == nil)
        #expect(fixture.dispatcher.runningRuns.isEmpty)
    }

    @Test
    func `stopping a run before it launches records it stopped and launches nothing`() async throws {
        let fixture = DispatcherFixture(DispatcherScenario(agent: Self.success))
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        let runID = try #require(fixture.dispatcher.runningRuns.first?.id)
        #expect(fixture.dispatcher.stop(runID: runID))
        await fixture.dispatcher.waitForRuns()

        #expect(fixture.runStore.savedRuns.map(\.outcome) == [.stopped])
        #expect(fixture.recorded.first?.exitCode == nil)
        #expect(fixture.launches.isEmpty)
    }

    @Test
    func `stopping a run that is not going does nothing`() async throws {
        let fixture = DispatcherFixture(DispatcherScenario(agent: Self.success))
        defer { fixture.cleanUp() }

        #expect(!fixture.dispatcher.stop(runID: SequentialIDs.id(99)))

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        let runID = try #require(fixture.dispatcher.runningRuns.first?.id)
        await fixture.dispatcher.waitForRuns()
        #expect(!fixture.dispatcher.stop(runID: runID))
        #expect(fixture.recorded.map(\.outcome) == [.succeeded])
    }

    @Test
    func `a run still going when its timeout passes is recorded timed out`() async {
        let fixture = DispatcherFixture(DispatcherScenario())
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        // The runner waits out the timeout on its own clock; advancing it again until the
        // run ends covers the moment before the runner has begun to wait.
        let ended = await fixture.until {
            fixture.runnerClock.advance(by: .seconds(1_800))
            return fixture.dispatcher.runningRuns.isEmpty
        }
        #expect(ended)
        await fixture.dispatcher.waitForRuns()

        let run = fixture.recorded.first
        #expect(run?.outcome == .timedOut)
        #expect(run?.exitCode == FakeAgentRunner.terminatedExitCode)
        #expect(run?.failureReason == nil)
        #expect(fixture.runner.requests.last?.timeout == .seconds(1_800))
    }

    @Test
    func `choosing Run Now starts the saved job by hand, with no scheduled time`() async throws {
        let fixture = DispatcherFixture(DispatcherScenario(
            now: DispatcherFixture.at(14, 20),
            agent: Self.success,
        ))
        defer { fixture.cleanUp() }

        let started = try #require(fixture.dispatcher.runNow(jobID: Fixture.jobID))
        #expect(started.outcome == .running)
        await fixture.dispatcher.waitForRuns()

        let run = fixture.recorded.first
        #expect(run?.id == started.id)
        #expect(run?.trigger == .manual)
        #expect(run?.scheduledAt == nil)
        #expect(run?.startedAt == DispatcherFixture.at(14, 20))
        #expect(run?.outcome == .succeeded)
        #expect(fixture.jobStore.savedDocuments.isEmpty)
    }

    @Test
    func `a paused job can still be run by hand`() async {
        let fixture = DispatcherFixture(DispatcherScenario(agent: Self.success) { job in
            job.enabled = false
        })
        defer { fixture.cleanUp() }

        fixture.dispatcher.runNow(jobID: Fixture.jobID)
        await fixture.dispatcher.waitForRuns()

        #expect(fixture.recorded.map(\.outcome) == [.succeeded])
    }

    @Test
    func `choosing Run Now while the job runs is recorded skipped as still running`() async {
        let fixture = DispatcherFixture(DispatcherScenario())
        defer { fixture.cleanUp() }

        fixture.dispatcher.runNow(jobID: Fixture.jobID)
        let second = fixture.dispatcher.runNow(jobID: Fixture.jobID)

        #expect(second?.outcome == .skipped)
        #expect(second?.skipReason == .stillRunning)
        #expect(second?.trigger == .manual)
        #expect(fixture.dispatcher.runningRuns.count == 1)
        await fixture.stopAll()
    }

    @Test
    func `choosing Run Now for a job that is not saved runs nothing`() {
        let fixture = DispatcherFixture(DispatcherScenario(agent: Self.success))
        defer { fixture.cleanUp() }

        #expect(fixture.dispatcher.runNow(jobID: SequentialIDs.id(42)) == nil)
        #expect(fixture.runStore.savedRuns.isEmpty)
        #expect(fixture.dispatcher.runningRuns.isEmpty)
    }

    @Test
    func `choosing Run Now with a jobs document that cannot be read runs nothing`() {
        let fixture =
            DispatcherFixture(
                DispatcherScenario(
                    stores: StoreFailures(jobLoad: .newerJobsVersion(schemaVersion: 2)),
                ),
            )
        defer { fixture.cleanUp() }

        #expect(fixture.dispatcher.runNow(jobID: Fixture.jobID) == nil)
        #expect(fixture.dispatcher.storageError == .newerJobsVersion(schemaVersion: 2))
        #expect(fixture.runner.requests.isEmpty)
    }

    @Test
    func `choosing Run Now in a directory that was removed is recorded as such`() throws {
        let fixture = DispatcherFixture(DispatcherScenario(agent: Self.success))
        defer { fixture.cleanUp() }
        try FileManager.default.removeItem(at: fixture.directory)

        let run = fixture.dispatcher.runNow(jobID: Fixture.jobID)

        #expect(run?.skipReason == .directoryMissing)
        #expect(run?.trigger == .manual)
        #expect(fixture.recorded == [run].compactMap(\.self))
        #expect(fixture.runner.requests.isEmpty)
    }
}
