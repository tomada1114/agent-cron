import AgentCronCore
import AgentCronTestSupport
import Foundation
import Testing

@MainActor
@Suite("PopoverModel timeline")
struct PopoverModelTimelineTests {
    typealias Fix = PopoverFixture

    @Test
    func `REQ-001 lists today's finished, running, and upcoming rows by time`() throws {
        try withScratchDefaults { defaults in
            let finished = Fix.run(
                of: Fix.digest,
                at: Fix.tuesday(9, 0),
                ended: Fix.tuesday(9, 2),
                outcome: .succeeded,
                cost: Decimal(string: "0.12"),
            )
            let running = Fix.run(of: Fix.review, at: Fix.tuesday(12, 0))
            let model = Fix.model(
                jobs: [Fix.digest, Fix.review],
                runs: [running, finished],
                now: Fix.tuesday(12, 4),
                defaults: defaults,
            )
            model.runningRunsChanged(to: [running])

            let rows = model.rows
            #expect(rows.map(\.timeText) == ["09:00", "12:00", "18:00"])
            #expect(rows.map(\.badge) == [.succeeded, .running, .upcoming])
            #expect(rows.map(\.jobName) == ["RSS digest", "Dependabot review", "RSS digest"])
            #expect(rows.map(\.day) == [.today, .today, .today])
            #expect(rows[0].duration == .seconds(120))
            #expect(rows[0].costUSD == Decimal(string: "0.12"))
            #expect(rows[1].duration == nil)
            #expect(rows[2].duration == nil)
            #expect(rows[2].costUSD == nil)
            #expect(model.statusSymbol == .running)
            #expect(model.statusSymbol.symbolName == "clock.fill")
            #expect(model.emptyState == nil)
        }
    }

    @Test
    func `a running run of a job no longer reported running is not listed`() throws {
        try withScratchDefaults { defaults in
            let stale = Fix.run(of: Fix.review, at: Fix.tuesday(12, 0))
            let model = Fix.model(
                jobs: [Fix.review],
                runs: [stale],
                now: Fix.tuesday(12, 4),
                defaults: defaults,
            )
            #expect(model.rows.allSatisfy { $0.badge != .running })
        }
    }

    @Test
    func `a finished run from yesterday is not one of today's rows`() throws {
        try withScratchDefaults { defaults in
            let yesterday = Fix.run(
                of: Fix.digest,
                at: Fix.tuesday(18, 0, plusDays: -1),
                ended: Fix.tuesday(18, 1, plusDays: -1),
                outcome: .succeeded,
            )
            let model = Fix.model(
                jobs: [Fix.digest],
                runs: [yesterday],
                now: Fix.tuesday(8, 0),
                defaults: defaults,
            )
            #expect(model.rows.map(\.timeText) == ["09:00", "18:00"])
            #expect(model.rows.map(\.badge) == [.upcoming, .upcoming])
        }
    }

    @Test
    func `REQ-002 with no fire left today the next run is appended as Tomorrow`() throws {
        try withScratchDefaults { defaults in
            let morning = Fix.run(
                of: Fix.digest,
                at: Fix.tuesday(9, 0),
                ended: Fix.tuesday(9, 2),
                outcome: .succeeded,
            )
            let evening = Fix.run(
                of: Fix.digest,
                at: Fix.tuesday(18, 0),
                ended: Fix.tuesday(18, 3),
                outcome: .failed,
            )
            let model = Fix.model(
                jobs: [Fix.digest],
                runs: [evening, morning],
                now: Fix.tuesday(23, 0),
                defaults: defaults,
            )
            let rows = model.rows
            #expect(rows.map(\.timeText) == ["09:00", "18:00", "09:00"])
            #expect(rows.map(\.badge) == [.succeeded, .failed, .upcoming])
            #expect(rows.map(\.day) == [.today, .today, .tomorrow])
            #expect(rows.last?.date == Fix.tuesday(9, 0, plusDays: 1))
            #expect(rows.last?.jobName == "RSS digest")
            #expect(PopoverDay.tomorrow.label?.resolved(in: .english) == "Tomorrow")
            #expect(model.emptyState == nil)
        }
    }

    @Test
    func `REQ-002 a next run beyond tomorrow is labelled with its weekday`() throws {
        try withScratchDefaults { defaults in
            // Friday 23:00: the next weekday run is Monday 09:00.
            let model = Fix.model(
                jobs: [Fix.digest],
                now: Fix.tuesday(23, 0, plusDays: 3),
                defaults: defaults,
            )
            let rows = model.rows
            #expect(rows.count == 1)
            #expect(rows.first?.day == .weekday(.monday))
            #expect(rows.first?.day.label?.resolved(in: .english) == "Mon")
            #expect(PopoverDay.today.label == nil)
        }
    }

    @Test
    func `a bypass job's rows carry the bypass flag`() throws {
        try withScratchDefaults { defaults in
            var bypass = Fix.digest
            bypass.permissionMode = .bypassPermissions
            let run = Fix.run(
                of: bypass,
                at: Fix.tuesday(9, 0),
                ended: Fix.tuesday(9, 1),
                outcome: .succeeded,
            )
            let model = Fix.model(
                jobs: [bypass],
                runs: [run],
                now: Fix.tuesday(12, 0),
                defaults: defaults,
            )
            #expect(model.rows.map(\.usesBypassPermissions) == [true, true])
        }
    }

    @Test
    func `runFinished replaces the running run with its finished one`() throws {
        try withScratchDefaults { defaults in
            var run = Fix.run(of: Fix.review, at: Fix.tuesday(12, 0))
            let model = Fix.model(
                jobs: [Fix.review],
                runs: [run],
                now: Fix.tuesday(12, 30),
                defaults: defaults,
            )
            model.runningRunsChanged(to: [run])
            run.endedAt = Fix.tuesday(12, 10)
            run.outcome = .succeeded
            model.runningRunsChanged(to: [])
            model.runFinished(run)
            #expect(model.runs.count == 1)
            #expect(model.rows.first?.badge == .succeeded)
            #expect(model.rows.first?.duration == .seconds(600))
        }
    }

    @Test
    func `a run that starts after load shows as running at once`() throws {
        try withScratchDefaults { defaults in
            let clock = ManualClock(start: Fix.tuesday(11, 59))
            let model = PopoverModel(
                jobStore: FakeJobStore(document: JobsDocument(jobs: [Fix.review])),
                runStore: FakeRunStore(runs: []),
                keepAwake: KeepAwakeController(preventer: FakeSleepPreventer()),
                calendar: Fix.calendar,
                defaults: defaults,
            ) { clock.date }
            model.load()
            #expect(model.rows.first?.badge == .upcoming)
            clock.advance(by: .seconds(120))
            #expect(model.rows.allSatisfy { $0.jobID != Fix.review.id || $0.day != .today })
            model.runningRunsChanged(to: [Fix.run(of: Fix.review, at: Fix.tuesday(12, 0))])
            #expect(model.statusSymbol == .running)
            #expect(model.rows.first?.badge == .running)
        }
    }
}
