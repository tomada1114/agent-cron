import AgentCronCore
import Foundation

/// A run store whose every read fails, for the load-failure path.
struct FailingRunStore: RunStoring {
    static let readCode = 2
    static let writeCode = 1

    func save(_: Run) throws(StorageError) {
        throw .writeFailed(code: Self.writeCode)
    }

    func runs(in _: DateInterval) throws(StorageError) -> [Run] {
        throw .readFailed(code: Self.readCode)
    }

    func deleteRuns(olderThan _: Date) throws(StorageError) -> Int {
        throw .writeFailed(code: Self.writeCode)
    }
}
