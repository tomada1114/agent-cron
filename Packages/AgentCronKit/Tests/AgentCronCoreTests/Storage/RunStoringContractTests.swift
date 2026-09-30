import AgentCronCore
import AgentCronTestSupport
import Foundation
import os
import Testing

// MARK: - Stores that each break one promise

/// How far past a bound the broken stores below reach.
private enum Overreach {
    static let millisecond: TimeInterval = 0.001
}

private struct EndInclusive: RunStoring {
    let inner = FakeRunStore()

    func save(_ run: Run) throws(StorageError) {
        try inner.save(run)
    }

    func runs(in interval: DateInterval) -> [Run] {
        // Breaks clause 1: a run starting exactly at the end is answered.
        inner.runs(in: DateInterval(
            start: interval.start,
            end: interval.end.addingTimeInterval(Overreach.millisecond),
        ))
    }

    func deleteRuns(olderThan cutoff: Date) -> Int {
        inner.deleteRuns(olderThan: cutoff)
    }
}

private final class Duplicating: RunStoring {
    private let saved = OSAllocatedUnfairLock<[Run]>(initialState: [])

    func save(_ run: Run) {
        // Breaks clause 2: saving a run again keeps both copies.
        saved.withLock { $0.append(run) }
    }

    func runs(in interval: DateInterval) -> [Run] {
        saved.withLock { runs in
            runs.filter { interval.start <= $0.startedAt && $0.startedAt < interval.end }
                .sorted { $0.startedAt < $1.startedAt }
        }
    }

    func deleteRuns(olderThan cutoff: Date) -> Int {
        saved.withLock { runs in
            let before = runs.count
            runs.removeAll { $0.startedAt < cutoff }
            return before - runs.count
        }
    }
}

private struct InclusiveDeleting: RunStoring {
    let inner = FakeRunStore()

    func save(_ run: Run) throws(StorageError) {
        try inner.save(run)
    }

    func runs(in interval: DateInterval) -> [Run] {
        inner.runs(in: interval)
    }

    func deleteRuns(olderThan cutoff: Date) -> Int {
        // Breaks clause 3: a run starting exactly at the cutoff is deleted too.
        inner.deleteRuns(olderThan: cutoff.addingTimeInterval(Overreach.millisecond))
    }
}

private struct Unsorted: RunStoring {
    let inner = FakeRunStore()

    func save(_ run: Run) throws(StorageError) {
        try inner.save(run)
    }

    func runs(in interval: DateInterval) -> [Run] {
        // Breaks clause 1: newest first.
        inner.runs(in: interval).reversed()
    }

    func deleteRuns(olderThan cutoff: Date) -> Int {
        inner.deleteRuns(olderThan: cutoff)
    }
}

/// Both halves of the `RunStoring` contract suite that CI runs: the same
/// ``RunStoringContract`` against ``FakeRunStore`` and against ``FileRunStore`` in a
/// temporary folder, so neither can drift from the port's promises.
@Suite("RunStoring contract")
struct RunStoringContractTests {
    @Test
    func `the fake keeps the contract`() {
        RunStoringContract.check(FakeRunStore())
    }

    @Test
    func `the file store keeps the contract`() throws {
        try StorageFixture.withTemporaryRoot { root in
            RunStoringContract.check(FileRunStore(root: root))
        }
    }

    @Test
    func `the fake starts from the runs it is handed and records every save`() throws {
        let earlier = StorageFixture.run(startedAt: StorageFixture.scheduledAt)
        let store = FakeRunStore(runs: [earlier])
        let run = StorageFixture.finishedRun()
        try store.save(run)
        #expect(store.savedRuns == [run])
        #expect(store.runs == [earlier, run])
    }

    @Test
    func `the fake throws what it is told to, and keeps nothing from a failed save`() {
        let store = FakeRunStore(saveError: .writeFailed(code: 512))
        #expect(throws: StorageError.writeFailed(code: 512)) {
            try store.save(StorageFixture.finishedRun())
        }
        #expect(store.savedRuns.isEmpty)
        #expect(store.runs.isEmpty)
    }

    // The contract's own oracle: a store that breaks a promise must be reported, or
    // `check` would pass anything, the file store included.

    @Test
    func `a store that answers something before any save is reported`() {
        let store = FakeRunStore(runs: [StorageFixture.finishedRun()])
        #expect(RunStoringContract.violations(of: store)
            .first == "before any save: runs(in:) answered ?, expected nothing")
    }

    @Test
    func `a store that answers a run starting at the interval's end is reported`() {
        #expect(RunStoringContract.violations(of: EndInclusive()) == [
            "runs(in:) from the second start to the fourth answered b, c, d, expected b, c",
        ])
    }

    @Test
    func `a store that keeps both copies of a run saved twice is reported`() {
        #expect(RunStoringContract.violations(of: Duplicating()) == [
            "after saving the second run again: runs(in:) answered a, b*, b, c, d, expected a, b, c, d",
            "after deleting runs older than the second start: runs(in:) answered b*, b, c, d, expected b, c, d",
        ])
    }

    @Test
    func `a store that deletes a run starting at the cutoff is reported`() {
        #expect(RunStoringContract.violations(of: InclusiveDeleting()) == [
            "deleteRuns(olderThan:) the second start answered 2, expected 1",
            "after deleting runs older than the second start: runs(in:) answered c, d, expected b, c, d",
        ])
    }

    @Test
    func `a store that answers newest first is reported`() {
        #expect(RunStoringContract.violations(of: Unsorted()) == [
            "runs(in:) from the second start to the fourth answered c, b, expected b, c",
            "after saving the second run again: runs(in:) answered d, c, b, a, expected a, b, c, d",
            "after deleting runs older than the second start: runs(in:) answered d, c, b, expected b, c, d",
        ])
    }

    @Test
    func `a store that throws is reported`() {
        let store = FakeRunStore(saveError: .writeFailed(code: 513))
        #expect(RunStoringContract.violations(of: store) == [
            "saving four runs: save(_:) threw writeFailed(code: 513)",
        ])
    }
}
