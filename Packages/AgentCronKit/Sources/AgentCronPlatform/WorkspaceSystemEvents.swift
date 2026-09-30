import AgentCronCore
import AppKit
import os

/// One stream's observer on both centers: turns each notification it is registered for
/// into its ``AgentCronCore/SystemEvent`` and yields it, on the thread that posted it.
///
/// A selector observer rather than a block one, so there is no non-`Sendable` observation
/// token to keep: removing the relay removes every registration it has. A center holds
/// its observers weakly, so the stream's `onTermination` handler keeps the relay alive
/// until it removes it.
private final class Relay: NSObject, Sendable {
    private let continuation: AsyncStream<SystemEvent>.Continuation

    init(continuation: AsyncStream<SystemEvent>.Continuation) {
        self.continuation = continuation
    }

    @objc
    func workspaceEvent(_ notification: Notification) {
        deliver(WorkspaceSystemEvents.workspaceEvents[notification.name])
    }

    @objc
    func defaultCenterEvent(_ notification: Notification) {
        deliver(WorkspaceSystemEvents.defaultCenterEvents[notification.name])
    }

    private func deliver(_ event: SystemEvent?) {
        guard let event else {
            return
        }
        AppLog.scheduler.debug("system event: \(String(describing: event), privacy: .public)")
        continuation.yield(event)
    }
}

/// The adapter for ``AgentCronCore/SystemEventsProviding`` (ADR-0003): sleep and wake from
/// `NSWorkspace.shared.notificationCenter` — the only center that posts them — clock and
/// time-zone changes from `NotificationCenter.default`, and a timer on the continuous
/// clock.
///
/// Translation only: it maps each notification's name to a ``AgentCronCore/SystemEvent``
/// and counts down to the armed date. Which date to arm, and what an event means, is
/// Core's decision, which is why this file sits outside the coverage floor. What is
/// checked here instead is the translation, by the local-machine test
/// `WorkspaceSystemEventsTests`, which posts the notifications in-process: opt-in,
/// human-run (`just test-local`), and reported as skipped under `just test` and in CI.
///
/// The timer sleeps on `ContinuousClock`, which keeps counting while the Mac sleeps, so a
/// date passed during sleep fires on wake. It does not follow the wall clock: a clock set
/// forward or back leaves it counting the old interval, and the caller re-arms on
/// ``AgentCronCore/SystemEvent/clockChanged`` (the port's last paragraph).
public final class WorkspaceSystemEvents: SystemEventsProviding {
    private struct State {
        var streams: [UUID: AsyncStream<SystemEvent>.Continuation] = [:]
        var timer: Task<Void, Never>?
        var generation: UInt64 = 0
    }

    /// Posted by `NSWorkspace.shared.notificationCenter` only; another center never
    /// receives them.
    static let workspaceEvents: [Notification.Name: SystemEvent] = [
        NSWorkspace.willSleepNotification: .willSleep,
        NSWorkspace.didWakeNotification: .didWake,
    ]

    /// Posted by `NotificationCenter.default`.
    static let defaultCenterEvents: [Notification.Name: SystemEvent] = [
        .NSSystemClockDidChange: .clockChanged,
        .NSSystemTimeZoneDidChange: .timeZoneChanged,
    ]

    private let state = OSAllocatedUnfairLock(initialState: State())

    /// How many streams are observed for right now: one per stream whose consumer has not
    /// stopped. The contract reads it to see that a stopped consumer's observers are gone.
    package var openStreamCount: Int {
        state.withLock { $0.streams.count }
    }

    public init() {
        // Nothing to set up: each stream registers its own observers.
    }

    private static func observe(with relay: Relay) {
        let workspace = NSWorkspace.shared.notificationCenter
        for name in workspaceEvents.keys {
            workspace.addObserver(
                relay,
                selector: #selector(Relay.workspaceEvent(_:)),
                name: name,
                object: nil,
            )
        }
        for name in defaultCenterEvents.keys {
            NotificationCenter.default.addObserver(
                relay,
                selector: #selector(Relay.defaultCenterEvent(_:)),
                name: name,
                object: nil,
            )
        }
    }

    /// Registers this stream's observers on both centers before returning, so an event
    /// posted right after the call is not missed; they are removed when its consumer stops.
    public func events() -> AsyncStream<SystemEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: SystemEvent.self)
        let id = UUID()
        let relay = Relay(continuation: continuation)
        state.withLock { $0.streams[id] = continuation }
        Self.observe(with: relay)
        continuation.onTermination = { [weak self] _ in
            NSWorkspace.shared.notificationCenter.removeObserver(relay)
            NotificationCenter.default.removeObserver(relay)
            _ = self?.state.withLock { $0.streams.removeValue(forKey: id) }
        }
        return stream
    }

    /// Cancels the timer armed before, then counts down from now to `date`; a date not in
    /// the future fires at once.
    public func armTimer(at date: Date) {
        let delay = Duration.seconds(date.timeIntervalSinceNow)
        let (previous, generation) = state.withLock { current in
            let previous = current.timer
            current.timer = nil
            current.generation &+= 1
            return (previous, current.generation)
        }
        previous?.cancel()
        let timer = Task { [weak self] in
            do {
                try await Task.sleep(until: .now + delay, clock: .continuous)
            } catch {
                return
            }
            self?.fire(generation)
        }
        let isStale = state.withLock { current in
            guard current.generation == generation else {
                return true
            }
            current.timer = timer
            return false
        }
        if isStale {
            timer.cancel()
        }
        AppLog.scheduler.debug("timer armed to fire in \(delay, privacy: .public)")
    }

    /// Delivers ``AgentCronCore/SystemEvent/fireDateReached`` unless the timer was
    /// re-armed since `generation` was.
    private func fire(_ generation: UInt64) {
        let streams = state.withLock { current in
            guard current.generation == generation else {
                return [AsyncStream<SystemEvent>.Continuation]()
            }
            current.timer = nil
            return Array(current.streams.values)
        }
        AppLog.scheduler.debug("timer fired for \(streams.count, privacy: .public) streams")
        for stream in streams {
            stream.yield(.fireDateReached)
        }
    }

    deinit {
        let (timer, streams) = state.withLock { ($0.timer, Array($0.streams.values)) }
        timer?.cancel()
        for stream in streams {
            stream.finish()
        }
    }
}
