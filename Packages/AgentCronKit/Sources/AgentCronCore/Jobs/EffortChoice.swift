import Foundation

/// How much reasoning effort a run asks the agent for.
///
/// Cases are declared alphabetically (SwiftLint's `sorted_enum_cases`); ``allCases`` is
/// the order the editor lists them in. The raw value is what `jobs.json` and each run
/// file store, so changing it is a file-format change.
public enum EffortChoice: String, Sendable, Codable, CaseIterable {
    /// Pass no effort level, so the agent's own configured default applies. The default
    /// for a new job.
    case `default`
    /// A high effort level.
    case high
    /// The lowest effort level.
    case low
    /// The highest effort level; not every model supports it.
    case max
    /// A middle effort level.
    case medium
    /// Above high; not every model supports it.
    case xhigh

    /// Every choice, in the order the editor lists them: Default, then lowest to highest.
    public static let allCases: [Self] = [.default, .low, .medium, .high, .xhigh, .max]

    /// The choice's title in the job editor's Effort menu.
    public var title: LocalizedStringResource {
        switch self {
        case .default:
            LocalizedStringResource(
                "effortChoice.default",
                defaultValue: "Default",
                bundle: .module,
                comment: "Effort menu item in the job editor: pass no effort, so the agent's own default applies.",
            )

        case .low:
            LocalizedStringResource(
                "effortChoice.low",
                defaultValue: "Low",
                bundle: .module,
                comment: "Effort menu item in the job editor: the lowest reasoning effort.",
            )

        case .medium:
            LocalizedStringResource(
                "effortChoice.medium",
                defaultValue: "Medium",
                bundle: .module,
                comment: "Effort menu item in the job editor: a middle reasoning effort.",
            )

        case .high:
            LocalizedStringResource(
                "effortChoice.high",
                defaultValue: "High",
                bundle: .module,
                comment: "Effort menu item in the job editor: a high reasoning effort.",
            )

        case .xhigh:
            LocalizedStringResource(
                "effortChoice.xhigh",
                defaultValue: "Extra High",
                bundle: .module,
                comment: "Effort menu item in the job editor: above high reasoning effort.",
            )

        case .max:
            LocalizedStringResource(
                "effortChoice.max",
                defaultValue: "Max",
                bundle: .module,
                comment: "Effort menu item in the job editor: the highest reasoning effort.",
            )
        }
    }
}
