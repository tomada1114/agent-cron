import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

@MainActor
@Suite("PopoverModel status and keep-awake")
struct PopoverModelStatusTests {
    typealias Fix = PopoverFixture

    @Test
    func `REQ-004 the symbol goes running, then manual hold, then idle`() throws {
        try withScratchDefaults { defaults in
            let keepAwake = KeepAwakeController(preventer: FakeSleepPreventer())
            let model = Fix.model(
                jobs: [Fix.digest],
                now: Fix.tuesday(12, 0),
                defaults: defaults,
                keepAwake: keepAwake,
            )
            #expect(model.statusSymbol == .idle)
            #expect(model.statusSymbol.symbolName == "clock")

            model.chooseKeepAwake(.untilTurnedOff)
            #expect(model.statusSymbol == .manualHold)
            #expect(model.statusSymbol.symbolName == "cup.and.saucer")

            model.runningRunsChanged(to: [Fix.run(of: Fix.digest, at: Fix.tuesday(12, 0))])
            #expect(model.statusSymbol == .running)

            model.runningRunsChanged(to: [])
            model.chooseKeepAwake(.off)
            #expect(model.statusSymbol == .idle)
        }
    }

    @Test
    func `a run reported running but not yet stored survives a load`() throws {
        try withScratchDefaults { defaults in
            let model = Fix.model(jobs: [Fix.digest], now: Fix.tuesday(12, 0), defaults: defaults)
            let running = Fix.run(of: Fix.digest, at: Fix.tuesday(12, 0))
            model.runningRunsChanged(to: [running])

            model.load()

            #expect(model.runs.contains(running))
            #expect(model.runningJobIDs == [Fix.digest.id])
        }
    }

    @Test
    func `REQ-005 a chosen mode reaches the controller and its remaining time shows`() throws {
        try withScratchDefaults { defaults in
            let keepAwake = KeepAwakeFixture()
            let model = Fix.model(
                jobs: [Fix.digest],
                now: Fix.tuesday(12, 0),
                defaults: defaults,
                keepAwake: keepAwake.controller,
            )
            #expect(model.keepAwakeMode == .off)
            #expect(model.remainingKeepAwakeTime == nil)

            model.chooseKeepAwake(.oneHour)
            #expect(keepAwake.controller.manualMode == .oneHour)
            #expect(model.keepAwakeMode == .oneHour)
            #expect(keepAwake.preventer.activeReasons == [KeepAwakeFixture.keptAwakeByYou])
            #expect(model.remainingKeepAwakeTime == .seconds(3_600))

            keepAwake.pass(.seconds(600))
            #expect(model.remainingKeepAwakeTime == .seconds(3_000))

            model.chooseKeepAwake(.fourHours)
            #expect(model.remainingKeepAwakeTime == .seconds(14_400))

            model.chooseKeepAwake(.untilTurnedOff)
            #expect(model.remainingKeepAwakeTime == nil)
            #expect(keepAwake.preventer.activeCount == 1)

            model.chooseKeepAwake(.off)
            #expect(keepAwake.preventer.activeCount == 0)
        }
    }

    @Test
    func `the keep-awake menu lists Off, 1 hour, 4 hours, Until turned off`() {
        #expect(KeepAwakeMode.menuOrder == [.off, .oneHour, .fourHours, .untilTurnedOff])
        #expect(KeepAwakeMode.menuOrder.map { $0.label.resolved(in: .english) }
            == ["Off", "1 hour", "4 hours", "Until turned off"])
    }
}
