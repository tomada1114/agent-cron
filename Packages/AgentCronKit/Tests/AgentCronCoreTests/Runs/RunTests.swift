import AgentCronCore
import Foundation
import Testing

@Suite("Run")
struct RunTests {
    private static let scheduledAt = Date(timeIntervalSince1970: 1_700_010_000)
    private static let startedAt = Date(timeIntervalSince1970: 1_700_010_002.5)
    private static let endedAt = Date(timeIntervalSince1970: 1_700_010_125.75)

    /// A job whose every option differs from its default, so a snapshot that dropped one
    /// would show.
    private static func customizedJob() -> Job {
        var job = Fixture.job()
        job.model = .opus
        job.effort = .high
        job.permissionMode = .acceptEdits
        job.timeoutMinutes = 90
        job.notify = .everyRun
        return job
    }

    // MARK: - Starting a run

    @Test
    func `a new run records the job, the trigger, and the times, and is running`() {
        let run = Run(
            job: Self.customizedJob(),
            trigger: .scheduled,
            startedAt: Self.startedAt,
            scheduledAt: Self.scheduledAt,
            id: Fixture.runID,
        )
        #expect(run.id == Fixture.runID)
        #expect(run.jobID == Fixture.jobID)
        #expect(run.jobName == "RSS digest")
        #expect(run.trigger == .scheduled)
        #expect(run.scheduledAt == Self.scheduledAt)
        #expect(run.startedAt == Self.startedAt)
        #expect(run.outcome == .running)
        #expect(run.endedAt == nil)
        #expect(run.skipReason == nil)
        #expect(run.failureReason == nil)
        #expect(run.exitCode == nil)
        #expect(run.costUSD == nil)
        #expect(run.sessionID == nil)
        #expect(run.resultText == nil)
    }

    @Test
    func `a manual run has no scheduled time`() {
        let run = Run(job: Fixture.job(), trigger: .manual, startedAt: Self.startedAt)
        #expect(run.scheduledAt == nil)
    }

    @Test
    func `a run snapshots the prompt and every option of the saved job`() {
        let snapshot = Run(job: Self.customizedJob(), trigger: .manual, startedAt: Self.startedAt)
            .snapshot
        #expect(snapshot.agent == .claudeCode)
        #expect(snapshot.directory == Fixture.directory)
        #expect(snapshot.prompt == "Summarize today's feeds into news.html.")
        #expect(snapshot.model == .opus)
        #expect(snapshot.effort == .high)
        #expect(snapshot.permissionMode == .acceptEdits)
        #expect(snapshot.timeoutMinutes == 90)
        #expect(snapshot.notify == .everyRun)
    }

    @Test
    func `editing the job afterwards leaves the run's snapshot as it was`() {
        var job = Self.customizedJob()
        let run = Run(job: job, trigger: .manual, startedAt: Self.startedAt)
        job.name = "Renamed"
        job.prompt = "Something else."
        job.model = .haiku
        #expect(run.jobName == "RSS digest")
        #expect(run.snapshot.prompt == "Summarize today's feeds into news.html.")
        #expect(run.snapshot.model == .opus)
    }

    // MARK: - Vocabulary

    @Test
    func `triggers, outcomes, and skip reasons persist under stable names`() {
        #expect(Set(RunTrigger.allCases.map(\.rawValue)) == ["scheduled", "catch_up", "manual"])
        #expect(Set(RunOutcome.allCases.map(\.rawValue)) == [
            "running", "succeeded", "failed", "timed_out", "stopped", "skipped",
        ])
        #expect(Set(SkipReason.allCases.map(\.rawValue)) == [
            "missed", "still_running", "agent_not_found", "directory_missing",
        ])
    }

    // MARK: - Codable

    @Test
    func `a running run survives a JSON round trip unchanged`() throws {
        let run = Run(
            job: Fixture.job(),
            trigger: .catchUp,
            startedAt: Self.startedAt,
            scheduledAt: Self.scheduledAt,
            id: Fixture.runID,
        )
        #expect(try Fixture.roundTrip(run) == run)
    }

    @Test
    func `a finished run with every field set survives a JSON round trip unchanged`() throws {
        var run = Run(
            job: Self.customizedJob(),
            trigger: .scheduled,
            startedAt: Self.startedAt,
            scheduledAt: Self.scheduledAt,
            id: Fixture.runID,
        )
        run.endedAt = Self.endedAt
        run.outcome = .failed
        run.failureReason = "error_max_turns"
        run.exitCode = -15
        run.costUSD = Decimal(string: "0.1234")
        run.sessionID = "5f2c9a1e-0000-4000-8000-000000000001"
        run.resultText = "## 結果\nMerged 2 PRs; skipped 1 (major bump)."
        #expect(try Fixture.roundTrip(run) == run)
    }

    @Test
    func `a skipped run survives a JSON round trip unchanged`() throws {
        var run = Run(
            job: Fixture.job(),
            trigger: .scheduled,
            startedAt: Self.startedAt,
            scheduledAt: Self.scheduledAt,
            id: Fixture.runID,
        )
        run.endedAt = Self.startedAt
        run.outcome = .skipped
        run.skipReason = .stillRunning
        #expect(try Fixture.roundTrip(run) == run)
    }

    @Test(arguments: ["0", "0.12", "1.5", "12.3456789"])
    func `a reported cost keeps its exact decimal value through a round trip`(cost: String) throws {
        var run = Run(job: Fixture.job(), trigger: .manual, startedAt: Self.startedAt)
        run.costUSD = Decimal(string: cost)
        #expect(try Fixture.roundTrip(run).costUSD == Decimal(string: cost))
    }
}
