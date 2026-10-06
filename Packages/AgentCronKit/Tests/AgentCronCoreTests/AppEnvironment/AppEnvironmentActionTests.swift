import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// What the user does reaches the scheduler: a saved job re-arms the timer, a deleted
/// job's run stops, Run Now and Stop act, and the main window switches the activation
/// policy (issue #28, `docs/architecture.md` › Core flows, ADR-0001).
@MainActor
@Suite("AppEnvironment — user actions")
struct AppEnvironmentActionTests {
    /// The fixture launched with its job selected in the Jobs screen's editor.
    private static func editing() async throws -> (AppEnvironmentFixture, JobEditorModel) {
        let fixture = AppEnvironmentFixture()
        await fixture.launch()
        fixture.environment.jobList.load()
        fixture.environment.jobList.select(jobID: Fixture.jobID)
        return try (fixture, #require(fixture.environment.jobList.editor))
    }

    /// Starts the job's run by hand and waits until it is going.
    private static func startRun(in fixture: AppEnvironmentFixture) async {
        fixture.environment.runNow(jobID: Fixture.jobID)
        _ = await fixture.until { fixture.preventer.activeCount == 1 }
    }

    @Test
    func `saving a job arms the timer for its new time`() async throws {
        let (fixture, editor) = try await Self.editing()

        editor.timeChanged(at: 0, to: Fixture.time(9, 30))
        #expect(editor.save() == .saved)

        #expect(fixture.events.armedDates.last == DispatcherFixture.at(9, 30))
        await fixture.cleanUp()
    }

    @Test
    func `the first job that notifies asks for notification permission`() async throws {
        var scenario = AppScenario(authorization: .notDetermined)
        scenario.edit = { $0.notify = .never }
        let fixture = AppEnvironmentFixture(scenario)
        await fixture.launch()
        #expect(fixture.notifier.promptsShown == 0)
        fixture.environment.jobList.load()
        fixture.environment.jobList.select(jobID: Fixture.jobID)
        let editor = try #require(fixture.environment.jobList.editor)

        editor.notifyChosen(.failuresOnly)
        editor.save()
        await fixture.settle()

        #expect(fixture.notifier.promptsShown == 1)
        #expect(fixture.environment.notifications.authorizationState == .authorized)
        await fixture.cleanUp()
    }

    @Test
    func `saving a job while it runs leaves the run going`() async throws {
        let (fixture, editor) = try await Self.editing()
        await Self.startRun(in: fixture)

        editor.nameChanged(to: "Morning digest")
        editor.save()

        #expect(fixture.environment.dispatcher.runningJobIDs == [Fixture.jobID])
        await fixture.cleanUp()
    }

    @Test
    func `deleting a running job stops its run`() async {
        let fixture = AppEnvironmentFixture()
        await fixture.launch()
        fixture.environment.jobList.load()
        await Self.startRun(in: fixture)

        fixture.environment.jobList.delete(jobID: Fixture.jobID)
        await fixture.settle()

        #expect(fixture.recorded.map(\.outcome) == [.stopped])
        #expect(fixture.preventer.activeCount == 0)
        #expect(fixture.environment.history.isDeleted(jobID: Fixture.jobID))
        // Nothing is left to fire, so the timer waits out the longest wait.
        #expect(fixture.events.armedDates.last == DispatcherFixture.at(9, 0)
            .addingTimeInterval(AppEnvironment.longestTimerWait))
        await fixture.cleanUp()
    }

    @Test
    func `the Job menu's Run Now and Stop act on the selected job`() async {
        let fixture = AppEnvironmentFixture()
        await fixture.launch()
        let navigation = fixture.environment.navigation
        navigation.select(section: .jobs)
        navigation.select(jobID: Fixture.jobID)

        navigation.runSelectedJobNow()
        #expect(await fixture.until { fixture.preventer.activeCount == 1 })
        #expect(fixture.environment.dispatcher.runningRuns.first?.trigger == .manual)

        navigation.stopSelectedJob()
        await fixture.settle()

        #expect(fixture.recorded.map(\.outcome) == [.stopped])
        await fixture.cleanUp()
    }

    @Test
    func `stop by run identifier stops that run, and stopping an idle job does nothing`(
    ) async throws {
        let fixture = AppEnvironmentFixture()
        await fixture.launch()
        fixture.environment.stopJob(jobID: Fixture.jobID)
        #expect(fixture.recorded.isEmpty)
        await Self.startRun(in: fixture)
        let run = try #require(fixture.environment.dispatcher.runningRuns.first)

        fixture.environment.stop(runID: run.id)
        await fixture.settle()

        #expect(fixture.recorded.map(\.id) == [run.id])
        #expect(fixture.recorded.first?.outcome == .stopped)
        await fixture.cleanUp()
    }

    @Test
    func `the main window opening and closing switches the activation policy`() async {
        let fixture = AppEnvironmentFixture()
        await fixture.launch()

        fixture.environment.mainWindowOpened()
        await fixture.settle()
        #expect(fixture.activation.policy == .regular)
        #expect(fixture.environment.lifecycle.isMainWindowOpen)

        fixture.environment.mainWindowClosed()
        #expect(fixture.activation.calls == [.regular, .accessory])
        await fixture.cleanUp()
    }

    @Test
    func `opening the main window reads History and the notification permission again`(
    ) async {
        let fixture = AppEnvironmentFixture(AppScenario(authorization: .denied))
        await fixture.launch()
        #expect(fixture.environment.notifications.authorizationState == .denied)
        fixture.notifier.userChangedAuthorization(to: .authorized)
        let stored = Run(
            job: fixture.job,
            trigger: .manual,
            startedAt: DispatcherFixture.at(AppEnvironmentFixture.lastCheckHour, 0),
            id: Fixture.runID,
        ).stopped(at: DispatcherFixture.at(AppEnvironmentFixture.lastCheckHour, 1))
        try? fixture.runStore.save(stored)

        fixture.environment.mainWindowOpened()
        await fixture.settle()

        #expect(fixture.environment.notifications.authorizationState == .authorized)
        #expect(fixture.environment.history.runs.map(\.id) == [Fixture.runID])
        await fixture.cleanUp()
    }

    @Test
    func `a run whose agent check has not answered stays listed through a reload`(
    ) async throws {
        // The check hangs until its timeout, so the run is going but not yet saved.
        let fixture = AppEnvironmentFixture(AppScenario(resolve: .runsUntilTerminated))
        fixture.environment.launch()
        fixture.environment.runNow(jobID: Fixture.jobID)
        let running = try #require(fixture.environment.dispatcher.runningRuns.first)
        #expect(fixture.recorded.isEmpty)

        fixture.environment.mainWindowOpened()
        fixture.environment.jobList.load()
        fixture.environment.jobList.select(jobID: Fixture.jobID)
        fixture.environment.jobList.editor?.nameChanged(to: "Morning digest")
        fixture.environment.jobList.editor?.save()

        #expect(fixture.environment.history.runs.map(\.id) == [running.id])
        #expect(fixture.environment.popover.runs.map(\.id) == [running.id])
        #expect(fixture.environment.popover.runningJobIDs == [Fixture.jobID])
        // Stops the run and lets General's hanging check time out, so nothing outlives
        // the test; the check may not be waiting yet, so time moves until it answers.
        fixture.environment.stop(runID: running.id)
        _ = await fixture.until {
            fixture.runnerClock.advance(by: .seconds(AppEnvironmentFixture.secondsPerHour))
            return fixture.environment.general.agent != nil
        }
        await fixture.cleanUp()
    }
}
