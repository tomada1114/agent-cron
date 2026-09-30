import AgentCronCore
import Foundation

/// What `claude -p … --output-format json` prints, as the parser tests feed it.
///
/// None of these was recorded from a real run — running `claude` spends the user's quota.
/// The success and error-during-execution objects are written by hand from the result
/// object's documented fields (`code.claude.com/docs/en/headless`, cited by ADR-0004),
/// with the extra fields the CLI also prints (`type`, `duration_api_ms`, `usage`) left in
/// so the parser is seen to ignore them; the other two are issue #10's examples verbatim.
enum ClaudeCodeResultSamples {
    /// A finished run: `subtype` `success`, `is_error` false, every field the parser reads.
    static let success = """
    {"type":"result","subtype":"success","is_error":false,"duration_ms":12345,\
    "duration_api_ms":11020,"num_turns":4,"result":"Wrote news.html with 12 items.",\
    "session_id":"5f0c2b9e-8a41-4c37-9d7e-1b2a3c4d5e6f","total_cost_usd":0.0421,\
    "usage":{"input_tokens":1200,"output_tokens":340}}

    """

    /// Issue #10's error-subtype example: the turn limit hit, no `result`.
    static let errorMaxTurns = #"{"subtype":"error_max_turns","is_error":true}"#

    /// A run that failed partway: an error subtype, no `result`, but a cost and a session.
    static let errorDuringExecution = """
    {"type":"result","subtype":"error_during_execution","is_error":true,"duration_ms":800,\
    "num_turns":1,"session_id":"0a1b2c3d-0000-4000-8000-000000000001","total_cost_usd":0.003}
    """

    /// Issue #10's garbage example: the shell's complaint, not JSON at all.
    static let garbage = "command not found"

    /// An outcome as ``AgentRunning`` reports a process that exited on its own.
    static func outcome(stdout: String, stderr: String, exitCode: Int32) -> ProcessOutcome {
        ProcessOutcome(
            stdout: Data(stdout.utf8),
            stderr: stderr,
            exitCode: exitCode,
            terminatedBy: .exit,
        )
    }

    /// An outcome as ``AgentRunning`` reports a process that exited on its own and wrote
    /// nothing to stderr.
    static func outcome(stdout: String, exitCode: Int32) -> ProcessOutcome {
        outcome(stdout: stdout, stderr: "", exitCode: exitCode)
    }

    /// A successful result object whose `total_cost_usd` is written as `costToken`.
    static func success(costToken: String) -> String {
        #"{"type":"result","subtype":"success","is_error":false,"result":"done","#
            + #""session_id":"s-1","num_turns":2,"total_cost_usd":\#(costToken)}"#
    }
}
