import AgentCronCore
import Testing

/// The raw values below are what `jobs.json` and the run files store, so a rename here is
/// a file-format change (`docs/architecture.md` › What is contract and what is private).
@Suite("Job options")
struct JobOptionsTests {
    @Test
    func `the only agent is Claude Code`() {
        #expect(AgentKind.allCases.map(\.rawValue) == ["claude_code"])
    }

    @Test
    func `model choices are Default and the four aliases`() {
        #expect(ModelChoice.allCases.map(\.rawValue) == [
            "default",
            "opus",
            "sonnet",
            "haiku",
            "fable",
        ])
    }

    @Test
    func `effort choices are Default and the five levels`() {
        #expect(EffortChoice.allCases.map(\.rawValue) == [
            "default", "low", "medium", "high", "xhigh", "max",
        ])
    }

    @Test
    func `permission modes are the six the editor offers, auto first`() {
        #expect(PermissionMode.allCases.map(\.rawValue) == [
            "auto", "accept_edits", "dont_ask", "plan", "default", "bypass_permissions",
        ])
    }

    @Test
    func `notification policies are never, failures only, and every run`() {
        #expect(NotifyPolicy.allCases.map(\.rawValue) == ["never", "failures_only", "every_run"])
    }
}
