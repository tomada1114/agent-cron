import AgentCronCore
import Foundation
import os

/// The one fake of ``AgentCronCore/RunNotifying``, shared by every test target.
///
/// A fake, not a mock (`.claude/rules/testing.md` › Fakes, not mocks): a real conforming
/// implementation whose "user" answers the authorization prompt with the answer the test
/// handed it, whose Notification Center is an array, and which records what it was
/// asked. It keeps the promises the real center does — the prompt appears only while the
/// state is undetermined, a post while not authorized is refused, one notification per
/// run — and `RunNotifyingContract` holds it to them, as it holds
/// `UserNotificationPoster`.
///
/// Its state sits behind a lock rather than an `@unchecked Sendable`, so the fake is
/// `Sendable` the way the port requires whichever task a test calls it from.
package final class FakeRunNotifier: RunNotifying {
    private struct State {
        var authorization: NotificationAuthorizationState
        let promptAnswer: NotificationAuthorizationState
        var postFailures: [NotificationPostError]
        var stateReads = 0
        var authorizationRequests = 0
        var promptsShown = 0
        var postAttempts = 0
        var posted: [NotificationContent] = []
        var clickHandler: (@Sendable (UUID) -> Void)?
    }

    private let state: OSAllocatedUnfairLock<State>

    /// Every notification delivered so far, oldest first.
    package var posted: [NotificationContent] {
        state.withLock { $0.posted }
    }

    /// How many times ``post(_:)`` was called, refused posts included.
    package var postAttempts: Int {
        state.withLock { $0.postAttempts }
    }

    /// How many times ``authorizationState()`` was called.
    package var stateReads: Int {
        state.withLock { $0.stateReads }
    }

    /// How many times ``requestAuthorizationIfNeeded()`` was called.
    package var authorizationRequests: Int {
        state.withLock { $0.authorizationRequests }
    }

    /// How many times the user was shown the authorization prompt.
    package var promptsShown: Int {
        state.withLock { $0.promptsShown }
    }

    /// A notifier nobody has answered yet, whose user allows notifications when asked.
    package convenience init() {
        self.init(authorization: .notDetermined, promptAnswer: .authorized)
    }

    /// A notifier whose state is `authorization`, and whose user answers the prompt — if
    /// it is ever shown — with `promptAnswer`.
    package init(
        authorization: NotificationAuthorizationState,
        promptAnswer: NotificationAuthorizationState,
    ) {
        state = OSAllocatedUnfairLock(initialState: State(
            authorization: authorization,
            promptAnswer: promptAnswer,
            postFailures: [],
        ))
    }

    /// An authorized notifier whose first `failures.count` posts the OS refuses with these,
    /// in order; every later post is delivered.
    package init(failingPostsWith failures: [NotificationPostError]) {
        state = OSAllocatedUnfairLock(initialState: State(
            authorization: .authorized,
            promptAnswer: .authorized,
            postFailures: failures,
        ))
    }

    /// The user changed the app's permission in System Settings.
    package func userChangedAuthorization(to authorization: NotificationAuthorizationState) {
        state.withLock { $0.authorization = authorization }
    }

    /// The user clicked the delivered notification for `runID`. A run with no delivered
    /// notification has nothing to click, so nothing happens.
    package func click(runID: UUID) {
        let handler = state.withLock { current in
            current.posted.contains { $0.runID == runID } ? current.clickHandler : nil
        }
        handler?(runID)
    }

    package func authorizationState() -> NotificationAuthorizationState {
        state.withLock { current in
            current.stateReads += 1
            return current.authorization
        }
    }

    package func requestAuthorizationIfNeeded() -> NotificationAuthorizationState {
        state.withLock { current in
            current.authorizationRequests += 1
            if current.authorization == .notDetermined {
                current.promptsShown += 1
                current.authorization = current.promptAnswer
            }
            return current.authorization
        }
    }

    package func post(_ content: NotificationContent) throws(NotificationPostError) {
        let refusal: NotificationPostError? = state.withLock { current in
            current.postAttempts += 1
            guard current.authorization == .authorized else {
                return .notAuthorized
            }
            if !current.postFailures.isEmpty {
                return current.postFailures.removeFirst()
            }
            current.posted.removeAll { $0.runID == content.runID }
            current.posted.append(content)
            return nil
        }
        if let refusal {
            throw refusal
        }
    }

    package func setClickHandler(_ handler: @escaping @Sendable (UUID) -> Void) {
        state.withLock { $0.clickHandler = handler }
    }
}
