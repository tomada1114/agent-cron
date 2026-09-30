import Foundation

/// Launch-time recovery of runs an earlier session left running (issue #49).
extension Dispatcher {
    /// The app launched: finishes every run a previous session left ``RunOutcome/running``
    /// — a quit or crash between a run's first save and its last — as failed
    /// (``Run/interrupted(at:)``), ending at `now`. Call it before the first
    /// ``didWake(now:)``.
    ///
    /// It reads the runs that started in the ``HistoryModel/retentionDays`` before `now`,
    /// the span History shows, which also outlasts the longest timeout
    /// (``Job/timeoutMinutesRange``). A run in ``runningRuns`` is this session's and is left
    /// alone. Recovered runs are not passed to ``onRunFinished``: they ended in an earlier
    /// session, and a notification at launch about a run long gone would be noise; History
    /// shows them. A store that cannot be read or written is logged and kept in
    /// ``storageError``.
    ///
    /// - Returns: The runs recorded as interrupted.
    @discardableResult
    public func recoverInterruptedRuns(now: Date) -> [Run] {
        let recent: [Run]
        do {
            recent = try runStore.runs(in: recoveryInterval(endingAt: now))
            storageError = nil
        } catch {
            report(error, while: "reading recent runs")
            return []
        }
        let ownIDs = Set(runningRuns.map(\.id))
        let interrupted = recent
            .filter { $0.outcome == .running && !ownIDs.contains($0.id) }
            .map { $0.interrupted(at: now) }
        for run in interrupted {
            save(run)
        }
        AppLog.scheduler.info("recovered \(interrupted.count, privacy: .public) interrupted runs")
        return interrupted
    }

    /// The span History shows before `now`: the runs recovery reads.
    private func recoveryInterval(endingAt now: Date) -> DateInterval {
        let start = environment.calendar.date(
            byAdding: .day,
            value: -HistoryModel.retentionDays,
            to: now,
        ) ?? now
        return DateInterval(start: min(start, now), end: now)
    }
}
