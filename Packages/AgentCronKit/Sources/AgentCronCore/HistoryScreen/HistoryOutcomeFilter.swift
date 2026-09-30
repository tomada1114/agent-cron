import Foundation

/// The History screen's outcome filter (`docs/product/ux-flows.md` S3).
public enum HistoryOutcomeFilter: String, Sendable, CaseIterable, Identifiable {
    /// Every run.
    case all
    /// Runs that did not do their job: failed, timed out, or skipped
    /// (`docs/product/requirements.md` §3.5).
    case failures
    /// Runs that never started.
    case skipped
    /// Runs that succeeded.
    case succeeded

    /// The order the picker lists the filters in (`docs/product/ux-flows.md` S3).
    public static let pickerOrder: [Self] = [.all, .failures, .succeeded, .skipped]

    public var id: Self {
        self
    }

    /// The filter's name in the picker.
    public var title: LocalizedStringResource {
        switch self {
        case .all:
            LocalizedStringResource(
                "history.outcomeFilter.all",
                defaultValue: "All",
                bundle: .module,
                comment: "History outcome filter: every run.",
            )

        case .failures:
            LocalizedStringResource(
                "history.outcomeFilter.failures",
                defaultValue: "Failures",
                bundle: .module,
                comment: "History outcome filter: failed, timed out, and skipped runs.",
            )

        case .succeeded:
            LocalizedStringResource(
                "history.outcomeFilter.succeeded",
                defaultValue: "Succeeded",
                bundle: .module,
                comment: "History outcome filter: runs that succeeded.",
            )

        case .skipped:
            LocalizedStringResource(
                "history.outcomeFilter.skipped",
                defaultValue: "Skipped",
                bundle: .module,
                comment: "History outcome filter: runs that never started.",
            )
        }
    }

    /// Whether a run that ended in `outcome` passes this filter.
    public func includes(_ outcome: RunOutcome) -> Bool {
        switch self {
        case .all:
            true

        case .failures:
            outcome == .failed || outcome == .timedOut || outcome == .skipped

        case .succeeded:
            outcome == .succeeded

        case .skipped:
            outcome == .skipped
        }
    }
}
