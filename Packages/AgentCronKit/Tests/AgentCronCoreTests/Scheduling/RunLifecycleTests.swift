import AgentCronCore
import Foundation
import Testing

/// How a started run becomes the record history keeps: what ended the process decides
/// before what the agent's output says (``RunResult``'s own rule), and every reported
/// field is copied, not interpreted (requirements §3.4).
@Suite("RunLifecycle")
struct RunLifecycleTests {
    private static let started = Run(
        job: Fixture.job(),
        trigger: .scheduled,
        startedAt: Fixture.createdAt,
        scheduledAt: Fixture.createdAt,
        id: Fixture.runID,
    )
    private static let ended = Fixture.createdAt.addingTimeInterval(125)

    private static let failedResult = RunResult(
        status: .failed,
        resultText: "partial output",
        failureReason: "error_during_execution",
        report: RunResult.Report(
            costUSD: Decimal(string: "0.003"),
            sessionID: "s-9",
            duration: nil,
            turnCount: 1,
        ),
    )

    private static let succeededResult = RunResult(
        status: .succeeded,
        resultText: "done",
        failureReason: nil,
        report: RunResult.Report(
            costUSD: Decimal(string: "0.25"),
            sessionID: "s-1",
            duration: .seconds(3),
            turnCount: 2,
        ),
    )

    private static func outcome(
        _ termination: ProcessOutcome.Termination,
        exitCode: Int32,
    ) -> ProcessOutcome {
        ProcessOutcome(stdout: Data(), stderr: "", exitCode: exitCode, terminatedBy: termination)
    }

    @Test(arguments: [
        (
            ProcessOutcome.Termination.exit,
            Int32(0),
            RunResult.Status.succeeded,
            RunOutcome.succeeded,
        ),
        (.exit, 1, .failed, .failed),
        (.timeout, 143, .failed, .timedOut),
        (.timeout, 143, .succeeded, .timedOut),
        (.stopped, 143, .failed, .stopped),
        (.stopped, 137, .succeeded, .stopped),
    ])
    func `the termination decides before the agent's own verdict`(
        termination: ProcessOutcome.Termination,
        exitCode: Int32,
        status: RunResult.Status,
        expected: RunOutcome,
    ) {
        let result = status == .succeeded ? Self.succeededResult : Self.failedResult
        let run = Self.started.finished(
            with: Self.outcome(termination, exitCode: exitCode),
            result: result,
            at: Self.ended,
        )
        #expect(run.outcome == expected)
        #expect(run.exitCode == exitCode)
        #expect(run.endedAt == Self.ended)
    }

    @Test
    func `a failed run keeps the agent's reason, result, cost, and session`() {
        let run = Self.started.finished(
            with: Self.outcome(.exit, exitCode: 1),
            result: Self.failedResult,
            at: Self.ended,
        )
        #expect(run.failureReason == "error_during_execution")
        #expect(run.resultText == "partial output")
        #expect(run.costUSD == Decimal(string: "0.003"))
        #expect(run.sessionID == "s-9")
        #expect(run.skipReason == nil)
    }

    @Test
    func `only a failed run carries a failure reason`() {
        let timedOut = Self.started.finished(
            with: Self.outcome(.timeout, exitCode: 143),
            result: Self.failedResult,
            at: Self.ended,
        )
        #expect(timedOut.failureReason == nil)
        #expect(timedOut.resultText == "partial output")
    }

    @Test
    func `finishing keeps what the run started as`() {
        let run = Self.started.finished(
            with: Self.outcome(.exit, exitCode: 0),
            result: Self.succeededResult,
            at: Self.ended,
        )
        #expect(run.id == Fixture.runID)
        #expect(run.jobID == Fixture.jobID)
        #expect(run.trigger == .scheduled)
        #expect(run.scheduledAt == Fixture.createdAt)
        #expect(run.startedAt == Fixture.createdAt)
        #expect(run.snapshot == JobSnapshot(of: Fixture.job()))
    }

    @Test(arguments: SkipReason.allCases)
    func `a skipped run says why and ends when it was recorded`(reason: SkipReason) {
        let run = Self.started.skipped(reason, at: Self.ended)
        #expect(run.outcome == .skipped)
        #expect(run.skipReason == reason)
        #expect(run.endedAt == Self.ended)
        #expect(run.exitCode == nil)
        #expect(run.startedAt == Fixture.createdAt)
    }

    @Test
    func `a run stopped before it launched has no exit code`() {
        let run = Self.started.stopped(at: Self.ended)
        #expect(run.outcome == .stopped)
        #expect(run.endedAt == Self.ended)
        #expect(run.exitCode == nil)
        #expect(run.skipReason == nil)
    }
}
