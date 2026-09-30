/// Which tool calls the agent may make without asking, in a run nobody is watching.
///
/// Cases are declared alphabetically (SwiftLint's `sorted_enum_cases`); ``allCases`` is
/// the order the editor lists them in. The raw value is what `jobs.json` and each run
/// file store, so changing it is a file-format change.
public enum PermissionMode: String, Sendable, Codable, CaseIterable {
    /// The agent's own default permission behavior.
    case `default`
    /// File edits are accepted without asking.
    case acceptEdits = "accept_edits"
    /// The agent decides per action. The default for a new job.
    case auto
    /// Every check is skipped; the editor warns and every list badges a job using it.
    case bypassPermissions = "bypass_permissions"
    /// Anything that would ask is refused instead.
    case dontAsk = "dont_ask"
    /// The agent plans and changes nothing.
    case plan

    /// Every mode, in the order the editor lists them: `auto` first, `bypassPermissions`
    /// last.
    public static let allCases: [Self] = [
        .auto,
        .acceptEdits,
        .dontAsk,
        .plan,
        .default,
        .bypassPermissions,
    ]
}
