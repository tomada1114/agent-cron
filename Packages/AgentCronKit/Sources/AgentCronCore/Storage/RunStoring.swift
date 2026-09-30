import Foundation

/// A port: "keep each run's record, find the ones that started in a span of time, and
/// forget the old ones" (ADR-0005).
///
/// Core declares it, ``FileRunStore`` answers it with one JSON file per run under
/// Application Support, and tests substitute `FakeRunStore`. It is `Sendable` and trades
/// in value types, so a store can be handed across actors. When to delete — 90 days,
/// on launch and daily (requirements §3.4) — is the caller's decision, not the store's.
///
/// The promises every implementation keeps — `RunStoringContract` in
/// `AgentCronTestSupport` checks them against the fake and the file store (`just test`); a
/// new clause is stated here first, then added there:
///
/// 1. ``runs(in:)`` answers exactly the saved runs whose ``Run/startedAt`` lies in the
///    interval — its start included, its end excluded, so adjacent intervals never
///    share a run — oldest first, with every field kept and dates to the millisecond.
/// 2. Saving a run again — the same ``Run/id`` and ``Run/startedAt`` — replaces the
///    earlier save: a run written when it starts and again when it ends is one run.
/// 3. ``deleteRuns(olderThan:)`` removes every saved run that started strictly before
///    the cutoff, keeps one that started exactly at it, and answers how many it removed.
public protocol RunStoring: Sendable {
    /// Saves `run`, replacing an earlier save of the same run.
    func save(_ run: Run) throws(StorageError)

    /// The saved runs that started in `interval`, oldest first.
    func runs(in interval: DateInterval) throws(StorageError) -> [Run]

    /// Removes the saved runs that started before `cutoff` and answers how many.
    func deleteRuns(olderThan cutoff: Date) throws(StorageError) -> Int
}
