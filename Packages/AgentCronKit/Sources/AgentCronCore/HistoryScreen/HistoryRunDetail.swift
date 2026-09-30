import Foundation

/// The selected run's detail pane (`docs/product/requirements.md` §3.4).
public struct HistoryRunDetail: Sendable {
    /// The run itself: job name, trigger, scheduled/start/end times, outcome, exit code,
    /// session id, result, and the prompt snapshot.
    public let run: Run
    /// The run's status badge.
    public let badge: OutcomeBadgeKind
    /// How the run was started.
    public let trigger: LocalizedStringResource
    /// "2m 14s", or `nil` while the run has not ended.
    public let duration: LocalizedStringResource?
    /// The cost in US dollars, or `nil` when the agent reported none, so the pane omits it.
    public let cost: String?
}
