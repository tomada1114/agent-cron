import AgentCronCore
import Foundation
import os

/// The one fake of ``AgentCronCore/RunStoring``, shared by every test target.
///
/// A fake, not a mock (`.claude/rules/testing.md` › Fakes, not mocks): a real conforming
/// implementation that keeps runs in memory and records every save, which a test reads
/// afterwards. `RunStoringContract` holds it to the same promises as `FileRunStore`.
///
/// Its state sits behind a lock rather than an `@unchecked Sendable`, so the fake is
/// `Sendable` the way the port requires whichever actor a test calls it from.
package final class FakeRunStore: RunStoring {
    private struct State {
        var runs: [Run]
        var savedRuns: [Run] = []
        let saveError: StorageError?
    }

    private let state: OSAllocatedUnfairLock<State>

    /// Every run held now, oldest first.
    package var runs: [Run] {
        state.withLock { Self.oldestFirst($0.runs) }
    }

    /// Every run a successful ``save(_:)`` was handed, in order, repeats included.
    package var savedRuns: [Run] {
        state.withLock { $0.savedRuns }
    }

    /// A store nothing was ever saved to, whose every call succeeds.
    package convenience init() {
        self.init(runs: [])
    }

    /// A store already holding `runs`, whose every call succeeds.
    package convenience init(runs: [Run]) {
        self.init(runs: runs, saveError: nil)
    }

    /// A store nothing was ever saved to, where every ``save(_:)`` throws `saveError` — a
    /// save that throws keeps nothing, as a refused write would.
    package convenience init(saveError: StorageError) {
        self.init(runs: [], saveError: saveError)
    }

    private init(runs: [Run], saveError: StorageError?) {
        state = OSAllocatedUnfairLock(initialState: State(runs: runs, saveError: saveError))
    }

    private static func oldestFirst(_ runs: [Run]) -> [Run] {
        runs.sorted { lhs, rhs in
            (lhs.startedAt, lhs.id.uuidString) < (rhs.startedAt, rhs.id.uuidString)
        }
    }

    package func save(_ run: Run) throws(StorageError) {
        let failure: StorageError? = state.withLock { current in
            if let error = current.saveError {
                return error
            }
            current.runs.removeAll { $0.id == run.id && $0.startedAt == run.startedAt }
            current.runs.append(run)
            current.savedRuns.append(run)
            return nil
        }
        if let failure {
            throw failure
        }
    }

    package func runs(in interval: DateInterval) -> [Run] {
        state.withLock { current in
            Self.oldestFirst(current.runs.filter { run in
                interval.start <= run.startedAt && run.startedAt < interval.end
            })
        }
    }

    package func deleteRuns(olderThan cutoff: Date) -> Int {
        state.withLock { current in
            let before = current.runs.count
            current.runs.removeAll { $0.startedAt < cutoff }
            return before - current.runs.count
        }
    }
}
