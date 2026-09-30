import AgentCronCore
import Foundation

/// A store whose every call fails, for the error paths.
struct ThrowingRunStore: RunStoring {
    static let code = 5

    func save(_: Run) throws(StorageError) {
        throw .writeFailed(code: Self.code)
    }

    func runs(in _: DateInterval) throws(StorageError) -> [Run] {
        throw .readFailed(code: Self.code)
    }

    func deleteRuns(olderThan _: Date) throws(StorageError) -> Int {
        throw .writeFailed(code: Self.code)
    }
}
