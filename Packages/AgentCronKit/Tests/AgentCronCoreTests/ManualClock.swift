import Foundation
import os

/// A clock that moves only when a test calls ``advance(by:)``, and the wall-clock date
/// that moves with it.
///
/// The standard library ships no test clock, so the test target keeps its own here
/// (`designing-core-logic` › Inject time). A type under test that waits takes it as its
/// `any Clock<Duration>`, and one that reads "now" takes ``date`` as its
/// `() -> Date`, so both of its time sources advance together and never disagree.
///
/// State sits behind a lock, so the clock is `Sendable` without `@unchecked`.
final class ManualClock: Clock {
    /// A point on this clock: how far it had been advanced.
    struct Instant: InstantProtocol {
        let offset: Duration

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.offset < rhs.offset
        }

        func advanced(by duration: Duration) -> Self {
            Self(offset: offset + duration)
        }

        func duration(to other: Self) -> Duration {
            other.offset - offset
        }
    }

    private struct Sleeper {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private struct State {
        var now = Instant(offset: .zero)
        var nextSleeperID = 0
        var sleepers: [Int: Sleeper] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let start: Date

    var now: Instant {
        state.withLock { $0.now }
    }

    var minimumResolution: Duration {
        .zero
    }

    /// The wall-clock date at ``now``: `start` plus however far the clock has advanced.
    var date: Date {
        start.addingTimeInterval(now.offset / .seconds(1))
    }

    /// Creates a clock whose ``date`` reads `start` until it is advanced.
    init(start: Date) {
        self.start = start
    }

    /// Suspends until the clock is advanced to `deadline`, or throws `CancellationError`
    /// when the waiting task is cancelled first.
    func sleep(until deadline: Instant, tolerance _: Duration?) async throws {
        let id = state.withLock { current in
            current.nextSleeperID += 1
            return current.nextSleeperID
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                // Checked under the lock the cancellation handler also takes, so a
                // cancellation either sees this sleeper registered or is seen here.
                let immediate: Result<Void, any Error>? = state.withLock { current in
                    if Task.isCancelled {
                        return .failure(CancellationError())
                    }
                    if deadline <= current.now {
                        return .success(())
                    }
                    current.sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                    return nil
                }
                if let immediate {
                    continuation.resume(with: immediate)
                }
            }
        } onCancel: {
            let sleeper = state.withLock { $0.sleepers.removeValue(forKey: id) }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Moves the clock forward and wakes every sleeper whose deadline has now passed.
    func advance(by duration: Duration) {
        let due = state.withLock { current in
            current.now = current.now.advanced(by: duration)
            let reached = current.now
            let dueIDs = current.sleepers.filter { $0.value.deadline <= reached }.map(\.key)
            return dueIDs.compactMap { current.sleepers.removeValue(forKey: $0) }
        }
        for sleeper in due {
            sleeper.continuation.resume()
        }
    }
}
