import AgentCronCore
import os

/// The one fake of ``AgentCronCore/JobStoring``, shared by every test target.
///
/// A fake, not a mock (`.claude/rules/testing.md` › Fakes, not mocks): a real conforming
/// implementation that keeps the document in memory and records what it was asked, which
/// a test reads afterwards. `JobStoringContract` holds it to the same promises as
/// `FileJobStore`.
///
/// Its state sits behind a lock rather than an `@unchecked Sendable`, so the fake is
/// `Sendable` the way the port requires whichever actor a test calls it from.
package final class FakeJobStore: JobStoring {
    private struct State {
        var document: JobsDocument
        var savedDocuments: [JobsDocument] = []
        var loadCount = 0
        var loadError: StorageError?
        let saveError: StorageError?
    }

    private let state: OSAllocatedUnfairLock<State>

    /// The document ``load()`` answers now.
    package var document: JobsDocument {
        state.withLock { $0.document }
    }

    /// Every document a successful ``save(_:)`` was handed, in order.
    package var savedDocuments: [JobsDocument] {
        state.withLock { $0.savedDocuments }
    }

    /// How many times ``load()`` was called, failed calls included.
    package var loadCount: Int {
        state.withLock { $0.loadCount }
    }

    /// A store nothing was ever saved to, whose every call succeeds.
    package convenience init() {
        self.init(document: JobsDocument())
    }

    /// A store already holding `document`, whose every call succeeds.
    package convenience init(document: JobsDocument) {
        self.init(document: document, loadError: nil, saveError: nil)
    }

    /// A store nothing was ever saved to, where every ``load()`` throws `loadError` and
    /// every ``save(_:)`` throws `saveError` when one is given — a save that throws keeps
    /// nothing, as a refused write would.
    package convenience init(loadError: StorageError?, saveError: StorageError?) {
        self.init(document: JobsDocument(), loadError: loadError, saveError: saveError)
    }

    private init(document: JobsDocument, loadError: StorageError?, saveError: StorageError?) {
        state = OSAllocatedUnfairLock(initialState: State(
            document: document,
            loadError: loadError,
            saveError: saveError,
        ))
    }

    /// Makes every later ``load()`` throw `error`, or succeed again with `nil` — a store
    /// that becomes unreadable after the app first read it.
    package func loadsFail(with error: StorageError?) {
        state.withLock { $0.loadError = error }
    }

    package func load() throws(StorageError) -> JobsDocument {
        let outcome: Result<JobsDocument, StorageError> = state.withLock { current in
            current.loadCount += 1
            if let error = current.loadError {
                return .failure(error)
            }
            return .success(current.document)
        }
        return try outcome.get()
    }

    package func save(_ document: JobsDocument) throws(StorageError) {
        let failure: StorageError? = state.withLock { current in
            if let error = current.saveError {
                return error
            }
            current.document = document
            current.savedDocuments.append(document)
            return nil
        }
        if let failure {
            throw failure
        }
    }
}
