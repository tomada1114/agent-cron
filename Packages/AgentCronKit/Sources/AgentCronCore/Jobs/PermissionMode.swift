import Foundation

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

    /// The mode's title in the job editor's Permission menu.
    public var title: LocalizedStringResource {
        switch self {
        case .auto:
            LocalizedStringResource(
                "permissionMode.auto",
                defaultValue: "Auto",
                bundle: .module,
                comment: "Permission menu item in the job editor: the agent decides per action.",
            )

        case .acceptEdits:
            LocalizedStringResource(
                "permissionMode.acceptEdits",
                defaultValue: "Accept Edits",
                bundle: .module,
                comment: "Permission menu item in the job editor: file edits are accepted without asking.",
            )

        case .dontAsk:
            LocalizedStringResource(
                "permissionMode.dontAsk",
                defaultValue: "Don’t Ask",
                bundle: .module,
                comment: "Permission menu item in the job editor: anything that would ask is refused.",
            )

        case .plan:
            LocalizedStringResource(
                "permissionMode.plan",
                defaultValue: "Plan",
                bundle: .module,
                comment: "Permission menu item in the job editor: the agent plans and changes nothing.",
            )

        case .default:
            LocalizedStringResource(
                "permissionMode.default",
                defaultValue: "Default",
                bundle: .module,
                comment: "Permission menu item in the job editor: the agent's own default permission behavior.",
            )

        case .bypassPermissions:
            LocalizedStringResource(
                "permissionMode.bypassPermissions",
                defaultValue: "Bypass Permissions",
                bundle: .module,
                comment: "Permission menu item in the job editor: every permission check is skipped.",
            )
        }
    }
}
