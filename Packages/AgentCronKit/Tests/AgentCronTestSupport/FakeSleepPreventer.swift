import AgentCronCore
import os

/// The one fake of ``AgentCronCore/SleepPreventing``, shared by every test target.
///
/// A fake, not a mock (`.claude/rules/testing.md` › Fakes, not mocks): a real conforming
/// implementation that keeps its holds in memory and records what it was asked, which a
/// test reads afterwards. `SleepPreventingContract` holds it to the same promises as
/// `PowerAssertionSleepPreventer`.
///
/// Its state sits behind a lock rather than an `@unchecked Sendable`, so the fake is
/// `Sendable` the way the port requires whichever actor a test calls it from.
package final class FakeSleepPreventer: SleepPreventing {
    private struct State {
        var nextID: UInt64 = 1
        var active: [SleepPreventionToken: String] = [:]
        var holdRequests: [String] = []
        var failures: [SleepPreventionError]
    }

    private let state: OSAllocatedUnfairLock<State>

    /// How many holds are in force right now.
    package var activeCount: Int {
        state.withLock { $0.active.count }
    }

    /// The reasons of the holds in force right now, oldest first.
    package var activeReasons: [String] {
        state.withLock { current in
            current.active.sorted { $0.key.id < $1.key.id }.map(\.value)
        }
    }

    /// Every reason ``hold(reason:)`` was called with, in order, failed calls included.
    package var holdRequests: [String] {
        state.withLock { $0.holdRequests }
    }

    /// A preventer whose every ``hold(reason:)`` succeeds.
    package convenience init() {
        self.init(failingWith: [])
    }

    /// The first `failures.count` calls to ``hold(reason:)`` throw these, in order; every
    /// later call succeeds.
    package init(failingWith failures: [SleepPreventionError]) {
        state = OSAllocatedUnfairLock(initialState: State(failures: failures))
    }

    /// How many holds named `reason` are in force right now.
    package func activeHolds(named reason: String) -> Int {
        state.withLock { current in
            current.active.values.count { $0 == reason }
        }
    }

    package func hold(reason: String) throws(SleepPreventionError) -> SleepPreventionToken {
        let outcome: Result<SleepPreventionToken, SleepPreventionError> = state
            .withLock { current in
                current.holdRequests.append(reason)
                if !current.failures.isEmpty {
                    return .failure(current.failures.removeFirst())
                }
                let token = SleepPreventionToken(id: current.nextID)
                current.nextID += 1
                current.active[token] = reason
                return .success(token)
            }
        return try outcome.get()
    }

    package func release(_ token: SleepPreventionToken) {
        _ = state.withLock { $0.active.removeValue(forKey: token) }
    }
}
