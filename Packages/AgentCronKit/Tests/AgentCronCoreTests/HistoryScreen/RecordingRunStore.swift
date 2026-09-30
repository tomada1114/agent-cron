import AgentCronCore
import Foundation
import os

/// A store that records every retention cutoff it was handed.
final class RecordingRunStore: RunStoring {
    private let recorded = OSAllocatedUnfairLock<[Date]>(initialState: [])

    var cutoffs: [Date] {
        recorded.withLock { $0 }
    }

    func save(_: Run) {
        // Nothing to keep: only cutoffs are recorded.
    }

    func runs(in _: DateInterval) -> [Run] {
        []
    }

    func deleteRuns(olderThan cutoff: Date) -> Int {
        recorded.withLock { $0.append(cutoff) }
        return 0
    }
}
