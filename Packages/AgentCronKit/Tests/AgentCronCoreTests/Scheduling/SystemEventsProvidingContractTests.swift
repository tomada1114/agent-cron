import AgentCronCore
import AgentCronTestSupport
import Foundation
import os
import Testing

// MARK: - Providers that each break one promise

/// Short, because every provider below is expected to leave an event missing: the
/// contract waits this long before calling it so. Nothing passing waits on it.
private let missingAfter = Duration.milliseconds(missingAfterMilliseconds)

private let missingAfterMilliseconds = 50

/// Breaks clause 3: a timer is never armed.
private struct NeverFiring: SystemEventsProviding {
    let inner = FakeSystemEvents()

    func events() -> AsyncStream<SystemEvent> {
        inner.events()
    }

    func armTimer(at _: Date) {
        // Arms nothing.
    }
}

/// Breaks clause 3: every date fires the moment it is armed.
private struct FiringOnArm: SystemEventsProviding {
    let inner = FakeSystemEvents()

    func events() -> AsyncStream<SystemEvent> {
        inner.events()
    }

    func armTimer(at _: Date) {
        inner.armTimer(at: .distantPast)
    }
}

/// Breaks clause 4: a date armed while another is pending is ignored.
private struct IgnoringRearm: SystemEventsProviding {
    let inner = FakeSystemEvents()

    func events() -> AsyncStream<SystemEvent> {
        inner.events()
    }

    func armTimer(at date: Date) {
        if inner.pendingDate == nil {
            inner.armTimer(at: date)
        }
    }
}

/// Breaks clause 5: every stream ever opened is still observed for.
private final class NeverForgetting: SystemEventsProviding {
    let inner = FakeSystemEvents()
    private let opened = OSAllocatedUnfairLock(initialState: 0)

    var openedCount: Int {
        opened.withLock { $0 }
    }

    func events() -> AsyncStream<SystemEvent> {
        opened.withLock { $0 += 1 }
        return inner.events()
    }

    func armTimer(at date: Date) {
        inner.armTimer(at: date)
    }
}

/// Breaks clause 1: only the first stream opened hears anything.
private final class OnlyFirstStreamHears: SystemEventsProviding {
    let inner = FakeSystemEvents()
    let deaf = FakeSystemEvents()
    private let opened = OSAllocatedUnfairLock(initialState: 0)

    func events() -> AsyncStream<SystemEvent> {
        let isFirst = opened.withLock { count in
            count += 1
            return count == 1
        }
        return isFirst ? inner.events() : deaf.events()
    }

    func armTimer(at date: Date) {
        inner.armTimer(at: date)
    }
}

/// The fake half of the `SystemEventsProviding` contract suite: the same
/// ``SystemEventsProvidingContract`` that `AgentCronPlatformTests` runs against the real
/// adapter under `just test-local` runs here against ``FakeSystemEvents``, on every
/// `just test` and in CI, so the fake cannot drift from the port's promises (REQ-005).
@Suite("SystemEventsProviding contract, against the fake")
struct SystemEventsProvidingContractTests {
    @Test
    func `the fake keeps the contract`() async {
        let fake = FakeSystemEvents()
        await SystemEventsProvidingContract.check(
            fake,
            driver: .driving(fake, patience: .seconds(5)),
        )
        #expect(fake.openStreamCount == 0)
    }

    @Test
    func `a date armed one second ahead stays pending until the fake reaches it`() async {
        let fake = FakeSystemEvents()
        let recorder = SystemEventRecorder()
        let consumer = recorder.consume(fake.events())
        defer { consumer.cancel() }
        let due = FakeSystemEvents.defaultStart.addingTimeInterval(1)

        fake.armTimer(at: due)
        fake.advance(by: .milliseconds(999))
        #expect(fake.pendingDate == due)
        fake.advance(by: .milliseconds(1))
        await recorder.wait(untilCount: 1, patience: .seconds(5))

        #expect(recorder.events == [.fireDateReached])
        #expect(fake.pendingDate == nil)
    }

    @Test
    func `the fake records every date it was armed with, in order`() {
        let fake = FakeSystemEvents()
        let first = FakeSystemEvents.defaultStart.addingTimeInterval(60)
        let second = FakeSystemEvents.defaultStart.addingTimeInterval(120)

        fake.armTimer(at: first)
        fake.armTimer(at: second)

        #expect(fake.armedDates == [first, second])
        #expect(fake.pendingDate == second)
    }

    @Test
    func `a stream released before it is iterated stops being served`() {
        let fake = FakeSystemEvents()
        do {
            let stream = fake.events()
            #expect(fake.openStreamCount == 1)
            _ = stream
        }
        #expect(fake.openStreamCount == 0)
    }

    // The contract's own oracle: a provider that breaks a promise must be reported, or
    // `check` would pass anything, the real adapter included.

    @Test
    func `a timer that never fires is reported`() async {
        let provider = NeverFiring()
        let violations = await SystemEventsProvidingContract.violations(
            of: provider,
            driver: .driving(provider.inner, patience: missingAfter),
        )
        #expect(violations == [
            "once the armed date was reached: heard [], expected [fireDateReached]",
            "after arming a date already past: heard [], expected [fireDateReached]",
            "once the date armed last was reached: heard [], expected [fireDateReached]",
        ])
    }

    @Test
    func `a timer that fires before its date is reported`() async {
        let provider = FiringOnArm()
        let violations = await SystemEventsProvidingContract.violations(
            of: provider,
            driver: .driving(provider.inner, patience: missingAfter),
        )
        #expect(violations == [
            "half-way to the armed date: heard [fireDateReached, clockChanged], expected [clockChanged]",
            "once the armed date was reached: heard [], expected [fireDateReached]",
            "past the first of two armed dates: heard [fireDateReached, fireDateReached, clockChanged], "
                + "expected [clockChanged]",
            "once the date armed last was reached: heard [], expected [fireDateReached]",
        ])
    }

    @Test
    func `arming again without replacing the timer is reported`() async {
        let provider = IgnoringRearm()
        let violations = await SystemEventsProvidingContract.violations(
            of: provider,
            driver: .driving(provider.inner, patience: missingAfter),
        )
        #expect(violations == [
            "past the first of two armed dates: heard [fireDateReached, clockChanged], expected [clockChanged]",
            "once the date armed last was reached: heard [], expected [fireDateReached]",
        ])
    }

    @Test
    func `an OS event delivered as the wrong case is reported`() async {
        let fake = FakeSystemEvents()
        let driver = SystemEventsDriver(
            now: { fake.now },
            advance: { fake.advance(by: $0) },
            post: { fake.send($0 == .timeZoneChanged ? .clockChanged : $0) },
            openStreams: { fake.openStreamCount },
            patience: missingAfter,
        )
        let violations = await SystemEventsProvidingContract.violations(of: fake, driver: driver)
        #expect(violations == [
            "after each OS event happened once: heard [willSleep, didWake, clockChanged, clockChanged], "
                + "expected [willSleep, didWake, clockChanged, timeZoneChanged]",
        ])
    }

    @Test
    func `a stream still observed for after its consumer stopped is reported`() async {
        let provider = NeverForgetting()
        let driver = SystemEventsDriver(
            now: { provider.inner.now },
            advance: { provider.inner.advance(by: $0) },
            post: { provider.inner.send($0) },
            openStreams: { provider.openedCount },
            patience: missingAfter,
        )
        let violations = await SystemEventsProvidingContract.violations(
            of: provider,
            driver: driver,
        )
        #expect(violations == [
            "after the second stream's consumer stopped: 2 streams observed for, expected 1",
            "after the consumer stopped: 2 streams observed for, expected 0",
        ])
    }

    @Test
    func `a second stream that hears nothing is reported`() async {
        let provider = OnlyFirstStreamHears()
        let driver = SystemEventsDriver(
            now: { provider.inner.now },
            advance: { provider.inner.advance(by: $0) },
            post: { provider.inner.send($0) },
            openStreams: { provider.inner.openStreamCount + provider.deaf.openStreamCount },
            patience: missingAfter,
        )
        let violations = await SystemEventsProvidingContract.violations(
            of: provider,
            driver: driver,
        )
        #expect(violations == [
            "on the second of two open streams: heard [], expected [didWake]",
        ])
    }
}
