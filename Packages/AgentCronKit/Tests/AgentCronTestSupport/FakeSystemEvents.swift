import AgentCronCore
import Foundation
import os

/// The one fake of ``AgentCronCore/SystemEventsProviding``, shared by every test target.
///
/// A fake, not a mock (`.claude/rules/testing.md` › Fakes, not mocks): a real conforming
/// implementation whose time moves only when a test calls ``advance(by:)`` and whose OS
/// events happen only when a test calls ``send(_:)``, recording every date it was armed
/// with. `SystemEventsProvidingContract` holds it to the same promises as
/// `WorkspaceSystemEvents`.
///
/// Its state sits behind a lock rather than an `@unchecked Sendable`, so the fake is
/// `Sendable` the way the port requires whichever actor a test calls it from.
package final class FakeSystemEvents: SystemEventsProviding {
    private struct State {
        var now: Date
        var pendingDate: Date?
        var armedDates: [Date] = []
        var streams: [UUID: AsyncStream<SystemEvent>.Continuation] = [:]
    }

    /// Where a fake's clock starts unless a test says otherwise: 2023-11-14 22:13:20 UTC.
    package static let defaultStart = Date(timeIntervalSince1970: defaultStartSeconds)

    private static let defaultStartSeconds: TimeInterval = 1_700_000_000

    private let state: OSAllocatedUnfairLock<State>

    /// The fake's current time, which only ``advance(by:)`` moves.
    package var now: Date {
        state.withLock { $0.now }
    }

    /// The date armed and not yet reached, or `nil` when no timer is pending.
    package var pendingDate: Date? {
        state.withLock { $0.pendingDate }
    }

    /// Every date ``armTimer(at:)`` was called with, in order.
    package var armedDates: [Date] {
        state.withLock { $0.armedDates }
    }

    /// How many streams have a consumer right now.
    package var openStreamCount: Int {
        state.withLock { $0.streams.count }
    }

    /// A fake whose clock reads ``defaultStart`` until it is advanced.
    package convenience init() {
        self.init(now: Self.defaultStart)
    }

    /// A fake whose clock reads `now` until it is advanced.
    package init(now: Date) {
        state = OSAllocatedUnfairLock(initialState: State(now: now))
    }

    package func events() -> AsyncStream<SystemEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: SystemEvent.self)
        let id = UUID()
        continuation.onTermination = { [weak self] _ in
            _ = self?.state.withLock { $0.streams.removeValue(forKey: id) }
        }
        state.withLock { $0.streams[id] = continuation }
        return stream
    }

    package func armTimer(at date: Date) {
        let firesNow = state.withLock { current in
            current.armedDates.append(date)
            current.pendingDate = date > current.now ? date : nil
            return current.pendingDate == nil
        }
        if firesNow {
            send(.fireDateReached)
        }
    }

    /// Moves the fake's time forward, firing the pending timer once its date is reached.
    package func advance(by duration: Duration) {
        let reached = state.withLock { current in
            current.now = current.now.addingTimeInterval(duration / .seconds(1))
            guard let pending = current.pendingDate, pending <= current.now else {
                return false
            }
            current.pendingDate = nil
            return true
        }
        if reached {
            send(.fireDateReached)
        }
    }

    /// Delivers `event` to every open stream, as the OS would when it happens.
    package func send(_ event: SystemEvent) {
        let streams = state.withLock { Array($0.streams.values) }
        for stream in streams {
            stream.yield(event)
        }
    }
}
