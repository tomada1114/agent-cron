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
}
