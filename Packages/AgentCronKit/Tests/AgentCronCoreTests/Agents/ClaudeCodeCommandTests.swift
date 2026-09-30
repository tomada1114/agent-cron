import AgentCronCore
import Testing

/// The expected command lines are written out by hand from ADR-0004 and requirements
/// §3.3; the flag spellings are Claude Code's own (`code.claude.com/docs/en/cli-reference`),
/// which is why they differ from the snake_case raw values the job files store.
@Suite("ClaudeCodeCommand")
struct ClaudeCodeCommandTests {
    private static func request(
        prompt: String = "Summarize README.md",
        model: ModelChoice = .default,
        effort: EffortChoice = .default,
        permissionMode: PermissionMode = .auto,
    ) -> RunRequest {
        RunRequest(prompt: prompt, model: model, effort: effort, permissionMode: permissionMode)
    }

    @Test
    func `default model and effort add no flag to the base command line`() {
        let argv = ClaudeCodeCommand().arguments(for: Self.request())
        #expect(argv == [
            "claude", "-p", "--output-format", "json", "--permission-mode", "auto",
            "--", "Summarize README.md",
        ])
    }

    @Test
    func `a chosen model and effort follow the base command line`() {
        let argv = ClaudeCodeCommand().arguments(
            for: Self.request(model: .opus, effort: .high, permissionMode: .acceptEdits),
        )
        #expect(argv == [
            "claude", "-p", "--output-format", "json", "--permission-mode", "acceptEdits",
            "--model", "opus", "--effort", "high", "--", "Summarize README.md",
        ])
    }

    @Test(arguments: [
        (PermissionMode.auto, "auto"),
        (.acceptEdits, "acceptEdits"),
        (.dontAsk, "dontAsk"),
        (.plan, "plan"),
        (.default, "default"),
        (.bypassPermissions, "bypassPermissions"),
    ])
    func `each permission mode is passed in Claude Code's spelling`(
        mode: PermissionMode,
        flagValue: String,
    ) {
        let argv = ClaudeCodeCommand().arguments(for: Self.request(permissionMode: mode))
        #expect(Array(argv.dropFirst(4).prefix(2)) == ["--permission-mode", flagValue])
    }

    @Test(arguments: [
        (ModelChoice.opus, "opus"),
        (.sonnet, "sonnet"),
        (.haiku, "haiku"),
        (.fable, "fable"),
    ])
    func `each chosen model is passed as its alias, and no effort flag follows`(
        model: ModelChoice,
        alias: String,
    ) {
        let argv = ClaudeCodeCommand().arguments(for: Self.request(model: model))
        #expect(Array(argv.dropFirst(6)) == ["--model", alias, "--", "Summarize README.md"])
    }

    @Test(arguments: [
        (EffortChoice.low, "low"),
        (.medium, "medium"),
        (.high, "high"),
        (.xhigh, "xhigh"),
        (.max, "max"),
    ])
    func `each chosen effort is passed as its level, and no model flag precedes it`(
        effort: EffortChoice,
        level: String,
    ) {
        let argv = ClaudeCodeCommand().arguments(for: Self.request(effort: effort))
        #expect(Array(argv.dropFirst(6)) == ["--effort", level, "--", "Summarize README.md"])
    }

    @Test
    func `every permission mode, model, and effort choice is covered above`() {
        // The tables above are the oracle; this fails when a case is added without a row.
        #expect(PermissionMode.allCases.count == 6)
        #expect(ModelChoice.allCases.count == 5)
        #expect(EffortChoice.allCases.count == 6)
    }

    @Test
    func `a multi-line prompt is one argument, unquoted and unchanged`() {
        let prompt = """
        Review the open Dependabot PRs.
        - merge the "safe" ones with `gh pr merge`
        Cost: $HOME * 2; don't escape this \\ backslash

        """
        let argv = ClaudeCodeCommand().arguments(for: Self.request(prompt: prompt))
        #expect(argv.count == 8)
        #expect(argv.last == prompt)
    }

    /// Claude Code rejects `claude -p "- hello"` with `error: unknown option '- hello'`
    /// (checked by hand for issue #42); after `--` the same prompt reaches it as text.
    @Test(arguments: ["- review open Dependabot PRs", "--", "-p", "--model opus"])
    func `a prompt that looks like an option follows the end-of-options marker`(prompt: String) {
        let argv = ClaudeCodeCommand().arguments(for: Self.request(prompt: prompt))
        #expect(Array(argv.suffix(2)) == ["--", prompt])
        #expect(argv.firstIndex(of: "--") == argv.count - 2)
    }

    @Test
    func `a request copies the prompt and options a run snapshot holds`() {
        var job = Fixture.job()
        job.model = .sonnet
        job.effort = .xhigh
        job.permissionMode = .dontAsk
        let request = RunRequest(JobSnapshot(of: job))
        #expect(request == RunRequest(
            prompt: "Summarize today's feeds into news.html.",
            model: .sonnet,
            effort: .xhigh,
            permissionMode: .dontAsk,
        ))
    }
}
