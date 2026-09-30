import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

/// Running jobs and a manual hold at once (REQ-002 and the timer-expiry boundary), Until
/// turned off (REQ-005), and the OS refusing a hold.
/// The time limit turns a timer that never fires into a failure rather than a hang.
@MainActor
@Suite("KeepAwakeController, overlapping holds", .timeLimit(.minutes(1)))
struct KeepAwakeControllerOverlapTests {
    let fixture = KeepAwakeFixture()

    var controller: KeepAwakeController {
        fixture.controller
    }

    var preventer: FakeSleepPreventer {
        fixture.preventer
    }

    // MARK: - Both at once (REQ-002, the boundary)

    @Test
    func `a job starting inside a manual hour, and outlasting it, rides one assertion`() {
        // The issue's worked example: 1 hour chosen at 10:00, a job from 10:30 to 11:20.
        controller.chooseManualMode(.oneHour)
        #expect(preventer.activeCount == 1)

        fixture.pass(.seconds(1_800))
        controller.runningJobCountChanged(to: 1)
        #expect(preventer.activeCount == 1)

        fixture.pass(.seconds(1_800))
        #expect(controller.manualMode == .off)
        #expect(controller.isHoldingAssertion)
        #expect(preventer.activeCount == 1)

        fixture.pass(.seconds(1_200))
        controller.runningJobCountChanged(to: 0)
        #expect(preventer.activeCount == 0)
        #expect(preventer.holdRequests == [KeepAwakeFixture.keptAwakeByYou])
    }

    @Test
    func `the controller's own timer ending while a job runs keeps the assertion`() async {
        controller.runningJobCountChanged(to: 1)
        controller.chooseManualMode(.oneHour)
        fixture.clock.advance(by: .seconds(3_600))
        await controller.waitForManualTimer()
        #expect(controller.manualMode == .off)
        #expect(controller.isHoldingAssertion)
        #expect(preventer.activeCount == 1)
        #expect(preventer.holdRequests == [KeepAwakeFixture.runningJobs])
    }

    @Test
    func `choosing Off while a job runs keeps the one hold`() {
        controller.runningJobCountChanged(to: 1)
        controller.chooseManualMode(.fourHours)
        controller.chooseManualMode(.off)
        #expect(controller.isHoldingAssertion)
        #expect(preventer.activeCount == 1)
        #expect(preventer.holdRequests == [KeepAwakeFixture.runningJobs])
    }

    // MARK: - Until turned off (REQ-005)

    @Test
    func `until turned off holds with no end and no remaining time, until Off`() async {
        controller.chooseManualMode(.untilTurnedOff)
        #expect(controller.isHoldingAssertion)
        #expect(controller.manualUntil == nil)
        #expect(controller.remainingManualTime == nil)
        #expect(preventer.activeReasons == [KeepAwakeFixture.keptAwakeByYou])

        fixture.pass(.seconds(10 * 24 * 3_600))
        await controller.waitForManualTimer()
        #expect(controller.isHoldingAssertion)
        #expect(controller.manualMode == .untilTurnedOff)

        controller.chooseManualMode(.off)
        #expect(!controller.isHoldingAssertion)
        #expect(preventer.activeCount == 0)
    }

    @Test
    func `switching from a timed hold to until turned off stops the timer`() async {
        controller.chooseManualMode(.oneHour)
        controller.chooseManualMode(.untilTurnedOff)
        fixture.pass(.seconds(3_600))
        await controller.waitForManualTimer()
        #expect(controller.isHoldingAssertion)
        #expect(controller.manualMode == .untilTurnedOff)
        #expect(preventer.holdRequests.count == 1)
    }

    // MARK: - The OS refusing (error path)

    @Test
    func `a refused hold leaves nothing held, and the next change tries again`() {
        let refusing = KeepAwakeFixture(
            preventer: FakeSleepPreventer(failingWith: [.systemFailure(code: -536_870_199)]),
        )

        refusing.controller.runningJobCountChanged(to: 1)
        #expect(!refusing.controller.isHoldingAssertion)
        #expect(refusing.preventer.activeCount == 0)

        refusing.controller.runningJobCountChanged(to: 2)
        #expect(refusing.controller.isHoldingAssertion)
        #expect(refusing.preventer.holdRequests == [
            KeepAwakeFixture.runningJobs,
            KeepAwakeFixture.runningJobs,
        ])
        #expect(refusing.preventer.activeCount == 1)
    }

    @Test
    func `a refused hold is retried by refresh`() {
        let refusing =
            KeepAwakeFixture(preventer: FakeSleepPreventer(failingWith: [.systemFailure(code: 1)]))
        refusing.controller.chooseManualMode(.untilTurnedOff)
        #expect(!refusing.controller.isHoldingAssertion)
        refusing.controller.refresh()
        #expect(refusing.controller.isHoldingAssertion)
        #expect(refusing.preventer.activeReasons == [KeepAwakeFixture.keptAwakeByYou])
    }
}
