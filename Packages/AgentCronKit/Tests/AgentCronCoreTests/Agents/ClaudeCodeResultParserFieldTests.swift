import AgentCronCore
import Foundation
import Testing

/// The fields beside the outcome — cost above all, since a run file stores it and a
/// non-finite one would make that file undecodable (ADR-0005).
@Suite("ClaudeCodeResultParser reported fields")
struct ClaudeCodeResultParserFieldTests {
    private typealias Samples = ClaudeCodeResultSamples

    @Test(arguments: [
        "1e999", // overflows Decimal and Double
        "-1e999",
        "1e200", // beyond Decimal's exponent
        "1e-999",
        #""0.05""#, // a string, not a number
        #""NaN""#,
        #""Infinity""#,
        "null",
        "true",
        "{}",
    ])
    func `a cost that is not a finite number is left out, the rest still read`(token: String) {
        let result = ClaudeCodeResultParser.parse(Samples.outcome(
            stdout: Samples.success(costToken: token),
            exitCode: 0,
        ))
        #expect(result.report.costUSD == nil)
        #expect(result.status == .succeeded)
        #expect(result.resultText == "done")
        #expect(result.report.sessionID == "s-1")
        #expect(result.report.turnCount == 2)
    }

    @Test(arguments: [
        ("0", Decimal(0)),
        ("0.0421", Decimal(sign: .plus, exponent: -4, significand: 421)),
        ("12", Decimal(12)),
        (
            "0.1234567890123456789",
            Decimal(sign: .plus, exponent: -19, significand: 1_234_567_890_123_456_789),
        ),
        ("4.2e-2", Decimal(sign: .plus, exponent: -3, significand: 42)),
    ])
    func `a finite cost is read exactly as written`(token: String, expected: Decimal) throws {
        let result = ClaudeCodeResultParser.parse(Samples.outcome(
            stdout: Samples.success(costToken: token),
            exitCode: 0,
        ))
        let cost = try #require(result.report.costUSD)
        #expect(cost == expected)
        #expect(cost.isFinite)
    }

    @Test(arguments: ["1e999", "0.0421"])
    func `a parsed cost survives the run file round trip`(token: String) throws {
        var run = Run(job: Fixture.job(), trigger: .manual, startedAt: Fixture.createdAt)
        run.costUSD = ClaudeCodeResultParser.parse(Samples.outcome(
            stdout: Samples.success(costToken: token),
            exitCode: 0,
        )).report.costUSD
        let decoded = try JSONDecoder().decode(Run.self, from: JSONEncoder().encode(run))
        #expect(decoded == run)
    }

    // MARK: - Other fields

    @Test(arguments: [
        #""session_id":7"#,
        #""duration_ms":"12""#,
        #""num_turns":2.5"#,
    ])
    func `a field of the wrong type is left out without losing the result`(field: String) {
        let stdout = #"{"subtype":"success","is_error":false,"result":"done",\#(field)}"#
        let result = ClaudeCodeResultParser.parse(Samples.outcome(stdout: stdout, exitCode: 0))
        #expect(result.status == .succeeded)
        #expect(result.resultText == "done")
        #expect(result.report == .empty)
    }
}
