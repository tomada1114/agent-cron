import Foundation

/// What a status badge shows (ADR-0009 › Outcome colors and glyphs): every
/// ``RunOutcome`` plus the two badges that are not a run's outcome — an upcoming run and
/// the bypass warning. The glyph and the label always travel together, so color is never
/// the only thing that tells two badges apart; the color itself is the view's to pick.
public enum OutcomeBadgeKind: String, Sendable, CaseIterable {
    /// A job that runs with permission checks bypassed — a warning, not a ``RunOutcome``.
    case bypass
    /// A run that failed.
    case failed
    /// A run still in progress.
    case running
    /// A run that never started.
    case skipped
    /// A run the user stopped.
    case stopped
    /// A run that finished and reported success.
    case succeeded
    /// A run stopped because its timeout passed.
    case timedOut
    /// A scheduled run that has not started yet — not a ``RunOutcome``.
    case upcoming

    /// The SF Symbol drawn beside the label.
    public var symbolName: String {
        switch self {
        case .succeeded:
            "checkmark.circle.fill"

        case .failed:
            "xmark.circle.fill"

        case .timedOut:
            "timer"

        case .stopped:
            "stop.circle"

        case .skipped:
            "arrow.uturn.right.circle"

        case .running:
            "circle.dotted"

        case .upcoming:
            "circle"

        case .bypass:
            "exclamationmark.triangle.fill"
        }
    }

    /// The word shown beside the glyph, which is also the badge's accessibility label.
    public var label: LocalizedStringResource {
        switch self {
        case .succeeded:
            LocalizedStringResource(
                "outcomeBadge.succeeded",
                defaultValue: "Succeeded",
                bundle: .module,
                comment: "Text label of the succeeded status badge next to its glyph.",
            )

        case .failed:
            LocalizedStringResource(
                "outcomeBadge.failed",
                defaultValue: "Failed",
                bundle: .module,
                comment: "Text label of the failed status badge next to its glyph.",
            )

        case .timedOut:
            LocalizedStringResource(
                "outcomeBadge.timedOut",
                defaultValue: "Timed Out",
                bundle: .module,
                comment: "Text label of the timed out status badge next to its glyph.",
            )

        case .stopped:
            LocalizedStringResource(
                "outcomeBadge.stopped",
                defaultValue: "Stopped",
                bundle: .module,
                comment: "Text label of the stopped status badge next to its glyph.",
            )

        case .skipped:
            LocalizedStringResource(
                "outcomeBadge.skipped",
                defaultValue: "Skipped",
                bundle: .module,
                comment: "Text label of the skipped status badge next to its glyph.",
            )

        case .running:
            LocalizedStringResource(
                "outcomeBadge.running",
                defaultValue: "Running",
                bundle: .module,
                comment: "Text label of the running status badge next to its glyph.",
            )

        case .upcoming:
            LocalizedStringResource(
                "outcomeBadge.upcoming",
                defaultValue: "Upcoming",
                bundle: .module,
                comment: "Text label of the upcoming status badge next to its glyph.",
            )

        case .bypass:
            LocalizedStringResource(
                "outcomeBadge.bypass",
                defaultValue: "Bypass",
                bundle: .module,
                comment: "Text label of the bypass status badge next to its glyph.",
            )
        }
    }

    /// The badge for a run's outcome.
    public init(_ outcome: RunOutcome) {
        switch outcome {
        case .failed:
            self = .failed

        case .running:
            self = .running

        case .skipped:
            self = .skipped

        case .stopped:
            self = .stopped

        case .succeeded:
            self = .succeeded

        case .timedOut:
            self = .timedOut
        }
    }
}
