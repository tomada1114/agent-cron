import AgentCronCore
import Foundation
import Testing

/// What the contract cannot ask the port and has to be told: how time passes, how an OS
/// event is made to happen, and how many streams the implementation still serves.
///
/// For ``FakeSystemEvents`` all four answer from the fake itself; for
/// `WorkspaceSystemEvents` time is the real clock, an event is a notification posted on
/// the center the OS uses, and the stream count is the adapter's own.
package struct SystemEventsDriver: Sendable {
    /// The time a date to arm is measured from.
    package let now: @Sendable () -> Date
    /// Lets `duration` pass.
    package let advance: @Sendable (Duration) async -> Void
    /// Makes one of the OS events (every case but ``SystemEvent/fireDateReached``) happen.
    package let post: @Sendable (SystemEvent) async -> Void
    /// How many streams the implementation observes for right now.
    package let openStreams: @Sendable () -> Int
    /// How long an expected event is waited for before it is called missing. An event
    /// that arrives ends the wait at once, so this bounds only a failing run.
    package let patience: Duration

    /// Makes a driver.
    package init(
        now: @escaping @Sendable () -> Date,
        advance: @escaping @Sendable (Duration) async -> Void,
        post: @escaping @Sendable (SystemEvent) async -> Void,
        openStreams: @escaping @Sendable () -> Int,
        patience: Duration,
    ) {
        self.now = now
        self.advance = advance
        self.post = post
        self.openStreams = openStreams
        self.patience = patience
    }

    /// A driver for `fake`: its own clock, its own events, and its own stream count.
    package static func driving(_ fake: FakeSystemEvents, patience: Duration) -> Self {
        Self(
            now: { fake.now },
            advance: { fake.advance(by: $0) },
            post: { fake.send($0) },
            openStreams: { fake.openStreamCount },
            patience: patience,
        )
    }
}

/// One contract run: the stream it listens on, how far it has read, and what broke.
private struct Probe {
    let driver: SystemEventsDriver
    let recorder = SystemEventRecorder()
    private(set) var broken: [String] = []
    private var cursor = 0

    init(driver: SystemEventsDriver) {
        self.driver = driver
    }

    /// `[willSleep, didWake]` rather than the module-qualified names an array prints.
    private static func names(_ events: [SystemEvent]) -> String {
        "[" + events.map { "\($0)" }.joined(separator: ", ") + "]"
    }

    // MARK: - Clauses

    /// Clauses 1 and 2: each OS event arrives once, as its own case, in order.
    mutating func checkOSEvents() async {
        for event in SystemEventsProvidingContract.osEvents {
            await driver.post(event)
        }
        await expect(SystemEventsProvidingContract.osEvents, "after each OS event happened once")
    }

    /// Clause 3: not before the armed date, once when it is reached, and not again.
    mutating func checkTimerFiresOnceWhenReached(_ provider: some SystemEventsProviding) async {
        let step = SystemEventsProvidingContract.step
        let halfStep = SystemEventsProvidingContract.halfStep
        provider.armTimer(at: SystemEventsProvidingContract.date(driver.now(), plus: step))
        await driver.advance(halfStep)
        await expectOnlyMarker("half-way to the armed date")
        await driver.advance(halfStep)
        await expect([.fireDateReached], "once the armed date was reached")
        await driver.advance(step)
        await expectOnlyMarker("a step after the armed date fired")
    }

    /// Clause 3: a date already past fires without waiting.
    mutating func checkPastDateFiresPromptly(_ provider: some SystemEventsProviding) async {
        let step = SystemEventsProvidingContract.step
        provider.armTimer(at: SystemEventsProvidingContract.date(driver.now(), plus: .zero - step))
        await expect([.fireDateReached], "after arming a date already past")
    }

    /// Clause 4: arming again cancels the earlier date; only the later one fires, once.
    mutating func checkRearmingReplacesTheTimer(_ provider: some SystemEventsProviding) async {
        let step = SystemEventsProvidingContract.step
        let halfStep = SystemEventsProvidingContract.halfStep
        let start = driver.now()
        provider.armTimer(at: SystemEventsProvidingContract.date(start, plus: step))
        provider.armTimer(at: SystemEventsProvidingContract.date(start, plus: step + step))
        await driver.advance(step + halfStep)
        await expectOnlyMarker("past the first of two armed dates")
        await driver.advance(halfStep)
        await expect([.fireDateReached], "once the date armed last was reached")
        await driver.advance(step)
        await expectOnlyMarker("a step after the date armed last fired")
    }

    /// Clauses 1 and 5: a second stream hears what the first hears, and stops being
    /// served once its consumer stops.
    mutating func checkEveryOpenStreamHearsAnEvent(
        _ provider: some SystemEventsProviding,
        baseline: Int,
    ) async {
        let second = SystemEventRecorder()
        let consumer = second.consume(provider.events())
        expectOpenStreams(
            baseline + SystemEventsProvidingContract.streamsAtOnce,
            "after a second events()",
        )
        await driver.post(.didWake)
        await expect([.didWake], "on the first of two open streams")
        await second.wait(untilCount: 1, patience: driver.patience)
        if second.events != [.didWake] {
            broken.append(
                "on the second of two open streams: heard \(Self.names(second.events)), expected [didWake]",
            )
        }
        consumer.cancel()
        await consumer.value
        expectOpenStreams(baseline + 1, "after the second stream's consumer stopped")
    }

    // MARK: - Expectations

    mutating func expectOpenStreams(_ expected: Int, _ moment: String) {
        let actual = driver.openStreams()
        if actual != expected {
            broken.append("\(moment): \(actual) streams observed for, expected \(expected)")
        }
    }

    /// Posts the marker and waits until it is heard: anything heard ahead of it happened
    /// when nothing should have.
    private mutating func expectOnlyMarker(_ moment: String) async {
        let marker = SystemEventsProvidingContract.marker
        await driver.post(marker)
        let from = cursor
        await recorder.wait(patience: driver.patience) { heard in
            heard.dropFirst(from).contains(marker)
        }
        compare([marker], moment)
    }

    /// Waits for `expected.count` new events, then compares every event heard since the
    /// last expectation — so an extra one ahead of them is reported too.
    private mutating func expect(_ expected: [SystemEvent], _ moment: String) async {
        await recorder.wait(untilCount: cursor + expected.count, patience: driver.patience)
        compare(expected, moment)
    }

    private mutating func compare(_ expected: [SystemEvent], _ moment: String) {
        let heard = recorder.events
        let actual = Array(heard[min(cursor, heard.count)...])
        cursor = heard.count
        if actual != expected {
            broken
                .append("\(moment): heard \(Self.names(actual)), expected \(Self.names(expected))")
        }
    }
}

/// The promises ``AgentCronCore/SystemEventsProviding`` makes, checked against any
/// implementation of it (`.claude/rules/testing.md` › One Contract Suite per Port).
///
/// `AgentCronCoreTests` runs it against ``FakeSystemEvents`` on every `just test` and in
/// CI; `AgentCronPlatformTests` runs it against `WorkspaceSystemEvents` under
/// `.requiresLocalMachine` (`just test-local`), where the time is real and the events are
/// notifications posted in-process. Every clause is one the port's `///` states; a new
/// clause is stated there first.
///
/// An absence — no fire before the armed date, no second fire — is checked with a marker:
/// ``marker`` is posted, and nothing may arrive ahead of it.
package enum SystemEventsProvidingContract {
    /// The OS events, in the order the contract makes them happen (clause 2).
    package static let osEvents: [SystemEvent] = [
        .willSleep,
        .didWake,
        .clockChanged,
        .timeZoneChanged,
    ]

    /// The event posted to show that nothing else arrived before it.
    package static let marker = SystemEvent.clockChanged

    /// How far ahead the contract arms a timer: one second, as the issue's examples do,
    /// long enough that a real timer's latency cannot be mistaken for an early fire.
    package static let step = halfStep + halfStep

    /// Half of ``step``: where the contract looks for a fire that came too early.
    package static let halfStep = Duration.milliseconds(halfStepMilliseconds)

    /// How many streams the contract opens at once: two, so it can see that an event
    /// reaches both and that stopping one leaves the other served (clauses 1 and 5).
    package static let streamsAtOnce = 2

    private static let halfStepMilliseconds = 500

    /// A description of every broken promise, empty when `provider` keeps them all.
    ///
    /// Separate from ``check(_:driver:)`` so a test can hand it a provider that breaks a
    /// promise and see the contract notice — the proof it is not vacuous.
    package static func violations(
        of provider: some SystemEventsProviding,
        driver: SystemEventsDriver,
    ) async -> [String] {
        let baseline = driver.openStreams()
        var probe = Probe(driver: driver)
        let consumer = probe.recorder.consume(provider.events())
        probe.expectOpenStreams(baseline + 1, "after events()")

        await probe.checkOSEvents()
        await probe.checkTimerFiresOnceWhenReached(provider)
        await probe.checkPastDateFiresPromptly(provider)
        await probe.checkRearmingReplacesTheTimer(provider)
        await probe.checkEveryOpenStreamHearsAnEvent(provider, baseline: baseline)

        consumer.cancel()
        await consumer.value
        probe.expectOpenStreams(baseline, "after the consumer stopped")
        return probe.broken
    }

    /// Records an issue for every promise `provider` breaks.
    package static func check(
        _ provider: some SystemEventsProviding,
        driver: SystemEventsDriver,
    ) async {
        let broken = await violations(of: provider, driver: driver)
        #expect(
            broken.isEmpty,
            "\(type(of: provider)) breaks the SystemEventsProviding contract: \(broken)",
        )
    }

    /// `date` moved by `duration`, either way.
    static func date(_ date: Date, plus duration: Duration) -> Date {
        date.addingTimeInterval(duration / .seconds(1))
    }
}
