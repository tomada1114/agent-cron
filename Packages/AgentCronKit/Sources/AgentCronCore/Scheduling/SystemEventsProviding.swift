import Foundation

/// Something that happened outside the app which the scheduler has to hear about
/// (ADR-0003): its timer came due, the Mac is going to sleep or woke up, or the wall
/// clock or time zone the schedules are read in moved.
///
/// Cases are declared alphabetically (SwiftLint's `sorted_enum_cases`).
public enum SystemEvent: Sendable, Hashable, CaseIterable {
    /// The system clock was set: a timer armed for a date may now fire early or late, so
    /// the next fire date is armed again.
    case clockChanged
    /// The Mac woke from sleep: missed times are caught up (``Dispatcher/didWake(now:)``).
    case didWake
    /// The date last given to ``SystemEventsProviding/armTimer(at:)`` was reached.
    case fireDateReached
    /// The system time zone changed: every schedule's wall times now fall on other
    /// instants, so the next fire date is armed again.
    case timeZoneChanged
    /// The Mac is about to sleep.
    case willSleep
}

/// A port: "tell me when the date I armed arrives, and when the Mac sleeps, wakes, or has
/// its clock or time zone changed", in Core's own vocabulary (ADR-0003).
///
/// Core declares it, `AgentCronPlatform`'s `WorkspaceSystemEvents` answers it from
/// `NSWorkspace`'s and Foundation's notifications and a timer, tests substitute
/// `FakeSystemEvents`, and `App/` — the composition root — hands the events to the
/// ``Dispatcher``. The port decides nothing: which date to arm, and what an event means
/// for the jobs, is Core's decision, where the coverage floor sees it.
///
/// The promises every implementation keeps — `SystemEventsProvidingContract` in
/// `AgentCronTestSupport` checks them against the fake (`just test`) and the real adapter
/// (`just test-local`); a new clause is stated here first, then added there:
///
/// 1. Each call to ``events()`` returns a new stream, and every event that happens while
///    a stream is open is delivered to it, once, in the order the events happened —
///    to every stream open at that moment.
/// 2. The Mac about to sleep is ``SystemEvent/willSleep``, waking is
///    ``SystemEvent/didWake``, the system clock set is ``SystemEvent/clockChanged``, and
///    the system time zone changed is ``SystemEvent/timeZoneChanged``.
/// 3. Once the date given to ``armTimer(at:)`` is reached — and not before —
///    ``SystemEvent/fireDateReached`` is delivered once. A date that is not in the future
///    fires promptly.
/// 4. Calling ``armTimer(at:)`` again replaces the timer: only the date armed last fires.
/// 5. When a stream's consumer stops — its iterating task is cancelled, or the stream is
///    released — the implementation stops observing anything on that stream's behalf.
///
/// A timer counts elapsed time, sleep included, from the moment it is armed: a date
/// passed while the Mac slept fires on wake, but a clock set forward or back does not move
/// it. That is why ``SystemEvent/clockChanged`` and ``SystemEvent/timeZoneChanged`` exist —
/// the caller re-arms on either.
public protocol SystemEventsProviding: Sendable {
    /// Starts delivering events on a new stream until its consumer stops. Nothing that
    /// happened before the call is replayed.
    func events() -> AsyncStream<SystemEvent>

    /// Delivers ``SystemEvent/fireDateReached`` once `date` is reached, replacing any
    /// timer armed before.
    func armTimer(at date: Date)
}
