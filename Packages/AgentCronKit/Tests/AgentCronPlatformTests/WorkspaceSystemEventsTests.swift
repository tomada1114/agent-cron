import AgentCronCore
import AgentCronPlatform
import AgentCronTestSupport
import AppKit
import Testing

/// `WorkspaceSystemEvents` against the real notification centers and a real timer — the one
/// thing a Core test with `FakeSystemEvents` cannot show: that each notification the OS
/// posts reaches the adapter on the center it is posted on and comes out as the right
/// ``SystemEvent`` (REQ-003, REQ-004), and that its timer fires on the real clock
/// (REQ-001, REQ-002).
///
/// Beside it sits the adapter half of the port's contract suite:
/// `SystemEventsProvidingContract`, the same function `AgentCronCoreTests` runs against the
/// fake on every `just test` (REQ-005).
///
/// Nothing here sleeps the Mac or sets its clock: each notification is posted in-process,
/// where only this process's observers hear it, which is also why the suite is serialized
/// — one test's post must not land on another test's stream. It needs no TCC grant — only
/// a real Mac's `NSWorkspace`, which is what a CI runner's session is not.
@Suite(
    "WorkspaceSystemEvents against the real notification centers",
    .requiresLocalMachine,
    .serialized,
)
struct WorkspaceSystemEventsTests {
    /// One notification the OS posts, and the center it posts it on.
    struct Posting {
        let event: SystemEvent
        let center: NotificationCenter
        let name: Notification.Name
    }

    /// How long an event the adapter should deliver is waited for before it is called
    /// missing; one that arrives ends the wait at once.
    static let patience = Duration.seconds(3)

    /// Where the OS posts each event, written out here rather than read from the adapter,
    /// so a wrong mapping there cannot agree with itself.
    static let postings = [
        Posting(
            event: .willSleep,
            center: NSWorkspace.shared.notificationCenter,
            name: NSWorkspace.willSleepNotification,
        ),
        Posting(
            event: .didWake,
            center: NSWorkspace.shared.notificationCenter,
            name: NSWorkspace.didWakeNotification,
        ),
        Posting(event: .clockChanged, center: .default, name: .NSSystemClockDidChange),
        Posting(event: .timeZoneChanged, center: .default, name: .NSSystemTimeZoneDidChange),
    ]

    /// Posts the notification the OS posts for `event`.
    static func post(_ event: SystemEvent) {
        guard let posting = postings.first(where: { $0.event == event }) else {
            Issue.record("the OS posts no notification for \(event)")
            return
        }
        posting.center.post(name: posting.name, object: nil)
    }

    @Test(arguments: [SystemEvent.willSleep, .didWake, .clockChanged, .timeZoneChanged])
    func `each notification the OS posts comes out as its event`(event: SystemEvent) async {
        let adapter = WorkspaceSystemEvents()
        let recorder = SystemEventRecorder()
        let consumer = recorder.consume(adapter.events())

        Self.post(event)
        await recorder.wait(untilCount: 1, patience: Self.patience)
        consumer.cancel()
        await consumer.value

        #expect(recorder.events == [event])
    }

    @Test
    func `a time-zone change posted on the default center is heard`() async {
        let adapter = WorkspaceSystemEvents()
        let recorder = SystemEventRecorder()
        let consumer = recorder.consume(adapter.events())

        NotificationCenter.default.post(name: .NSSystemTimeZoneDidChange, object: nil)
        await recorder.wait(untilCount: 1, patience: Self.patience)
        consumer.cancel()
        await consumer.value

        #expect(recorder.events == [.timeZoneChanged])
    }

    @Test
    func `sleep and wake are heard only on the workspace center`() async {
        let adapter = WorkspaceSystemEvents()
        let recorder = SystemEventRecorder()
        let consumer = recorder.consume(adapter.events())

        NotificationCenter.default.post(name: NSWorkspace.willSleepNotification, object: nil)
        NotificationCenter.default.post(name: NSWorkspace.didWakeNotification, object: nil)
        Self.post(.clockChanged)
        await recorder.wait(untilCount: 1, patience: Self.patience)
        consumer.cancel()
        await consumer.value

        #expect(recorder.events == [.clockChanged])
    }

    @Test
    func `a stream released before it is iterated stops being observed for`() {
        let adapter = WorkspaceSystemEvents()
        do {
            let stream = adapter.events()
            #expect(adapter.openStreamCount == 1)
            _ = stream
        }
        #expect(adapter.openStreamCount == 0)
        Self.post(.didWake)
    }

    @Test
    func `a stream ends when the adapter goes away`() async {
        var adapter: WorkspaceSystemEvents? = WorkspaceSystemEvents()
        let recorder = SystemEventRecorder()
        let consumer = recorder.consume(adapter?.events() ?? AsyncStream { $0.finish() })
        adapter?.armTimer(at: .now.addingTimeInterval(60))

        adapter = nil
        let ended = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await consumer.value
                return true
            }
            group.addTask {
                try? await Task.sleep(for: Self.patience)
                consumer.cancel()
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }

        #expect(ended, "the stream was still open \(Self.patience) after the adapter went away")
        #expect(recorder.events.isEmpty)
    }

    @Test
    func `keeps the SystemEventsProviding contract the fake is held to`() async {
        let adapter = WorkspaceSystemEvents()
        await SystemEventsProvidingContract.check(
            adapter,
            driver: SystemEventsDriver(
                now: { .now },
                advance: { try? await Task.sleep(for: $0) },
                post: { Self.post($0) },
                openStreams: { adapter.openStreamCount },
                patience: Self.patience,
            ),
        )
        #expect(adapter.openStreamCount == 0)
    }
}
