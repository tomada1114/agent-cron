import AgentCronCore
import Foundation
import Testing

/// A caller reaches an agent's command line and result only through the builder its
/// ``AgentKind`` names, so a second agent is a new builder, not a new branch in the
/// dispatcher (ADR-0004).
@Suite("AgentCommandBuilding")
struct AgentCommandBuildingTests {
    @Test(arguments: AgentKind.allCases)
    func `every agent kind names a builder for that same kind`(kind: AgentKind) {
        #expect(kind.commandBuilder.agent == kind)
    }

    @Test
    func `the Claude Code builder writes the claude -p command line`() {
        let request = RunRequest(
            prompt: "Review PRs",
            model: .haiku,
            effort: .default,
            permissionMode: .plan,
        )
        #expect(AgentKind.claudeCode.commandBuilder.arguments(for: request) == [
            "claude", "-p", "Review PRs", "--output-format", "json",
            "--permission-mode", "plan", "--model", "haiku",
        ])
    }

    @Test
    func `the Claude Code builder reads back Claude Code's JSON result`() {
        let builder = AgentKind.claudeCode.commandBuilder
        let succeeded = builder.result(of: ClaudeCodeResultSamples.outcome(
            stdout: ClaudeCodeResultSamples.success,
            exitCode: 0,
        ))
        #expect(succeeded.status == .succeeded)
        #expect(succeeded.resultText == "Wrote news.html with 12 items.")

        let failed = builder.result(of: ClaudeCodeResultSamples.outcome(
            stdout: ClaudeCodeResultSamples.garbage,
            exitCode: 127,
        ))
        #expect(failed.status == .failed)
        #expect(failed.resultText == "command not found")
    }
}
