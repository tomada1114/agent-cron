import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// A timer tick: due jobs start and every run is recorded twice, running and then final
/// (issue #13 REQ-001–003, REQ-008; requirements §3.2).
@MainActor
@Suite("Dispatcher — ticks")
struct DispatcherTests {
    private typealias Samples = ClaudeCodeResultSamples

    @Test
    func `a due job starts and is saved running, then with its final result`() async {
        let fixture = DispatcherFixture(DispatcherScenario(agent: DispatcherFixture.exits(
            0,
            Samples.success,
        )))
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        #expect(fixture.dispatcher.runningJobIDs == [Fixture.jobID])
        await fixture.dispatcher.waitForRuns()

        let saved = fixture.runStore.savedRuns
        #expect(saved.count == 2)
        let started = saved.first
        #expect(started?.outcome == .running)
        #expect(started?.id == SequentialIDs.id(1))
        #expect(started?.trigger == .scheduled)
        #expect(started?.scheduledAt == DispatcherFixture.at(10, 0))
        #expect(started?.startedAt == DispatcherFixture.at(10, 0))
        #expect(started?.endedAt == nil)
        #expect(fixture.launches.count == 1)
        #expect(fixture.dispatcher.runningRuns.isEmpty)
    }

    @Test
    func `a finished run keeps its outcome, exit code, cost, session, and result text`() async {
        let fixture = DispatcherFixture(DispatcherScenario(agent: DispatcherFixture.exits(
            0,
            Samples.success,
        )))
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        fixture.wallClock.advance(by: .seconds(95))
        await fixture.dispatcher.waitForRuns()

        let finished = fixture.recorded.first
        #expect(fixture.recorded.count == 1)
        #expect(finished?.outcome == .succeeded)
        #expect(finished?.exitCode == 0)
        #expect(finished?.costUSD == Decimal(string: "0.0421"))
        #expect(finished?.sessionID == "5f0c2b9e-8a41-4c37-9d7e-1b2a3c4d5e6f")
        #expect(finished?.resultText == "Wrote news.html with 12 items.")
        #expect(finished?.failureReason == nil)
        #expect(finished?.skipReason == nil)
        #expect(finished?.startedAt == DispatcherFixture.at(10, 0))
        #expect(finished?.endedAt == DispatcherFixture.at(10, 1).addingTimeInterval(35))
    }

    @Test
    func `a run the agent reports as an error is recorded failed with its reason`() async {
        let fixture = DispatcherFixture(DispatcherScenario(agent: DispatcherFixture.exits(
            1,
            Samples.errorMaxTurns,
            stderr: "Reached max turns\n",
        )))
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        await fixture.dispatcher.waitForRuns()

        let failed = fixture.recorded.first
        #expect(failed?.outcome == .failed)
        #expect(failed?.exitCode == 1)
        #expect(failed?.failureReason == "error_max_turns: Reached max turns")
        #expect(failed?.resultText == "Reached max turns\n")
    }

    @Test
    func `the run is launched with the job's command line, directory, and timeout`() async {
        let fixture = DispatcherFixture(DispatcherScenario(agent: DispatcherFixture.exits(
            0,
            Samples.success,
        )) { job in
            job.timeoutMinutes = 45
        })
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        await fixture.dispatcher.waitForRuns()

        let launch = fixture.runner.requests.last
        #expect(launch?.argv.prefix(3) == [
            "claude",
            "-p",
            "Summarize today's feeds into news.html.",
        ])
        #expect(launch?.directory == fixture.directory)
        #expect(launch?.timeout == .seconds(2_700))
    }

    @Test
    func `a job whose run is still going is recorded skipped as still running`() async {
        // Issue #13's third example: the 09:00 run holds while 12:00 comes round.
        let fixture = DispatcherFixture(DispatcherScenario(
            times: [(9, 0), (12, 0)],
            now: DispatcherFixture.at(9, 0),
            lastCheckedAt: DispatcherFixture.at(8, 55),
        ))
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(9, 0))
        let launched = await fixture.until { fixture.launches.count == 1 }
        #expect(launched)
        fixture.wallClock.advance(by: .seconds(3 * 3_600))
        fixture.dispatcher.tick(now: DispatcherFixture.at(12, 0))

        let noon = DispatcherFixture.at(12, 0)
        let skipped = fixture.runStore.savedRuns.first { run in run.scheduledAt == noon }
        #expect(skipped?.outcome == .skipped)
        #expect(skipped?.skipReason == .stillRunning)
        #expect(skipped?.trigger == .scheduled)
        #expect(skipped?.startedAt == DispatcherFixture.at(12, 0))
        #expect(skipped?.endedAt == DispatcherFixture.at(12, 0))
        #expect(fixture.dispatcher.runningRuns.map(\.scheduledAt) == [DispatcherFixture.at(9, 0)])

        await fixture.stopAll()
        #expect(fixture.launches.count == 1)
        #expect(fixture.recorded.map(\.outcome) == [.stopped, .skipped])
    }

    @Test
    func `a disabled job never starts from a tick`() async {
        let fixture = DispatcherFixture(DispatcherScenario(agent: DispatcherFixture.exits(
            0,
            Samples.success,
        )) { job in
            job.enabled = false
        })
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        await fixture.dispatcher.waitForRuns()

        #expect(fixture.dispatcher.runningRuns.isEmpty)
        #expect(fixture.runStore.savedRuns.isEmpty)
        #expect(fixture.runner.requests.isEmpty)
        #expect(fixture.jobStore.document.lastCheckedAt == DispatcherFixture.at(10, 0))
    }

    @Test
    func `a job with no time in the window does not start`() {
        let fixture = DispatcherFixture(DispatcherScenario(times: [(11, 0)]))
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))

        #expect(fixture.dispatcher.runningRuns.isEmpty)
        #expect(fixture.runStore.savedRuns.isEmpty)
        #expect(fixture.runner.requests.isEmpty)
    }

    @Test
    func `different jobs due at once run in parallel`() async {
        let fixture = DispatcherFixture(DispatcherScenario(siblings: 2))
        defer { fixture.cleanUp() }

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        let everyJob = Set([Fixture.jobID] + fixture.siblings.map(\.id))
        #expect(fixture.dispatcher.runningJobIDs == everyJob)

        // All three are launched while none has ended: none waits for another.
        let argvs = Set(([fixture.job] + fixture.siblings).map(DispatcherFixture.argv(for:)))
        let allLaunched = await fixture.until {
            argvs.isSubset(of: Set(fixture.runner.requests.map(\.argv)))
        }
        #expect(allLaunched)
        #expect(fixture.dispatcher.runningRuns.count == 3)

        await fixture.stopAll()
        #expect(fixture.recorded.map(\.outcome) == [.stopped, .stopped, .stopped])
    }

    @Test
    func `the running jobs and every finished run are reported as they change`() async {
        let fixture = DispatcherFixture(DispatcherScenario(agent: DispatcherFixture.exits(
            0,
            Samples.success,
        )))
        defer { fixture.cleanUp() }
        let reports = DispatchReports(listeningTo: fixture.dispatcher)

        fixture.dispatcher.tick(now: DispatcherFixture.at(10, 0))
        await fixture.dispatcher.waitForRuns()

        #expect(reports.runningSets == [[Fixture.jobID], []])
        #expect(reports.finished == fixture.recorded)
        #expect(reports.finished.first?.outcome == .succeeded)
    }

    @Test
    func `a skipped time is reported as finished without changing the running jobs`() {
        let fixture = DispatcherFixture(DispatcherScenario(now: DispatcherFixture.at(11, 30)))
        defer { fixture.cleanUp() }
        let reports = DispatchReports(listeningTo: fixture.dispatcher)

        fixture.dispatcher.didWake(now: DispatcherFixture.at(11, 30))

        #expect(reports.runningSets.isEmpty)
        #expect(reports.finished.map(\.skipReason) == [.missed])
    }

    @Test
    func `the live environment gives every run its own identity`() {
        let live = DispatchEnvironment.live
        let first = live.makeRunID()
        let second = live.makeRunID()
        #expect(first != second)
    }
}
