import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

@MainActor
@Suite("PopoverModel unseen failures")
struct PopoverModelUnseenTests {
    typealias Fix = PopoverFixture

    private static func nightly(ending end: Date, outcome: RunOutcome = .failed) -> Run {
        let job = JobsScreenFixture.job(
            Fix.nightlyNumber,
            "Nightly review",
            days: [.tuesday],
            times: [(22, 0)],
        )
        return Fix.run(of: job, at: Fix.tuesday(22, 0), ended: end, outcome: outcome)
    }

    @Test
    func `REQ-003 a failure after the last open is unseen until the popover opens`() throws {
        try withScratchDefaults { defaults in
            defaults.set(Fix.tuesday(20, 0), forKey: PopoverModel.lastPopoverOpenedAtKey)
            let model = Fix.model(
                jobs: [Fix.digest],
                runs: [Self.nightly(ending: Fix.tuesday(22, 5))],
                now: Fix.tuesday(23, 0),
                defaults: defaults,
            )
            #expect(model.unseenFailureCount == 1)
            #expect(model.showsFailureDot)

            model.open()

            #expect(model.unseenFailureCount == 0)
            #expect(!model.showsFailureDot)
            #expect(defaults.object(forKey: "lastPopoverOpenedAt") as? Date == Fix.tuesday(23, 0))
            #expect(model.lastPopoverOpenedAt == Fix.tuesday(23, 0))
        }
    }

    @Test(arguments: [RunOutcome.failed, .timedOut, .skipped])
    func `REQ-003 failed, timed out, and skipped runs count as unseen`(outcome: RunOutcome) throws {
        try withScratchDefaults { defaults in
            defaults.set(Fix.tuesday(20, 0), forKey: PopoverModel.lastPopoverOpenedAtKey)
            let run = Self.nightly(ending: Fix.tuesday(22, 5), outcome: outcome)
            let model = Fix.model(
                jobs: [Fix.digest],
                runs: [run],
                now: Fix.tuesday(23, 0),
                defaults: defaults,
            )
            #expect(model.unseenFailureCount == 1)
        }
    }

    @Test(arguments: [RunOutcome.succeeded, .stopped, .running])
    func `REQ-003 other outcomes never count as unseen`(outcome: RunOutcome) throws {
        try withScratchDefaults { defaults in
            defaults.set(Fix.tuesday(20, 0), forKey: PopoverModel.lastPopoverOpenedAtKey)
            let run = Self.nightly(ending: Fix.tuesday(22, 5), outcome: outcome)
            let model = Fix.model(
                jobs: [Fix.digest],
                runs: [run],
                now: Fix.tuesday(23, 0),
                defaults: defaults,
            )
            #expect(model.unseenFailureCount == 0)
        }
    }

    @Test
    func `with the key absent on first launch no run counts as unseen`() throws {
        try withScratchDefaults { defaults in
            let model = Fix.model(
                jobs: [Fix.digest],
                runs: [Self.nightly(ending: Fix.tuesday(22, 5))],
                now: Fix.tuesday(23, 0),
                defaults: defaults,
            )
            #expect(model.lastPopoverOpenedAt == nil)
            #expect(model.unseenFailureCount == 0)
            #expect(!model.showsFailureDot)
        }
    }

    @Test
    func `a run that ended exactly at the key is not unseen`() throws {
        try withScratchDefaults { defaults in
            defaults.set(Fix.tuesday(22, 5), forKey: PopoverModel.lastPopoverOpenedAtKey)
            let model = Fix.model(
                jobs: [Fix.digest],
                runs: [Self.nightly(ending: Fix.tuesday(22, 5))],
                now: Fix.tuesday(23, 0),
                defaults: defaults,
            )
            #expect(model.unseenFailureCount == 0)
        }
    }

    @Test
    func `a failure from before today still counts when it ended after the key`() throws {
        try withScratchDefaults { defaults in
            defaults.set(
                Fix.tuesday(20, 0, plusDays: -1),
                forKey: PopoverModel.lastPopoverOpenedAtKey,
            )
            let job = JobsScreenFixture.job(
                Fix.nightlyNumber,
                "Nightly review",
                days: [.monday],
                times: [(22, 0)],
            )
            let run = Fix.run(
                of: job,
                at: Fix.tuesday(22, 0, plusDays: -1),
                ended: Fix.tuesday(22, 5, plusDays: -1),
                outcome: .failed,
            )
            let model = Fix.model(
                jobs: [job],
                runs: [run],
                now: Fix.tuesday(8, 0),
                defaults: defaults,
            )
            #expect(model.unseenFailureCount == 1)
            #expect(model.rows.allSatisfy { $0.badge == .upcoming })
        }
    }

    @Test
    func `a failure reported by runFinished after the key is unseen`() throws {
        try withScratchDefaults { defaults in
            defaults.set(Fix.tuesday(20, 0), forKey: PopoverModel.lastPopoverOpenedAtKey)
            let model = Fix.model(jobs: [Fix.digest], now: Fix.tuesday(23, 0), defaults: defaults)
            #expect(model.unseenFailureCount == 0)
            model.runFinished(Self.nightly(ending: Fix.tuesday(22, 5)))
            #expect(model.unseenFailureCount == 1)
        }
    }
}
