/// Claude Code's command line: `claude -p <prompt> --output-format json
/// --permission-mode <mode> [--model <alias>] [--effort <level>]` (ADR-0004,
/// requirements §3.3).
///
/// The same flags a user would type, so a scheduled run matches a hand-run one. A model
/// or effort left at its default passes no flag at all, so Claude Code's own setting
/// applies exactly as it would by hand. Each option is spelled with an explicit `switch`
/// rather than its raw value: the raw values are the job file's snake_case storage
/// spellings, and Claude Code's flag values are its own.
public struct ClaudeCodeCommand: AgentCommandBuilding {
    /// Always ``AgentKind/claudeCode``.
    public let agent = AgentKind.claudeCode

    /// Makes the builder.
    public init() {
        // Public so the dispatcher's module can construct it; a synthesized one is internal.
    }

    /// The `claude -p` command line for `request`. The prompt is one element however
    /// many lines, quotes, or `$` it holds; the runner never lets a shell re-parse it.
    public func arguments(for request: RunRequest) -> [String] {
        var argv = [
            "claude",
            "-p",
            request.prompt,
            "--output-format",
            "json",
            "--permission-mode",
            flagValue(for: request.permissionMode),
        ]
        if let alias = flagValue(for: request.model) {
            argv += ["--model", alias]
        }
        if let level = flagValue(for: request.effort) {
            argv += ["--effort", level]
        }
        return argv
    }

    /// Claude Code's JSON result, read by ``ClaudeCodeResultParser``.
    public func result(of outcome: ProcessOutcome) -> RunResult {
        ClaudeCodeResultParser.parse(outcome)
    }

    private func flagValue(for mode: PermissionMode) -> String {
        switch mode {
        case .default:
            "default"

        case .acceptEdits:
            "acceptEdits"

        case .auto:
            "auto"

        case .bypassPermissions:
            "bypassPermissions"

        case .dontAsk:
            "dontAsk"

        case .plan:
            "plan"
        }
    }

    private func flagValue(for model: ModelChoice) -> String? {
        switch model {
        case .default:
            nil

        case .fable:
            "fable"

        case .haiku:
            "haiku"

        case .opus:
            "opus"

        case .sonnet:
            "sonnet"
        }
    }

    private func flagValue(for effort: EffortChoice) -> String? {
        switch effort {
        case .default:
            nil

        case .high:
            "high"

        case .low:
            "low"

        case .max:
            "max"

        case .medium:
            "medium"

        case .xhigh:
            "xhigh"
        }
    }
}
