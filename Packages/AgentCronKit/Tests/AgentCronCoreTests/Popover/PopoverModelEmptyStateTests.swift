import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

@MainActor
@Suite("PopoverModel empty states")
struct PopoverModelEmptyStateTests {
    typealias Fix = PopoverFixture

    @Test
    func `REQ-006 no jobs reads No jobs yet`() throws {
        try withScratchDefaults { defaults in
            let model = Fix.model(jobs: [], now: Fix.tuesday(12, 0), defaults: defaults)
            #expect(model.emptyState == .noJobs)
            #expect(model.emptyState?.message.resolved(in: .english) == "No jobs yet")
            #expect(model.rows.isEmpty)
        }
    }

    @Test
    func `REQ-006 every job paused reads All jobs are paused and lists no upcoming row`() throws {
        try withScratchDefaults { defaults in
            let paused = [
                JobsScreenFixture.paused(Fix.digest),
                JobsScreenFixture.paused(Fix.review),
            ]
            let model = Fix.model(jobs: paused, now: Fix.tuesday(8, 0), defaults: defaults)
            #expect(model.emptyState == .allPaused)
            #expect(model.emptyState?.message.resolved(in: .english) == "All jobs are paused.")
            #expect(model.rows.isEmpty)
        }
    }

    @Test
    func `REQ-006 nothing today names the next run`() throws {
        try withScratchDefaults { defaults in
            // Saturday noon: nothing ran or runs today; next is Monday 09:00.
            let model = Fix.model(
                jobs: [Fix.digest],
                now: Fix.tuesday(12, 0, plusDays: 4),
                defaults: defaults,
            )
            let state = try #require(model.emptyState)
            guard case let .nothingToday(next, dayText) = state else {
                Issue.record("expected nothingToday, got \(state)")
                return
            }
            #expect(dayText == "Mon")
            #expect(next.timeText == "09:00")
            #expect(state.message
                .resolved(in: .english) == "Nothing scheduled today. Next: Mon 09:00 RSS digest.")
        }
    }

    @Test
    func `nothing today on the evening before names Tomorrow`() throws {
        try withScratchDefaults { defaults in
            let model = Fix.model(
                jobs: [Fix.digest],
                now: Fix.tuesday(12, 0, plusDays: 5),
                defaults: defaults,
            )
            #expect(model.emptyState?.message.resolved(in: .english)
                == "Nothing scheduled today. Next: Tomorrow 09:00 RSS digest.")
        }
    }

    @Test
    func `REQ-006 the agent-not-found banner follows the availability check`() throws {
        try withScratchDefaults { defaults in
            let model = Fix.model(jobs: [Fix.digest], now: Fix.tuesday(12, 0), defaults: defaults)
            #expect(!model.isAgentMissing)
            model.agentAvailabilityChanged(.notFound)
            #expect(model.isAgentMissing)
            #expect(PopoverBanner.agentNotFound.resolved(in: .english)
                == "claude was not found in your login shell.")
            model.agentAvailabilityChanged(.available(
                path: "/usr/local/bin/claude",
                version: "2.1.0",
            ))
            #expect(!model.isAgentMissing)
        }
    }

    @Test
    func `a failing job store is reported and the popover shows no jobs`() throws {
        try withScratchDefaults { defaults in
            let model = Fix.model(
                jobStore: FakeJobStore(loadError: .corruptJobs, saveError: nil),
                runs: [],
                now: Fix.tuesday(12, 0),
                defaults: defaults,
                keepAwake: KeepAwakeController(preventer: FakeSleepPreventer()),
            )
            #expect(model.storageError == .corruptJobs)
            #expect(model.emptyState == .noJobs)
        }
    }

    @Test
    func `a failing run store is reported and leaves no runs`() throws {
        try withScratchDefaults { defaults in
            let model = PopoverModel(
                jobStore: FakeJobStore(document: JobsDocument(jobs: [Fix.digest])),
                runStore: FailingRunStore(),
                keepAwake: KeepAwakeController(preventer: FakeSleepPreventer()),
                calendar: Fix.calendar,
                defaults: defaults,
            ) { Fix.tuesday(12, 0) }
            model.load()
            #expect(model.storageError == .readFailed(code: FailingRunStore.readCode))
            #expect(model.runs.isEmpty)
            #expect(model.jobs.count == 1)
        }
    }
}
