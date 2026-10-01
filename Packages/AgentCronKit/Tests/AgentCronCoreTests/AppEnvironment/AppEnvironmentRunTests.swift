import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// A finished run reaches notifications, History, and the popover (issue #28 REQ-004),
/// and a click on its notification opens History on it (REQ-005).
@MainActor
@Suite("AppEnvironment — finished runs")
struct AppEnvironmentRunTests {
    private typealias Samples = ClaudeCodeResultSamples

    /// A fixture whose job's command line exits with `code` and prints `stdout`,
    /// launched, with its 10:00 run finished.
    private static func ran(_ code: Int32, _ stdout: String) async -> AppEnvironmentFixture {
        let fixture = AppEnvironmentFixture(AppScenario(agent: DispatcherFixture.exits(
            code,
            stdout,
        )))
        await fixture.launch()
        fixture.advance(hours: 1)
        _ = await fixture.until { !fixture.recorded.isEmpty }
        await fixture.settle()
        return fixture
    }

    @Test
    func `a finished run shows in the popover and History`() async throws {
        let fixture = await Self.ran(0, Samples.success)
        let run = try #require(fixture.recorded.first)

        #expect(run.outcome == .succeeded)
        #expect(fixture.environment.history.runs.map(\.id) == [run.id])
        #expect(fixture.environment.history.runs.first?.outcome == .succeeded)
        #expect(fixture.environment.popover.runs.map(\.id) == [run.id])
        #expect(fixture.environment.popover.runs.first?.outcome == .succeeded)
        #expect(fixture.environment.popover.runningJobIDs.isEmpty)
        await fixture.cleanUp()
    }

    @Test
    func `a failed run notifies under the job's setting, a succeeded one does not`() async {
        let failed = await Self.ran(1, "")
        #expect(failed.recorded.map(\.outcome) == [.failed])
        #expect(failed.notifier.posted.map(\.runID) == failed.recorded.map(\.id))
        await failed.cleanUp()

        let succeeded = await Self.ran(0, Samples.success)
        #expect(succeeded.notifier.posted.isEmpty)
        await succeeded.cleanUp()
    }

    @Test
    func `a run is shown running in History and the popover while it runs`() async throws {
        let fixture = AppEnvironmentFixture()
        await fixture.launch()

        fixture.advance(hours: 1)

        #expect(await fixture.until { !fixture.environment.dispatcher.runningRuns.isEmpty })
        let running = try #require(fixture.environment.dispatcher.runningRuns.first)
        #expect(fixture.environment.history.runs.map(\.id) == [running.id])
        #expect(fixture.environment.popover.runs.map(\.id) == [running.id])
        #expect(fixture.environment.popover.runningJobIDs == [Fixture.jobID])
        await fixture.cleanUp()
    }

    @Test
    func `a job whose folder is gone is recorded skipped, notified, and opens History`(
    ) async throws {
        let fixture = AppEnvironmentFixture()
        await fixture.launch()
        try FileManager.default.removeItem(at: fixture.directory)

        fixture.advance(hours: 1)

        #expect(await fixture.until { !fixture.recorded.isEmpty })
        await fixture.settle()
        let run = try #require(fixture.recorded.first)
        #expect(run.skipReason == .directoryMissing)
        #expect(fixture.notifier.posted.map(\.runID) == [run.id])

        fixture.notifier.click(runID: run.id)

        #expect(await fixture.until { fixture.environment.isMainWindowRequested })
        #expect(fixture.environment.navigation.section == .history)
        #expect(fixture.environment.navigation.selectedRunID == run.id)
        #expect(fixture.environment.history.selectedRunID == run.id)
        #expect(fixture.environment.history.detail?.run.id == run.id)
        fixture.environment.mainWindowRequestHandled()
        #expect(!fixture.environment.isMainWindowRequested)
        await fixture.cleanUp()
    }

    @Test
    func `times missed while away post one notification`() async {
        let fixture = AppEnvironmentFixture(AppScenario(
            // Three days away: 10:00 on each of them was missed, and the last is past the
            // grace period too.
            now: DispatcherFixture.at(AppEnvironmentFixture.launchHour, 0)
                .addingTimeInterval(3 * AppEnvironmentFixture.secondsPerDay),
            lastCheckedAt: DispatcherFixture.at(AppEnvironmentFixture.launchHour, 0),
        ))

        await fixture.launch()
        await fixture.settle()

        #expect(fixture.recorded.count == 3)
        #expect(fixture.recorded.allSatisfy { $0.skipReason == .missed })
        #expect(fixture.notifier.posted.count == 1)
        await fixture.cleanUp()
    }

    @Test
    func `an agent the login shell cannot find raises the popover's banner`() async {
        let fixture = AppEnvironmentFixture(AppScenario(resolve: DispatcherFixture.notResolved))
        await fixture.launch()
        fixture.environment.popover.agentAvailabilityChanged(.available(path: "/x", version: "1"))

        fixture.advance(hours: 1)

        #expect(await fixture.until { !fixture.recorded.isEmpty })
        #expect(fixture.recorded.first?.skipReason == .agentNotFound)
        #expect(fixture.environment.popover.isAgentMissing)
        await fixture.cleanUp()
    }
}
