import Foundation

/// Why the History list shows no runs — two different states with different copy
/// (`docs/design/ux-guidelines.md` › States).
public enum HistoryEmptyState: Sendable, Equatable {
    /// Runs exist, but none passes the filters.
    case noMatches
    /// No run was ever recorded.
    case noRuns

    /// What the list says instead of rows.
    public var message: LocalizedStringResource {
        switch self {
        case .noMatches:
            LocalizedStringResource(
                "history.empty.noMatches",
                defaultValue: "No runs match these filters.",
                bundle: .module,
                comment: "History list placeholder when the filters hide every run.",
            )

        case .noRuns:
            LocalizedStringResource(
                "history.empty.noRuns",
                defaultValue: "No runs yet. Runs appear here after a job runs.",
                bundle: .module,
                comment: "History list placeholder when no run was ever recorded.",
            )
        }
    }
}
