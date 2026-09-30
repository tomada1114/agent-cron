import Foundation

/// The model a run asks the agent for.
///
/// Cases are declared alphabetically (SwiftLint's `sorted_enum_cases`); ``allCases`` is
/// the order the editor lists them in. The raw value is what `jobs.json` and each run
/// file store, so changing it is a file-format change.
public enum ModelChoice: String, Sendable, Codable, CaseIterable {
    /// Pass no model, so the agent's own configured default applies — what a hand-run
    /// command without the flag would use. The default for a new job.
    case `default`
    /// The Fable model family alias.
    case fable
    /// The Haiku model family alias.
    case haiku
    /// The Opus model family alias.
    case opus
    /// The Sonnet model family alias.
    case sonnet

    /// Every choice, in the order the editor lists them: Default first.
    public static let allCases: [Self] = [.default, .opus, .sonnet, .haiku, .fable]

    /// The choice's title in the job editor's Model menu.
    public var title: LocalizedStringResource {
        switch self {
        case .default:
            LocalizedStringResource(
                "modelChoice.default",
                defaultValue: "Default",
                bundle: .module,
                comment: "Model menu item in the job editor: pass no model, so the agent's own default applies.",
            )

        case .opus:
            LocalizedStringResource(
                "modelChoice.opus",
                defaultValue: "Opus",
                bundle: .module,
                comment: "Model menu item in the job editor: the Opus model family. A product name.",
            )

        case .sonnet:
            LocalizedStringResource(
                "modelChoice.sonnet",
                defaultValue: "Sonnet",
                bundle: .module,
                comment: "Model menu item in the job editor: the Sonnet model family. A product name.",
            )

        case .haiku:
            LocalizedStringResource(
                "modelChoice.haiku",
                defaultValue: "Haiku",
                bundle: .module,
                comment: "Model menu item in the job editor: the Haiku model family. A product name.",
            )

        case .fable:
            LocalizedStringResource(
                "modelChoice.fable",
                defaultValue: "Fable",
                bundle: .module,
                comment: "Model menu item in the job editor: the Fable model family. A product name.",
            )
        }
    }
}
