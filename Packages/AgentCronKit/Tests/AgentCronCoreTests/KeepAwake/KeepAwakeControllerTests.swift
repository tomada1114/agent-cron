import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// Running jobs (REQ-001) and timed manual holds (REQ-003, REQ-004), each on its own.
/// Their overlap, Until turned off, and the OS refusing are
/// `KeepAwakeControllerOverlapTests`.
/// The time limit turns a timer that never fires into a failure rather than a hang.
@MainActor
@Suite("KeepAwakeController", .timeLimit(.minutes(1)))
struct KeepAwakeControllerTests {
    let fixture = KeepAwakeFixture()

    var controller: KeepAwakeController {
        fixture.controller
    }

    var preventer: FakeSleepPreventer {
        fixture.preventer
    }

    // MARK: - Construction

    @Test
    func `starts idle, and constructing it holds nothing`() {
        #expect(!controller.isHoldingAssertion)
        #expect(controller.runningJobCount == 0)
        #expect(controller.manualMode == .off)
        #expect(controller.manualUntil == nil)
        #expect(controller.remainingManualTime == nil)
        #expect(preventer.holdRequests.isEmpty)
    }

    @Test
    func `the convenience initializer holds nothing either`() {
        let real = KeepAwakeController(preventer: preventer)
        #expect(!real.isHoldingAssertion)
        #expect(real.manualMode == .off)
        #expect(preventer.holdRequests.isEmpty)
    }

    @Test
    func `the assertion names are the ones pmset shows`() {
        #expect(KeepAwakeController.runningJobsReason == KeepAwakeFixture.runningJobs)
        #expect(KeepAwakeController.manualReason == KeepAwakeFixture.keptAwakeByYou)
    }

    @Test
    func `refresh with nothing to hold asks the preventer nothing`() {
        controller.refresh()
        #expect(preventer.holdRequests.isEmpty)
        #expect(preventer.activeCount == 0)
    }

    // MARK: - Running jobs (REQ-001)

    @Test
    func `the first running job holds once, named for running jobs`() {
        controller.runningJobCountChanged(to: 1)
        #expect(controller.isHoldingAssertion)
        #expect(controller.runningJobCount == 1)
        #expect(preventer.holdRequests == [KeepAwakeFixture.runningJobs])
        #expect(preventer.activeReasons == [KeepAwakeFixture.runningJobs])
    }

    @Test
    func `more running jobs never add a second hold`() {
        for count in [1, 2, 3, 1] {
            controller.runningJobCountChanged(to: count)
            #expect(preventer.activeCount == 1)
        }
        #expect(preventer.holdRequests.count == 1)
    }

    @Test
    func `the last running job ending with no manual hold releases`() {
        controller.runningJobCountChanged(to: 2)
        controller.runningJobCountChanged(to: 0)
        #expect(!controller.isHoldingAssertion)
        #expect(preventer.activeCount == 0)
    }

    @Test
    func `the same count twice changes nothing`() {
        controller.runningJobCountChanged(to: 0)
        #expect(preventer.holdRequests.isEmpty)
        controller.runningJobCountChanged(to: 1)
        controller.runningJobCountChanged(to: 1)
        #expect(preventer.holdRequests.count == 1)
        #expect(preventer.activeCount == 1)
    }

    @Test
    func `a negative running count is treated as none`() {
        controller.runningJobCountChanged(to: 1)
        controller.runningJobCountChanged(to: -1)
        #expect(controller.runningJobCount == 0)
        #expect(preventer.activeCount == 0)
    }

    // MARK: - Timed manual holds (REQ-003, REQ-004)

    @Test(arguments: [
        (KeepAwakeMode.oneHour, 3_600.0, Duration.seconds(3_600), Duration.seconds(1_800)),
        (KeepAwakeMode.fourHours, 14_400.0, Duration.seconds(14_400), Duration.seconds(12_600)),
    ])
    func `a timed choice holds until now plus its length and counts down`(
        mode: KeepAwakeMode,
        secondsUntilEnd: TimeInterval,
        remainingAtOnce: Duration,
        remainingHalfAnHourLater: Duration,
    ) {
        controller.chooseManualMode(mode)
        #expect(controller.manualMode == mode)
        #expect(controller.manualUntil == KeepAwakeFixture.tenOClock
            .addingTimeInterval(secondsUntilEnd))
        #expect(controller.remainingManualTime == remainingAtOnce)
        #expect(preventer.activeReasons == [KeepAwakeFixture.keptAwakeByYou])

        fixture.clock.advance(by: .seconds(1_800))
        #expect(controller.remainingManualTime == remainingHalfAnHourLater)
    }

    @Test
    func `one hour chosen at 10:00 holds through 10:59:59 and is released at 11:00`() {
        controller.chooseManualMode(.oneHour)

        fixture.pass(.seconds(3_599))
        #expect(controller.isHoldingAssertion)
        #expect(controller.remainingManualTime == .seconds(1))

        fixture.pass(.seconds(1))
        #expect(!controller.isHoldingAssertion)
        #expect(preventer.activeCount == 0)
        #expect(controller.manualMode == .off)
        #expect(controller.manualUntil == nil)
        #expect(controller.remainingManualTime == nil)
    }

    @Test
    func `remaining time never goes below zero before the controller looks`() {
        controller.chooseManualMode(.oneHour)
        fixture.clock.advance(by: .seconds(4_000))
        #expect(controller.remainingManualTime == .zero)
    }

    @Test
    func `the controller's own timer releases at the end, with no one calling refresh`() async {
        controller.chooseManualMode(.oneHour)
        fixture.clock.advance(by: .seconds(3_600))
        await controller.waitForManualTimer()
        #expect(!controller.isHoldingAssertion)
        #expect(controller.manualMode == .off)
        #expect(preventer.activeCount == 0)
    }

    @Test
    func `a shorter choice replaces the running timer`() async {
        controller.chooseManualMode(.fourHours)
        controller.chooseManualMode(.oneHour)
        fixture.clock.advance(by: .seconds(3_600))
        await controller.waitForManualTimer()
        #expect(!controller.isHoldingAssertion)
        #expect(preventer.holdRequests.count == 1)
    }

    @Test
    func `choosing a length again restarts it from now, on the same hold`() {
        controller.chooseManualMode(.oneHour)
        fixture.clock.advance(by: .seconds(1_800))
        controller.chooseManualMode(.oneHour)
        #expect(controller.manualUntil == KeepAwakeFixture.tenOClock.addingTimeInterval(5_400))
        #expect(controller.remainingManualTime == .seconds(3_600))
        #expect(preventer.holdRequests.count == 1)
        #expect(preventer.activeCount == 1)
    }

    @Test
    func `choosing Off releases a manual hold at once`() {
        controller.chooseManualMode(.oneHour)
        controller.chooseManualMode(.off)
        #expect(!controller.isHoldingAssertion)
        #expect(preventer.activeCount == 0)
        #expect(controller.manualUntil == nil)
        #expect(controller.remainingManualTime == nil)
    }
}
