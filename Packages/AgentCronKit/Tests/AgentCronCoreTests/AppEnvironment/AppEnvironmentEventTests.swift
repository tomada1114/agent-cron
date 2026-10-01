import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// System events tick the scheduler and arm the timer again (issue #28 REQ-002), and the
/// running set holds the keep-awake assertion (REQ-003).
@MainActor
@Suite("AppEnvironment — system events")
struct AppEnvironmentEventTests {
    private typealias Samples = ClaudeCodeResultSamples

    private static let tomorrowTen = DispatcherFixture.at(DispatcherFixture.tenHour, 0)
        .addingTimeInterval(AppEnvironmentFixture.secondsPerDay)

    @Test
    func `the armed timer firing starts the due job and arms the next fire date`() async {
        let fixture = AppEnvironmentFixture(AppScenario(agent: DispatcherFixture.exits(
            0,
            Samples.success,
        )))
        await fixture.launch()

        fixture.advance(hours: 1)

        #expect(await fixture.until { fixture.events.armedDates.count == 2 })
        await fixture.settle()
        #expect(fixture.recorded.map(\.outcome) == [.succeeded])
        #expect(fixture.recorded.first?.trigger == .scheduled)
        #expect(fixture.events.armedDates.last == Self.tomorrowTen)
        await fixture.cleanUp()
    }

    @Test
    func `a wake catches up the time missed while asleep`() async {
        let fixture = AppEnvironmentFixture(AppScenario(agent: DispatcherFixture.exits(
            0,
            Samples.success,
        )))
        await fixture.launch()
        // Asleep through 10:00: the timer's clock stops with the Mac in this fake, so only
        // the wall clock moves.
        fixture.wallClock.advance(by: .seconds(AppEnvironmentFixture.secondsPerHour + 600))

        fixture.events.send(.didWake)

        #expect(await fixture.until { fixture.events.armedDates.count == 2 })
        await fixture.settle()
        #expect(fixture.recorded.map(\.trigger) == [.catchUp])
        #expect(fixture.events.armedDates.last == Self.tomorrowTen)
        await fixture.cleanUp()
    }

    @Test(arguments: [SystemEvent.clockChanged, .timeZoneChanged])
    func `a clock or time zone change checks the schedule and arms the timer again`(
        event: SystemEvent,
    ) async {
        let fixture = AppEnvironmentFixture()
        await fixture.launch()
        // The clock was set forward past 10:00; the timer, counting elapsed time, has not
        // fired.
        fixture.wallClock.advance(by: .seconds(AppEnvironmentFixture.secondsPerHour + 60))

        fixture.events.send(event)

        #expect(await fixture.until { fixture.events.armedDates.count == 2 })
        #expect(fixture.environment.dispatcher.runningJobIDs == [Fixture.jobID])
        #expect(fixture.events.armedDates.last == Self.tomorrowTen)
        await fixture.cleanUp()
    }

    @Test
    func `going to sleep checks nothing and arms nothing`() async {
        let fixture = AppEnvironmentFixture()
        await fixture.launch()
        let lastCheck = fixture.jobStore.document.lastCheckedAt
        fixture.wallClock.advance(by: .seconds(AppEnvironmentFixture.secondsPerHour / 2))

        fixture.events.send(.willSleep)
        fixture.events.send(.timeZoneChanged)

        // Events arrive in order: once the time-zone change has armed the timer, the
        // sleep before it was handled too — and armed nothing, checked nothing.
        #expect(await fixture.until { fixture.events.armedDates.count >= 2 })
        #expect(fixture.events.armedDates.count == 2)
        #expect(lastCheck == DispatcherFixture.at(AppEnvironmentFixture.launchHour, 0))
        #expect(fixture.jobStore.document.lastCheckedAt == DispatcherFixture.at(9, 30))
        await fixture.cleanUp()
    }

    @Test
    func `a running job holds the keep-awake assertion until its run ends`() async {
        let fixture = AppEnvironmentFixture()
        await fixture.launch()
        #expect(fixture.preventer.activeCount == 0)

        fixture.advance(hours: 1)

        #expect(await fixture.until { !fixture.environment.dispatcher.runningRuns.isEmpty })
        #expect(fixture.preventer.activeReasons == [KeepAwakeController.runningJobsReason])
        #expect(fixture.environment.popover.statusSymbol == .running)
        #expect(fixture.environment.jobList.runningJobIDs == [Fixture.jobID])

        fixture.environment.stopJob(jobID: Fixture.jobID)
        await fixture.settle()

        #expect(fixture.preventer.activeCount == 0)
        #expect(fixture.environment.popover.statusSymbol == .idle)
        #expect(fixture.recorded.map(\.outcome) == [.stopped])
        await fixture.cleanUp()
    }
}
