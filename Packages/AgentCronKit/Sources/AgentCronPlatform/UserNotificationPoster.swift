import AgentCronCore
import Foundation
import os
import UserNotifications

/// The notification center's delegate: turns the user's click on a notification back
/// into the run ID ``UserNotificationPoster/request(for:)`` stored in it.
///
/// Separate from the poster so the translation can be exercised without a notification
/// center: `route(actionIdentifier:userInfo:)` is what the delegate callback calls, with
/// the plain values the OS's response carries.
package final class NotificationClickRouter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    /// The `userInfo` key a notification carries its run ID under.
    package static let runIDKey = "runID"

    /// How a notification is shown when it arrives while the app is active — the popover
    /// or the main window is open — so a finished run is never announced only silently.
    package static let foregroundPresentation: UNNotificationPresentationOptions = [.banner, .list]

    private let handler = OSAllocatedUnfairLock<(@Sendable (UUID) -> Void)?>(initialState: nil)

    /// Replaces the handler a click calls.
    package func setHandler(_ newHandler: @escaping @Sendable (UUID) -> Void) {
        handler.withLock { $0 = newHandler }
    }

    /// Calls the handler with the run a notification is about, when the user opened the
    /// notification — not when they dismissed it — and it names a run.
    package func route(actionIdentifier: String, userInfo: [AnyHashable: Any]) {
        guard actionIdentifier == UNNotificationDefaultActionIdentifier,
              let text = userInfo[Self.runIDKey] as? String,
              let runID = UUID(uuidString: text)
        else {
            return
        }
        handler.withLock { $0 }?(runID)
    }

    package func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: () -> Void,
    ) {
        route(
            actionIdentifier: response.actionIdentifier,
            userInfo: response.notification.request.content.userInfo,
        )
        completionHandler()
    }

    package func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: (UNNotificationPresentationOptions)
            -> Void,
    ) {
        completionHandler(Self.foregroundPresentation)
    }
}

/// The UserNotifications-backed adapter for ``AgentCronCore/RunNotifying`` (ADR-0007):
/// local notifications through the app's `UNUserNotificationCenter`.
///
/// Translation only: it reads and requests the authorization, turns a
/// ``AgentCronCore/NotificationContent`` into a notification request, and turns a click
/// back into the run ID. Whether a run notifies, what it says, and when to ask are Core's
/// (``AgentCronCore/NotificationPolicy``, ``AgentCronCore/RunNotificationController``),
/// which is why this file sits outside the coverage floor.
///
/// It touches the notification center only when a port method is called, never when it
/// is made: `UNUserNotificationCenter.current()` raises an Objective-C exception that ends
/// the process when the process is not an app bundle — `swift test`'s host is not — so
/// the translation is checked by `UserNotificationPosterTests` without a center, and the
/// center itself only in the running app.
public final class UserNotificationPoster: RunNotifying {
    /// What the app asks the user to allow: banners and the list, silently.
    static let authorizationOptions: UNAuthorizationOptions = [.alert]

    private let router = NotificationClickRouter()

    public init() {
        // Nothing to set up: the center is reached on the first port call.
    }

    /// Makes the one request that delivers `content`: identified by its run, so a
    /// second post for the same run replaces the first and a post for another run never
    /// does, and in a thread of its own, so Notification Center never groups two runs.
    package static func request(for content: NotificationContent) -> UNNotificationRequest {
        let notification = UNMutableNotificationContent()
        notification.title = content.title
        notification.subtitle = content.subtitle
        notification.body = content.body
        notification.threadIdentifier = content.runID.uuidString
        notification.userInfo = [NotificationClickRouter.runIDKey: content.runID.uuidString]
        return UNNotificationRequest(
            identifier: content.runID.uuidString,
            content: notification,
            trigger: nil,
        )
    }

    /// Translation only: which Core state a UserNotifications status means. Provisional
    /// authorization delivers, quietly, so it counts as authorized; a status added after
    /// this SDK counts as denied, so nothing is posted on a guess.
    package static func state(for status: UNAuthorizationStatus) -> NotificationAuthorizationState {
        switch status {
        case .authorized, .provisional:
            .authorized

        case .denied:
            .denied

        case .notDetermined:
            .notDetermined

        @unknown default:
            .denied
        }
    }

    public func authorizationState() async -> NotificationAuthorizationState {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return Self.state(for: settings.authorizationStatus)
    }

    /// Asks the system to prompt; it prompts only while the user has never answered, and
    /// otherwise answers at once with what they chose.
    public func requestAuthorizationIfNeeded() async -> NotificationAuthorizationState {
        let center = UNUserNotificationCenter.current()
        do {
            _ = try await center.requestAuthorization(options: Self.authorizationOptions)
        } catch {
            let code = (error as NSError).code
            AppLog.notifications
                .error("requestAuthorization failed: error \(code, privacy: .public)")
        }
        let settings = await center.notificationSettings()
        return Self.state(for: settings.authorizationStatus)
    }

    public func post(_ content: NotificationContent) async throws(NotificationPostError) {
        do {
            try await UNUserNotificationCenter.current().add(Self.request(for: content))
        } catch {
            throw NotificationPostError(userNotificationsError: error)
        }
    }

    /// Makes this poster's router the center's delegate, which the center holds weakly
    /// and this poster keeps alive.
    public func setClickHandler(_ handler: @escaping @Sendable (UUID) -> Void) {
        router.setHandler(handler)
        UNUserNotificationCenter.current().delegate = router
    }
}

extension NotificationPostError {
    /// Translation only: which Core case an error from `UNUserNotificationCenter.add`
    /// means. Only the code crosses — never the error's description or `userInfo`.
    init(userNotificationsError error: any Error) {
        if let refusal = error as? UNError, refusal.code == .notificationsNotAllowed {
            self = .notAuthorized
        } else {
            self = .systemFailure(code: (error as NSError).code)
        }
    }
}
