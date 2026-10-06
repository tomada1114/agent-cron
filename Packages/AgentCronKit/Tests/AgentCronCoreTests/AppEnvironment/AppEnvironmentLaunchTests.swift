import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// Launch: the graph is built, the parts are connected, the catch-up check runs, and the
/// timer is armed for the next fire date (issue #28 REQ-001).
@MainActor
@Suite("AppEnvironment — launch")
struct AppEnvironmentLaunchTests {
    @Test
    func `construction reads, starts, and asks nothing`() async {
        let fixture = AppEnvironmentFixture()

        #expect(fixture.jobStore.loadCount == 0)
        #expect(fixture.events.openStreamCount == 0)
        #expect(fixture.events.armedDates.isEmpty)
        #expect(fixture.loginItem.registerCalls == 0)
        #expect(fixture.notifier.stateReads == 0)
        #expect(!fixture.environment.isSchedulerRunning)
        await fixture.cleanUp()
    }

    @Test
    func `launch starts the scheduler and arms the timer for the next fire date`() async {
        let fixture = AppEnvironmentFixture()

        await fixture.launch()

        #expect(fixture.environment.isSchedulerRunning)
        #expect(fixture.environment.launchError == nil)
        #expect(fixture.events.openStreamCount == 1)
        #expect(fixture.events.armedDates == [DispatcherFixture.at(DispatcherFixture.tenHour, 0)])
        // The catch-up check moved the last check to launch.
        #expect(fixture.jobStore.document.lastCheckedAt == DispatcherFixture.at(9, 0))
        await fixture.cleanUp()
    }

    @Test
    func `launch registers the login item once and reads the notification permission`() async {
        var scenario = AppScenario()
        scenario.edit = { $0.notify = .never }
        let fixture = AppEnvironmentFixture(scenario)

        await fixture.launch()

        #expect(fixture.loginItem.registerCalls == 1)
        #expect(fixture.environment.lifecycle.loginItemStatus == .enabled)
        #expect(fixture.environment.notifications.authorizationState == .authorized)
        // No stored job notifies, so nothing asks yet.
        #expect(fixture.notifier.authorizationRequests == 0)
        await fixture.cleanUp()
    }

    @Test
    func `launch with a stored notifying job asks for notification permission once`() async {
        var scenario = AppScenario()
        scenario.authorization = .notDetermined
        scenario.edit = { $0.notify = .everyRun }
        let fixture = AppEnvironmentFixture(scenario)

        await fixture.launch()

        // Issue #83: the jobs loaded at launch take the same path as a save.
        #expect(fixture.notifier.authorizationRequests == 1)
        #expect(fixture.notifier.promptsShown == 1)
        #expect(fixture.environment.notifications.authorizationState == .authorized)
        await fixture.cleanUp()
    }

    @Test
    func `a second launch does nothing more`() async {
        let fixture = AppEnvironmentFixture()

        await fixture.launch()
        await fixture.launch()

        #expect(fixture.events.openStreamCount == 1)
        #expect(fixture.events.armedDates.count == 1)
        #expect(fixture.loginItem.registerCalls == 1)
        await fixture.cleanUp()
    }

    @Test
    func `launch checks the agent and tells the popover`() async {
        let found = AppEnvironmentFixture()
        await found.launch()
        #expect(found.environment.general.agent == .available(
            path: DispatcherFixture.claudePath,
            version: "2.1.0",
        ))
        #expect(!found.environment.popover.isAgentMissing)
        await found.cleanUp()

        let missing = AppEnvironmentFixture(AppScenario(resolve: DispatcherFixture.notResolved))
        await missing.launch()
        #expect(missing.environment.general.agent == .notFound)
        #expect(missing.environment.popover.isAgentMissing)
        await missing.cleanUp()
    }

    @Test
    func `a Check Again in General updates the popover's agent banner`() async {
        let found = AppEnvironmentFixture()
        await found.launch()
        found.environment.popover.agentAvailabilityChanged(.notFound)
        await found.environment.general.checkAgain()
        #expect(!found.environment.popover.isAgentMissing)
        await found.cleanUp()

        let missing = AppEnvironmentFixture(AppScenario(resolve: DispatcherFixture.notResolved))
        await missing.launch()
        missing.environment.popover.agentAvailabilityChanged(.available(
            path: DispatcherFixture.claudePath,
            version: "2.1.0",
        ))
        await missing.environment.general.checkAgain()
        #expect(missing.environment.popover.isAgentMissing)
        await missing.cleanUp()
    }

    @Test
    func `launch recovers a run an earlier session left running, and History shows it`() async {
        let interrupted = Run(
            job: Fixture.job(),
            trigger: .scheduled,
            startedAt: DispatcherFixture.at(AppEnvironmentFixture.lastCheckHour, 0),
            scheduledAt: DispatcherFixture.at(AppEnvironmentFixture.lastCheckHour, 0),
            id: Fixture.runID,
        )
        let fixture = AppEnvironmentFixture(AppScenario(runs: [interrupted]))

        await fixture.launch()

        let recovered = fixture.recorded.first { $0.id == Fixture.runID }
        #expect(recovered?.outcome == .failed)
        #expect(fixture.environment.history.runs.map(\.id) == [Fixture.runID])
        #expect(fixture.environment.history.runs.first?.outcome == .failed)
        #expect(fixture.environment.history.lastSweepAt == DispatcherFixture.at(9, 0))
        await fixture.cleanUp()
    }

    @Test
    func `the status item shows an unseen failure from the store without the popover opening`(
    ) async {
        let failed = Run(
            job: Fixture.job(),
            trigger: .scheduled,
            startedAt: DispatcherFixture.at(AppEnvironmentFixture.lastCheckHour, 0),
            scheduledAt: nil,
            id: Fixture.runID,
        ).interrupted(at: DispatcherFixture.at(AppEnvironmentFixture.lastCheckHour, 1))
        let fixture = AppEnvironmentFixture(AppScenario(
            runs: [failed],
            popoverSeenAt: DispatcherFixture.at(AppEnvironmentFixture.lastCheckHour - 1, 0),
        ))
        #expect(!fixture.environment.popover.showsFailureDot)

        await fixture.launch()

        #expect(fixture.environment.popover.showsFailureDot)
        await fixture.cleanUp()
    }

    @Test
    func `with no enabled job the timer still fires within a day`() async {
        let fixture = AppEnvironmentFixture(AppScenario { $0.enabled = false })

        await fixture.launch()

        #expect(fixture.events.armedDates == [
            DispatcherFixture.at(9, 0).addingTimeInterval(AppEnvironment.longestTimerWait),
        ])
        await fixture.cleanUp()
    }

    @Test
    func `the timer is armed for the earliest of several times`() async {
        let fixture = AppEnvironmentFixture(AppScenario(times: [(18, 0), (9, 30), (12, 0)]))

        await fixture.launch()

        #expect(fixture.events.armedDates == [DispatcherFixture.at(9, 30)])
        await fixture.cleanUp()
    }
}
