import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// Pre-flight: a run whose directory is gone or whose agent the login shell cannot find
/// is recorded with that reason and never launched (issue #13 REQ-005; requirements
/// §3.3; ADR-0004).
@MainActor
@Suite("Dispatcher — pre-flight")
struct DispatcherPreflightTests {
    private static let success = DispatcherFixture.exits(0, ClaudeCodeResultSamples.success)

    @Test
    func `a job whose directory was removed is recorded as such without running anything`(
    ) async throws {
        // Issue #13's fourth example.
        let fixture = DispatcherFixture(DispatcherScenario(
            times: [(9, 0)],
            now: DispatcherFixture.at(9, 0),
            lastCheckedAt: DispatcherFixture.at(8, 55),
            agent: Self.success,
        ))
        defer { fixture.cleanUp() }
        try FileManager.default.removeItem(at: fixture.directory)

        fixture.dispatcher.tick(now: DispatcherFixture.at(9, 0))
        await fixture.dispatcher.waitForRuns()

        #expect(fixture.runStore.savedRuns.count == 1)
        let run = fixture.recorded.first
        #expect(run?.outcome == .skipped)
        #expect(run?.skipReason == .directoryMissing)
        #expect(run?.trigger == .scheduled)
        #expect(run?.scheduledAt == DispatcherFixture.at(9, 0))
        #expect(run?.startedAt == DispatcherFixture.at(9, 0))
        #expect(run?.endedAt == DispatcherFixture.at(9, 0))
        #expect(run?.exitCode == nil)
        #expect(fixture.runner.requests.isEmpty)
        #expect(fixture.dispatcher.runningRuns.isEmpty)
    }

    @Test
    func `a file where the job's directory should be counts as a missing directory`() async throws {
        let fixture = DispatcherFixture(DispatcherScenario(agent: Self.success))
        defer { fixture.cleanUp() }
        try FileManager.default.removeItem(at: fixture.directory)
        try Data().write(to: fixture.directory)

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        await fixture.dispatcher.waitForRuns()

        #expect(fixture.recorded.map(\.skipReason) == [.directoryMissing])
        #expect(fixture.runner.requests.isEmpty)
    }

    @Test
    func `a job whose agent the login shell cannot find is recorded as such without launching`(
    ) async {
        let fixture = DispatcherFixture(DispatcherScenario(
            agent: Self.success,
            resolve: DispatcherFixture.notResolved,
        ))
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        fixture.wallClock.advance(by: .seconds(2))
        await fixture.dispatcher.waitForRuns()

        // Only the finished record: a run that never launched was never saved running.
        #expect(fixture.runStore.savedRuns.count == 1)
        let run = fixture.recorded.first
        #expect(run?.outcome == .skipped)
        #expect(run?.skipReason == .agentNotFound)
        #expect(run?.startedAt == DispatcherFixture.at(10, 0))
        #expect(run?.endedAt == DispatcherFixture.at(10, 0).addingTimeInterval(2))
        #expect(fixture.runner.requests.map(\.argv) == [DispatcherFixture.resolveArgv])
        #expect(fixture.launches.isEmpty)
        #expect(fixture.dispatcher.runningRuns.isEmpty)
    }

    @Test
    func `the agent is looked up in the login shell before every launch`() async {
        let fixture = DispatcherFixture(DispatcherScenario(agent: Self.success))
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        await fixture.dispatcher.waitForRuns()

        #expect(fixture.runner.requests.map(\.argv) == [
            DispatcherFixture.resolveArgv,
            DispatcherFixture.versionArgv,
            fixture.jobArgv,
        ])
    }

    @Test
    func `a lookup that cannot answer does not hold the run back`() async {
        let fixture = DispatcherFixture(DispatcherScenario(
            agent: Self.success,
            resolve: DispatcherFixture.shellFails,
        ))
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        await fixture.dispatcher.waitForRuns()

        #expect(fixture.launches.count == 1)
        #expect(fixture.recorded.map(\.outcome) == [.succeeded])
    }

    @Test
    func `a run that could not be started once launched is recorded failed`() async {
        let fixture = DispatcherFixture(DispatcherScenario(agent: DispatcherFixture.exits(
            ProcessOutcome.notLaunchedExitCode,
            "",
            stderr: "agentcron: could not start the process (error 4)\n",
        )))
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        await fixture.dispatcher.waitForRuns()

        let run = fixture.recorded.first
        #expect(run?.outcome == .failed)
        #expect(run?.exitCode == -1)
        #expect(run?.resultText == "agentcron: could not start the process (error 4)\n")
    }

    @Test
    func `runs are still started when history cannot be written`() async {
        let fixture = DispatcherFixture(DispatcherScenario(
            agent: Self.success,
            stores: StoreFailures(runSave: .writeFailed(code: 640)),
        ))
        defer { fixture.cleanUp() }
        let reports = DispatchReports(listeningTo: fixture.dispatcher)

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        await fixture.dispatcher.waitForRuns()

        #expect(fixture.launches.count == 1)
        #expect(fixture.dispatcher.storageError == .writeFailed(code: 640))
        #expect(reports.finished.map(\.outcome) == [.succeeded])
    }
}
