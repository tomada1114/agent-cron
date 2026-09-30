import AgentCronCore
import AgentCronTestSupport
import Foundation
import os
import Testing

// MARK: - Notifiers that each break one promise

/// Breaks clause 1: every read answers something different.
private final class Flickering: RunNotifying {
    let inner = FakeRunNotifier(authorization: .authorized, promptAnswer: .authorized)
    private let answersDenied = OSAllocatedUnfairLock(initialState: false)

    func authorizationState() -> NotificationAuthorizationState {
        let denied = answersDenied.withLock { denied in
            defer { denied.toggle() }
            return denied
        }
        return denied ? .denied : .authorized
    }

    func requestAuthorizationIfNeeded() -> NotificationAuthorizationState {
        inner.requestAuthorizationIfNeeded()
    }

    func post(_ content: NotificationContent) throws(NotificationPostError) {
        try inner.post(content)
    }

    func setClickHandler(_ handler: @escaping @Sendable (UUID) -> Void) {
        inner.setClickHandler(handler)
    }
}

/// Breaks clause 2: asking again re-prompts a user who already denied, who then allows.
private struct Reprompting: RunNotifying {
    let inner = FakeRunNotifier(authorization: .denied, promptAnswer: .authorized)

    func authorizationState() -> NotificationAuthorizationState {
        inner.authorizationState()
    }

    func requestAuthorizationIfNeeded() -> NotificationAuthorizationState {
        inner.userChangedAuthorization(to: .authorized)
        return inner.requestAuthorizationIfNeeded()
    }

    func post(_ content: NotificationContent) throws(NotificationPostError) {
        try inner.post(content)
    }

    func setClickHandler(_ handler: @escaping @Sendable (UUID) -> Void) {
        inner.setClickHandler(handler)
    }
}

/// Breaks clause 3: every post replaces the one before, as a shared identifier would.
private final class OneSlot: RunNotifying {
    let inner = FakeRunNotifier(authorization: .authorized, promptAnswer: .authorized)
    private let last = OSAllocatedUnfairLock<UUID?>(initialState: nil)

    var delivered: [UUID] {
        last.withLock { $0 }.map { [$0] } ?? []
    }

    func authorizationState() -> NotificationAuthorizationState {
        inner.authorizationState()
    }

    func requestAuthorizationIfNeeded() -> NotificationAuthorizationState {
        inner.requestAuthorizationIfNeeded()
    }

    func post(_ content: NotificationContent) throws(NotificationPostError) {
        try inner.post(content)
        last.withLock { $0 = content.runID }
    }

    func setClickHandler(_ handler: @escaping @Sendable (UUID) -> Void) {
        inner.setClickHandler(handler)
    }
}

/// Breaks clause 4: a post while denied is swallowed rather than refused.
private struct SilentWhileDenied: RunNotifying {
    let inner = FakeRunNotifier(authorization: .denied, promptAnswer: .denied)

    func authorizationState() -> NotificationAuthorizationState {
        inner.authorizationState()
    }

    func requestAuthorizationIfNeeded() -> NotificationAuthorizationState {
        inner.requestAuthorizationIfNeeded()
    }

    func post(_: NotificationContent) {
        // Nothing delivered, and nothing reported either.
    }

    func setClickHandler(_ handler: @escaping @Sendable (UUID) -> Void) {
        inner.setClickHandler(handler)
    }
}

/// Breaks clause 5: every handler ever set hears every click, with the wrong run.
private final class Broadcasting: RunNotifying {
    let inner = FakeRunNotifier(authorization: .authorized, promptAnswer: .authorized)
    private let handlers = OSAllocatedUnfairLock<[@Sendable (UUID) -> Void]>(initialState: [])

    func click(runID _: UUID) {
        for handler in handlers.withLock({ $0 }) {
            handler(NotificationFixture.otherRunID)
        }
    }

    func authorizationState() -> NotificationAuthorizationState {
        inner.authorizationState()
    }

    func requestAuthorizationIfNeeded() -> NotificationAuthorizationState {
        inner.requestAuthorizationIfNeeded()
    }

    func post(_ content: NotificationContent) throws(NotificationPostError) {
        try inner.post(content)
    }

    func setClickHandler(_ handler: @escaping @Sendable (UUID) -> Void) {
        handlers.withLock { $0.append(handler) }
    }
}

/// The fake half of the `RunNotifying` contract suite: the same ``RunNotifyingContract``
/// that `AgentCronPlatformTests` runs against the real adapter runs here against
/// ``FakeRunNotifier``, on every `just test` and in CI, so the fake cannot drift from the
/// port's promises — including REQ-006, a click reaching the handler with its run.
@Suite("RunNotifying contract, against the fake")
struct RunNotifyingContractTests {
    static let settings: [(NotificationAuthorizationState, NotificationAuthorizationState)] = [
        (.notDetermined, .authorized),
        (.notDetermined, .denied),
        (.authorized, .denied),
        (.denied, .authorized),
    ]

    @Test(arguments: settings)
    func `the fake keeps the contract`(
        state: NotificationAuthorizationState,
        answer: NotificationAuthorizationState,
    ) async {
        let notifier = FakeRunNotifier(authorization: state, promptAnswer: answer)
        await RunNotifyingContract.check(
            notifier,
            posting: RunNotifyingContract.sampleContents(),
            delivered: { notifier.posted.map(\.runID) },
            click: { notifier.click(runID: $0) },
        )
    }

    @Test
    func `a click reaches the handler with the clicked run, and nothing else does`() throws {
        let notifier = FakeRunNotifier(authorization: .authorized, promptAnswer: .authorized)
        let clicks = OSAllocatedUnfairLock<[UUID]>(initialState: [])
        notifier.setClickHandler { runID in clicks.withLock { $0.append(runID) } }
        let content = try #require(RunNotifyingContract.sampleContents().first)
        try notifier.post(content)
        notifier.click(runID: NotificationFixture.otherRunID)
        notifier.click(runID: content.runID)
        #expect(clicks.withLock { $0 } == [content.runID])
    }

    @Test
    func `every sample is a different run`() {
        let first = RunNotifyingContract.sampleContents().map(\.runID)
        let second = RunNotifyingContract.sampleContents().map(\.runID)
        #expect(Set(first + second).count == 4)
    }

    // The contract's own oracle: a notifier that breaks a promise must be reported, or
    // `check` would pass anything, the real adapter included.

    @Test
    func `a state that changes between reads is reported`() async {
        let notifier = Flickering()
        let violations = await RunNotifyingContract.violations(
            of: notifier,
            posting: [],
            delivered: { [] },
            click: { _ in /* never reached: no post is made */ },
        )
        #expect(violations.first == "authorizationState() answered authorized, then denied")
    }

    @Test
    func `asking a user who already answered again is reported`() async {
        let notifier = Reprompting()
        let violations = await RunNotifyingContract.violations(
            of: notifier,
            posting: [],
            delivered: { [] },
            click: { _ in /* never reached: no post is made */ },
        )
        #expect(violations ==
            ["requestAuthorizationIfNeeded() changed a settled denied to authorized"])
    }

    @Test
    func `a post that replaces the one before is reported`() async {
        let notifier = OneSlot()
        let contents = RunNotifyingContract.sampleContents()
        let violations = await RunNotifyingContract.violations(
            of: notifier,
            posting: contents,
            delivered: { notifier.delivered },
            click: { notifier.inner.click(runID: $0) },
        )
        #expect(violations.count == 1)
        #expect(violations.first?.hasPrefix("after posting 2, delivered [") == true)
    }

    @Test
    func `a post while denied that throws nothing is reported`() async {
        let notifier = SilentWhileDenied()
        let violations = await RunNotifyingContract.violations(
            of: notifier,
            posting: RunNotifyingContract.sampleContents(),
            delivered: { notifier.inner.posted.map(\.runID) },
            click: { notifier.inner.click(runID: $0) },
        )
        #expect(violations == [
            "post(_:) while not authorized did not throw",
            "post(_:) while not authorized did not throw",
        ])
    }

    @Test
    func `a click that reaches the wrong run, or a replaced handler, is reported`() async throws {
        let notifier = Broadcasting()
        let contents = RunNotifyingContract.sampleContents()
        let first = try #require(contents.first)
        let other = NotificationFixture.otherRunID
        let violations = await RunNotifyingContract.violations(
            of: notifier,
            posting: contents,
            delivered: { notifier.inner.posted.map(\.runID) },
            click: { notifier.click(runID: $0) },
        )
        #expect(violations == [
            "a click on \(first.runID) called the handler with [\(other)]",
            "a replaced click handler was called with [\(other)]",
        ])
    }

    @Test
    func `a post while authorized that the OS refuses is reported`() async {
        let notifier = FakeRunNotifier(failingPostsWith: [.systemFailure(code: 7)])
        let contents = RunNotifyingContract.sampleContents()
        let violations = await RunNotifyingContract.violations(
            of: notifier,
            posting: contents,
            delivered: { notifier.posted.map(\.runID) },
            click: { notifier.click(runID: $0) },
        )
        #expect(violations.first == "post(_:) while authorized threw systemFailure(code: 7)")
        // The refused post is also missing from Notification Center, and has nothing to click.
        #expect(violations.count == 3)
    }
}
