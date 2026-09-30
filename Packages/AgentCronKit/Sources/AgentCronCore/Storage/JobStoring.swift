import Foundation

/// Everything `jobs.json` keeps: the saved jobs and the scheduler's last check.
///
/// One document rather than two files so a save writes jobs and scheduler state
/// together, atomically (ADR-0005).
public struct JobsDocument: Sendable, Equatable {
    /// Every saved job, in the order the job list shows them.
    public var jobs: [Job]
    /// When the scheduler last looked for due times; `nil` until it first has. A wake or
    /// a launch catches up the times missed since then (ADR-0003).
    public var lastCheckedAt: Date?

    /// Makes a document; the defaults are what a first launch starts from.
    public init(jobs: [Job] = [], lastCheckedAt: Date? = nil) {
        self.jobs = jobs
        self.lastCheckedAt = lastCheckedAt
    }
}

/// A port: "keep the jobs document between launches, and give it back" (ADR-0005).
///
/// Core declares it, ``FileJobStore`` answers it with `jobs.json` in Application
/// Support, and tests substitute `FakeJobStore`. It is `Sendable` and trades in value
/// types, so a store can be handed across actors.
///
/// The promises every implementation keeps — `JobStoringContract` in
/// `AgentCronTestSupport` checks them against the fake and the file store (`just test`); a
/// new clause is stated here first, then added there:
///
/// 1. ``load()`` before anything was ever saved answers an empty document — no jobs, no
///    last check — so a first launch is not an error.
/// 2. ``load()`` after ``save(_:)`` answers the saved document: every job and field, in
///    the same order, with dates kept to the millisecond.
/// 3. A ``save(_:)`` replaces the whole previous document; nothing of an earlier save
///    survives it.
public protocol JobStoring: Sendable {
    /// Reads the saved document.
    ///
    /// Throws ``StorageError/corruptJobs`` or ``StorageError/newerJobsVersion(schemaVersion:)``
    /// for a document it cannot read, which a caller must never answer by saving over it.
    func load() throws(StorageError) -> JobsDocument

    /// Replaces the saved document with `document`.
    func save(_ document: JobsDocument) throws(StorageError)
}
