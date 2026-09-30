import AgentCronCore
import Foundation
import Testing

@Suite("ClaudeCodeResultParser")
struct ClaudeCodeResultParserTests {
    private typealias Samples = ClaudeCodeResultSamples

    // MARK: - The four fixtures

    @Test
    func `a success result is succeeded, with every field the agent reported`() {
        let result = ClaudeCodeResultParser.parse(Samples.outcome(
            stdout: Samples.success,
            exitCode: 0,
        ))
        #expect(result == RunResult(
            status: .succeeded,
            resultText: "Wrote news.html with 12 items.",
            failureReason: nil,
            report: RunResult.Report(
                costUSD: Decimal(sign: .plus, exponent: -4, significand: 421),
                sessionID: "5f0c2b9e-8a41-4c37-9d7e-1b2a3c4d5e6f",
                duration: .milliseconds(12_345),
                turnCount: 4,
            ),
        ))
    }

    @Test
    func `an error subtype with no result fails with the subtype and the first stderr line`() {
        let result = ClaudeCodeResultParser.parse(Samples.outcome(
            stdout: Samples.errorMaxTurns,
            stderr: "Reached max turns\nsee --max-turns\n",
            exitCode: 1,
        ))
        #expect(result.status == .failed)
        #expect(result.failureReason == "error_max_turns: Reached max turns")
        #expect(result.resultText == "Reached max turns\nsee --max-turns\n")
        #expect(result.report == .empty)
    }

    @Test
    func `stdout that is not JSON fails with the raw stdout as the result text`() {
        let result = ClaudeCodeResultParser.parse(Samples.outcome(
            stdout: Samples.garbage,
            exitCode: 127,
        ))
        #expect(result == RunResult(
            status: .failed,
            resultText: "command not found",
            failureReason: "command not found",
            report: .empty,
        ))
    }

    @Test
    func `empty stdout with exit 1 fails with the first stderr line as the reason`() {
        let result = ClaudeCodeResultParser.parse(Samples.outcome(
            stdout: "",
            stderr: "Error: Invalid API key · Please run /login\n    at main\n",
            exitCode: 1,
        ))
        #expect(result == RunResult(
            status: .failed,
            resultText: "Error: Invalid API key · Please run /login\n    at main\n",
            failureReason: "Error: Invalid API key · Please run /login",
            report: .empty,
        ))
    }

    // MARK: - Failure signals in a result object

    @Test
    func `is_error with a result fails and keeps the result as the result text`() {
        let stdout = #"""
        {"type":"result","subtype":"success","is_error":true,"result":"API Error: 529 \#
        Overloaded\nretry later","session_id":"s-9","total_cost_usd":0}
        """#
        let result = ClaudeCodeResultParser.parse(Samples.outcome(stdout: stdout, exitCode: 1))
        #expect(result == RunResult(
            status: .failed,
            resultText: "API Error: 529 Overloaded\nretry later",
            failureReason: "API Error: 529 Overloaded",
            report: RunResult.Report(costUSD: 0, sessionID: "s-9", duration: nil, turnCount: nil),
        ))
    }

    @Test
    func `an error subtype fails even when is_error is false, keeping what it reported`() {
        let result = ClaudeCodeResultParser.parse(Samples.outcome(
            stdout: Samples.errorDuringExecution.replacingOccurrences(
                of: #""is_error":true"#,
                with: #""is_error":false"#,
            ),
            exitCode: 0,
        ))
        #expect(result == RunResult(
            status: .failed,
            resultText: nil,
            failureReason: "error_during_execution",
            report: RunResult.Report(
                costUSD: Decimal(sign: .plus, exponent: -3, significand: 3),
                sessionID: "0a1b2c3d-0000-4000-8000-000000000001",
                duration: .milliseconds(800),
                turnCount: 1,
            ),
        ))
    }

    @Test
    func `a success result from a process that exited non-zero fails`() {
        let result = ClaudeCodeResultParser.parse(Samples.outcome(
            stdout: Samples.success,
            stderr: "hook failed\n",
            exitCode: 2,
        ))
        #expect(result.status == .failed)
        #expect(result.failureReason == "hook failed")
        #expect(result.resultText == "Wrote news.html with 12 items.")
        #expect(result.report.sessionID == "5f0c2b9e-8a41-4c37-9d7e-1b2a3c4d5e6f")
    }

    @Test
    func `a success result with no optional field is succeeded with nothing reported`() {
        let result = ClaudeCodeResultParser.parse(Samples.outcome(
            stdout: #"{"type":"result","subtype":"success","is_error":false}"#,
            exitCode: 0,
        ))
        #expect(result == RunResult(
            status: .succeeded,
            resultText: nil,
            failureReason: nil,
            report: .empty,
        ))
    }

    @Test(arguments: [
        #"{"is_error":false,"result":"ok"}"#,
        #"{"subtype":"success","result":"ok"}"#,
    ])
    func `either failure field alone is enough to read a result object`(stdout: String) {
        let result = ClaudeCodeResultParser.parse(Samples.outcome(stdout: stdout, exitCode: 0))
        #expect(result.status == .succeeded)
        #expect(result.resultText == "ok")
    }

    // MARK: - Failure text

    @Test
    func `an error subtype with no stderr is the whole failure reason`() {
        let result = ClaudeCodeResultParser.parse(Samples.outcome(
            stdout: Samples.errorMaxTurns,
            exitCode: 1,
        ))
        #expect(result.failureReason == "error_max_turns")
        #expect(result.resultText == nil)
    }

    @Test
    func `the first stderr line skips blank lines and surrounding whitespace`() {
        let result = ClaudeCodeResultParser.parse(Samples.outcome(
            stdout: Samples.errorMaxTurns,
            stderr: "\n   \n\t  Reached max turns  \nnext\n",
            exitCode: 1,
        ))
        #expect(result.failureReason == "error_max_turns: Reached max turns")
    }

    @Test
    func `a failure with no output at all has no reason and no result text`() {
        let result = ClaudeCodeResultParser.parse(Samples.outcome(
            stdout: "",
            stderr: " \n",
            exitCode: 1,
        ))
        #expect(result == RunResult(
            status: .failed,
            resultText: nil,
            failureReason: nil,
            report: .empty,
        ))
    }

    @Test
    func `whitespace-only stdout counts as no output`() {
        let result = ClaudeCodeResultParser.parse(Samples.outcome(
            stdout: "\n  \n",
            stderr: "zsh: killed\n",
            exitCode: 137,
        ))
        #expect(result.status == .failed)
        #expect(result.resultText == "zsh: killed\n")
        #expect(result.failureReason == "zsh: killed")
    }

    // MARK: - Output that is not a result object

    @Test(arguments: [
        #"{"type":"assistant","message":{}}"#,
        "[1, 2]",
        #""just a string""#,
        "null",
        "{\"subtype\":\"success\"", // truncated
        #"{"result":"ok","total_cost_usd":NaN}"#,
    ])
    func `JSON that is not a result object fails with the raw stdout kept`(stdout: String) {
        let result = ClaudeCodeResultParser.parse(Samples.outcome(stdout: stdout, exitCode: 0))
        #expect(result.status == .failed)
        #expect(result.resultText == stdout)
        #expect(result.report == .empty)
    }

    @Test
    func `stdout that is not valid UTF-8 is kept with the bad bytes replaced`() {
        let outcome = ProcessOutcome(
            stdout: Data([0x6F, 0x6B, 0xFF, 0x0A]),
            stderr: "",
            exitCode: 1,
            terminatedBy: .exit,
        )
        let result = ClaudeCodeResultParser.parse(outcome)
        #expect(result.status == .failed)
        #expect(result.resultText == "ok\u{FFFD}\n")
    }

    // MARK: - Login-shell output ahead of the result

    @Test(arguments: [
        "Welcome to zsh\n",
        "Last login: Mon\n\nnvm: using node v20\n   \nrbenv: shims ready\n",
    ])
    func `a success result after login-shell noise is succeeded with every field`(
        noise: String,
    ) {
        let result = ClaudeCodeResultParser.parse(Samples.outcome(
            stdout: noise + Samples.success,
            exitCode: 0,
        ))
        #expect(result == ClaudeCodeResultParser.parse(Samples.outcome(
            stdout: Samples.success,
            exitCode: 0,
        )))
        #expect(result.status == .succeeded)
        #expect(result.report.turnCount == 4)
    }

    @Test
    func `noise followed by output that is not JSON fails with the raw stdout`() {
        let stdout = "Welcome to zsh\ncommand not found\n"
        let result = ClaudeCodeResultParser.parse(Samples.outcome(stdout: stdout, exitCode: 127))
        #expect(result == RunResult(
            status: .failed,
            resultText: stdout,
            failureReason: "Welcome to zsh",
            report: .empty,
        ))
    }
}
