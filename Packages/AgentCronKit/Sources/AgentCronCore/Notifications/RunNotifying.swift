import Foundation

/// What one notification about one finished run says, already in the reader's language.
///
/// Plain strings rather than `LocalizedStringResource`s: ``NotificationPolicy`` resolves
/// them in Core, where the coverage floor sees the wording, so an adapter only copies
/// them into the OS's notification.
public struct NotificationContent: Sendable, Equatable {
    /// The run the notification is about; a click answers it (requirements §3.5).
    public let runID: UUID
    /// The job's name and how its run ended: "Nightly review timed out".
    public let title: String
    /// When the run was for: "· 22:00".
    public let subtitle: String
    /// The first line of the run's reason or result, at most
    /// ``NotificationPolicy/maximumBodyLength`` characters; empty when it has neither.
    public let body: String

    /// Makes the content of one run's notification.
    public init(runID: UUID, title: String, subtitle: String, body: String) {
        self.runID = runID
        self.title = title
        self.subtitle = subtitle
        self.body = body
    }
}

/// Whether the user lets the app post notifications — what the Jobs screen's
/// "Notifications are off" note is shown from (docs/design/ux-guidelines.md › States).
///
/// Cases are declared alphabetically (SwiftLint's `sorted_enum_cases`).
public enum NotificationAuthorizationState: Sendable, Equatable, CaseIterable {
    /// The user allowed notifications, quietly or not.
    case authorized
    /// The user refused them, or turned them off in System Settings.
    case denied
    /// The user has not been asked yet.
    case notDetermined
}

/// Why a notification could not be posted.
///
/// An enum so a caller can tell a permission it can explain from a failure it can only
/// log; the payload is the OS's error code, which carries no user data.
public enum NotificationPostError: Error, Equatable, Sendable {
    /// The user has not allowed notifications, so the OS refused this one.
    case notAuthorized
    /// The OS refused it for a reason the app has no recovery for; `code` is for logs.
    case systemFailure(code: Int)
}

/// A port: "tell the user about this finished run, and tell me when they click it"
/// (ADR-0007).
///
/// Core declares it, `AgentCronPlatform`'s `UserNotificationPoster` answers it with the
/// UserNotifications framework, tests substitute `FakeRunNotifier`, and `App/` — the
/// composition root — decides which one ``RunNotificationController`` gets. The port
/// decides nothing: whether a run notifies and what it says are ``NotificationPolicy``'s,
/// and when to ask for authorization and whether to post at all are
/// ``RunNotificationController``'s, where the coverage floor sees them.
///
/// The promises every implementation keeps — `RunNotifyingContract` in
/// `AgentCronTestSupport` checks them against the fake (`just test`) and the real adapter;
/// a new clause is stated here first, then added there:
///
/// 1. ``authorizationState()`` never asks the user anything; asked twice with nothing
///    changed in between, it answers the same state.
/// 2. ``requestAuthorizationIfNeeded()`` asks the user only while the state is
///    ``NotificationAuthorizationState/notDetermined``, and answers the state that
///    follows, which ``authorizationState()`` then answers too. Once the state is settled,
///    it asks nothing and answers that same state.
/// 3. While authorized, ``post(_:)`` delivers one notification per run: posting for two
///    different runs leaves two, never one replacing or absorbing the other.
/// 4. While not authorized, ``post(_:)`` throws ``NotificationPostError/notAuthorized``
///    and delivers nothing.
/// 5. When the user clicks a delivered notification, the handler most recently passed to
///    ``setClickHandler(_:)`` is called once with that notification's run ID.
public protocol RunNotifying: Sendable {
    /// The user's current answer, read without asking.
    func authorizationState() async -> NotificationAuthorizationState

    /// Shows the system's authorization prompt if the user has never answered it, and
    /// answers the state that follows. May wait for as long as the user takes to answer.
    func requestAuthorizationIfNeeded() async -> NotificationAuthorizationState

    /// Delivers `content` as one notification, identified by its run.
    func post(_ content: NotificationContent) async throws(NotificationPostError)

    /// Sets what a click on a delivered notification calls, with that notification's run
    /// ID, replacing any handler set before. The composition root calls it while the app
    /// launches, so a click that launched the app is not lost; the handler may be called
    /// on any thread.
    func setClickHandler(_ handler: @escaping @Sendable (UUID) -> Void)
}
