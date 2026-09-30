import Foundation

/// One run in the History list.
public struct HistoryRow: Sendable, Identifiable {
    /// The run's identifier, which ``HistoryModel/selectedRunID`` holds.
    public let id: UUID
    /// The job the run belongs to.
    public let jobID: UUID
    /// The job's name when the run started.
    public let jobName: String
    /// When the run started.
    public let startedAt: Date
    /// The run's status badge.
    public let badge: OutcomeBadgeKind
    /// "2m 14s", or `nil` while the run has not ended.
    public let duration: LocalizedStringResource?
}
