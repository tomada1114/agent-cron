import AgentCronCore
import os

/// Collects what a ``AgentCronCore/SystemEventsProviding`` stream delivers, so a test can
/// wait for the events it expects without iterating the stream itself.
///
/// Waiting is bounded, but the bound is only how long a *missing* event is waited for:
/// an event that arrives ends the wait at once, so a passing test waits on no clock.
package final class SystemEventRecorder: Sendable {
    private struct Waiter {
        let isSatisfied: @Sendable ([SystemEvent]) -> Bool
        let continuation: CheckedContinuation<Void, Never>
    }

    private struct State {
        var events: [SystemEvent] = []
        var nextWaiterID = 0
        var waiters: [Int: Waiter] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    /// Every event recorded so far, in the order it arrived.
    package var events: [SystemEvent] {
        state.withLock { $0.events }
    }

    package init() {
        // Starts empty; `consume(_:)` or `record(_:)` fills it.
    }

    /// Records every event `stream` delivers until the returned task is cancelled or the
    /// stream ends.
    package func consume(_ stream: AsyncStream<SystemEvent>) -> Task<Void, Never> {
        Task {
            for await event in stream {
                record(event)
            }
        }
    }

    /// Appends `event` and wakes whoever waits for what has now been heard.
    package func record(_ event: SystemEvent) {
        let due = state.withLock { current in
            current.events.append(event)
            let heard = current.events
            let reachedIDs = current.waiters.filter { $0.value.isSatisfied(heard) }.map(\.key)
            return reachedIDs.compactMap { current.waiters.removeValue(forKey: $0)?.continuation }
        }
        for continuation in due {
            continuation.resume()
        }
    }

    /// Returns once at least `count` events have been recorded, or once `patience` has
    /// passed without that many — whichever comes first.
    package func wait(untilCount count: Int, patience: Duration) async {
        await wait(patience: patience) { $0.count >= count }
    }

    /// Returns once the events recorded so far satisfy `isSatisfied`, or once `patience`
    /// has passed without that — whichever comes first.
    package func wait(
        patience: Duration,
        until isSatisfied: @escaping @Sendable ([SystemEvent]) -> Bool,
    ) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.reach(isSatisfied) }
            group.addTask { try? await Task.sleep(for: patience) }
            await group.next()
            group.cancelAll()
        }
    }

    private func reach(_ isSatisfied: @escaping @Sendable ([SystemEvent]) -> Bool) async {
        let id = state.withLock { current in
            current.nextWaiterID += 1
            return current.nextWaiterID
        }
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // Checked under the lock `record(_:)` and the cancellation handler take, so
                // an event or a cancellation either sees this waiter or is seen here.
                let ready = state.withLock { current in
                    if Task.isCancelled || isSatisfied(current.events) {
                        return true
                    }
                    current.waiters[id] = Waiter(
                        isSatisfied: isSatisfied,
                        continuation: continuation,
                    )
                    return false
                }
                if ready {
                    continuation.resume()
                }
            }
        } onCancel: {
            let waiter = state.withLock { $0.waiters.removeValue(forKey: id) }
            waiter?.continuation.resume()
        }
    }
}
