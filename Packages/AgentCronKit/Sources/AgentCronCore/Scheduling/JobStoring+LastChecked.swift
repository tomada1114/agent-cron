import Foundation

extension JobStoring {
    /// Reads the saved document, sets its `lastCheckedAt` to `date`, and writes it back
    /// with the jobs it was read with.
    ///
    /// The mirror of `updateJobs(_:)`: reading afresh rather than writing a copy read
    /// earlier keeps a job edit saved in between. A read that throws —
    /// ``StorageError/corruptJobs`` and ``StorageError/newerJobsVersion(schemaVersion:)``
    /// included — throws before anything is written, which is the port's rule that such a
    /// document is never saved over.
    func updateLastCheckedAt(_ date: Date) throws(StorageError) {
        var document = try load()
        document.lastCheckedAt = date
        try save(document)
    }
}
