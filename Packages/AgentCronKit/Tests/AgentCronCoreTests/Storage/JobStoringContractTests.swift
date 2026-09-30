import AgentCronCore
import AgentCronTestSupport
import Foundation
import os
import Testing

// MARK: - Stores that each break one promise

private struct Forgetful: JobStoring {
    func load() -> JobsDocument {
        JobsDocument()
    }

    func save(_: JobsDocument) {
        // Breaks clause 2: nothing saved is ever answered.
    }
}

private final class Appending: JobStoring {
    private let document = OSAllocatedUnfairLock(initialState: JobsDocument())

    func load() -> JobsDocument {
        document.withLock { $0 }
    }

    func save(_ saved: JobsDocument) {
        // Breaks clause 3: a save adds to the previous document instead of replacing it.
        document.withLock { current in
            current.jobs += saved.jobs
            current.lastCheckedAt = saved.lastCheckedAt ?? current.lastCheckedAt
        }
    }
}

private struct Mangling: JobStoring {
    let inner = FakeJobStore()

    func load() throws(StorageError) -> JobsDocument {
        try inner.load()
    }

    func save(_ document: JobsDocument) throws(StorageError) {
        // Breaks clause 2: what is answered is not what was saved.
        var changed = document
        if !changed.jobs.isEmpty {
            changed.jobs[0].prompt += " "
        }
        try inner.save(changed)
    }
}

/// Both halves of the `JobStoring` contract suite that CI runs: the same
/// ``JobStoringContract`` against ``FakeJobStore`` and against ``FileJobStore`` in a
/// temporary folder, so neither can drift from the port's promises.
@Suite("JobStoring contract")
struct JobStoringContractTests {
    @Test
    func `the fake keeps the contract`() {
        JobStoringContract.check(FakeJobStore())
    }

    @Test
    func `the file store keeps the contract`() throws {
        try StorageFixture.withTemporaryRoot { root in
            JobStoringContract.check(FileJobStore(root: root))
        }
    }

    @Test
    func `the fake records what it was asked`() throws {
        let store = FakeJobStore()
        let document = StorageFixture.jobsDocument()
        try store.save(document)
        _ = try store.load()
        #expect(store.savedDocuments == [document])
        #expect(store.document == document)
        #expect(store.loadCount == 1)
    }

    @Test
    func `the fake throws what it is told to, and keeps nothing from a failed save`() {
        let store = FakeJobStore(loadError: .corruptJobs, saveError: .writeFailed(code: 512))
        #expect(throws: StorageError.corruptJobs) {
            try store.load()
        }
        #expect(throws: StorageError.writeFailed(code: 512)) {
            try store.save(StorageFixture.jobsDocument())
        }
        #expect(store.savedDocuments.isEmpty)
        #expect(store.document == JobsDocument())
    }

    // The contract's own oracle: a store that breaks a promise must be reported, or
    // `check` would pass anything, the file store included.

    @Test
    func `a store that answers something before any save is reported`() {
        let store = FakeJobStore(document: StorageFixture.jobsDocument())
        #expect(JobStoringContract.violations(of: store) == [
            "before any save: load() answered 2 jobs, last checked set, "
                + "expected 0 jobs, last checked nil",
        ])
    }

    @Test
    func `a store that forgets what it saved is reported`() {
        #expect(JobStoringContract.violations(of: Forgetful()) == [
            "after saving two jobs: load() answered 0 jobs, last checked nil, "
                + "expected 2 jobs, last checked set",
            "after saving one job over two: load() answered 0 jobs, last checked nil, "
                + "expected 1 jobs, last checked nil",
        ])
    }

    @Test
    func `a store that adds to the previous save instead of replacing it is reported`() {
        #expect(JobStoringContract.violations(of: Appending()) == [
            "after saving one job over two: load() answered 3 jobs, last checked set, "
                + "expected 1 jobs, last checked nil",
        ])
    }

    @Test
    func `a store that changes a saved job is reported`() {
        #expect(JobStoringContract.violations(of: Mangling()) == [
            "after saving two jobs: load() answered a document whose jobs differ from those saved",
            "after saving one job over two: load() answered a document whose jobs differ from those saved",
        ])
    }

    @Test
    func `a store that throws is reported`() {
        let store = FakeJobStore(
            loadError: .readFailed(code: 257),
            saveError: .writeFailed(code: 513),
        )
        #expect(JobStoringContract.violations(of: store) == [
            "before any save: load() threw readFailed(code: 257)",
            "saving two jobs: save(_:) threw writeFailed(code: 513)",
            "saving one job over two: save(_:) threw writeFailed(code: 513)",
        ])
    }
}
