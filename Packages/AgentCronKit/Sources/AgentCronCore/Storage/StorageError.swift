/// Why a store could not read or write the app's files.
///
/// An enum a caller switches over: a corrupt or newer `jobs.json` stops the app with an
/// alert rather than overwriting the user's jobs (ADR-0005), while a refused read or
/// write is a plain failure to report. The payloads are Cocoa error codes and version
/// numbers — never a path, a job's name, or a file's contents.
public enum StorageError: Error, Equatable, Sendable {
    /// `jobs.json` is there but is not a jobs document: not JSON, no usable
    /// `schemaVersion`, or a job that does not decode. The file is left as it is.
    case corruptJobs
    /// `jobs.json` was written by a newer AgentCron whose format this build cannot read;
    /// `schemaVersion` is the version it declares. The file is left as it is.
    case newerJobsVersion(schemaVersion: Int)
    /// The file system refused a read; `code` is the Cocoa error code, for logs.
    case readFailed(code: Int)
    /// The file system refused a write, a new folder, or a removal; `code` is the Cocoa
    /// error code, for logs.
    case writeFailed(code: Int)
}
