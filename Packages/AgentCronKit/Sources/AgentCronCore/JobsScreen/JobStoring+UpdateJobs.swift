extension JobStoring {
    /// Reads the saved document, applies `change` to its jobs, and writes it back with
    /// the `lastCheckedAt` it was read with.
    ///
    /// Reading afresh rather than writing a copy held since launch keeps the scheduler's
    /// latest `lastCheckedAt`. A read that throws — ``StorageError/corruptJobs`` and
    /// ``StorageError/newerJobsVersion(schemaVersion:)`` included — throws before anything
    /// is written, which is the port's rule that such a document is never saved over.
    /// - Returns: The document as written.
    func updateJobs(_ change: (inout [Job]) -> Void) throws(StorageError) -> JobsDocument {
        var document = try load()
        change(&document.jobs)
        try save(document)
        return document
    }
}
