import Foundation
import Observation

/// Decides when the user is asked to allow notifications and which finished runs reach
/// ``RunNotifying`` (ADR-0007, requirements §3.5).
///
/// Authorization is asked for once, the first time it sees a job whose Notify setting is
/// not ``NotifyPolicy/never`` — at the first opt-in, never at launch. A finished run
/// that ``NotificationPolicy`` says notifies is posted only while the user allows it: the
/// state is read afresh first, since it can change in System Settings at any time, and a
/// denied or unanswered state posts nothing. ``authorizationState`` is what the Jobs
/// screen's "Notifications are off" note reads (docs/design/ux-guidelines.md › States).
///
/// Routing a click to the run in History is the composition root's, through
/// ``RunNotifying/setClickHandler(_:)``.
@MainActor
@Observable
public final class RunNotificationController {
    /// The user's answer as last read, or `nil` before anything has read it.
    public private(set) var authorizationState: NotificationAuthorizationState?

    @ObservationIgnored private var hasRequestedAuthorization = false

    private let notifier: any RunNotifying
    private let locale: Locale
    private let calendar: Calendar

    /// Creates a controller over `notifier` that writes in the user's language and tells
    /// times in their time zone, following either when it changes.
    ///
    /// Asks nothing and posts nothing until told something: construction has no side
    /// effect.
    public convenience init(notifier: any RunNotifying) {
        self.init(notifier: notifier, locale: .autoupdatingCurrent, calendar: .autoupdatingCurrent)
    }

    /// Creates a controller over `notifier` that writes in `locale` and tells times in
    /// `calendar`'s time zone. Tests pass fixed ones.
    public init(notifier: any RunNotifying, locale: Locale, calendar: Calendar) {
        self.notifier = notifier
        self.locale = locale
        self.calendar = calendar
    }

    /// Reads the user's answer again without asking — at launch, and whenever the app
    /// becomes active, since it may have changed in System Settings.
    public func refreshAuthorization() async {
        authorizationState = await notifier.authorizationState()
    }

    /// The saved jobs changed (or were loaded). The first time any of them notifies, the
    /// user is asked to allow notifications; never again after that.
    public func jobsChanged(_ jobs: [Job]) async {
        guard !hasRequestedAuthorization, jobs.contains(where: { $0.notify != .never }) else {
            return
        }
        hasRequestedAuthorization = true
        authorizationState = await notifier.requestAuthorizationIfNeeded()
        AppLog.notifications.info("notification authorization requested")
    }

    /// A run finished: posts its notification when its setting and outcome call for one
    /// and the user allows it.
    public func runFinished(_ run: Run) async {
        guard NotificationPolicy.shouldNotify(for: run),
              let content = NotificationPolicy.content(for: run, locale: locale, calendar: calendar)
        else {
            return
        }
        let state = await notifier.authorizationState()
        authorizationState = state
        guard state == .authorized else {
            let named = String(describing: state)
            AppLog.notifications.info("run not notified: authorization \(named, privacy: .public)")
            return
        }
        do {
            try await notifier.post(content)
        } catch {
            switch error {
            case .notAuthorized:
                AppLog.notifications.error("notification refused: not authorized")

            case let .systemFailure(code):
                AppLog.notifications.error("notification refused: error \(code, privacy: .public)")
            }
        }
    }
}
