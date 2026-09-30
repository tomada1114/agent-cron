import AgentCronCore
import AgentCronPlatform
import AgentCronTestSupport
import Foundation
import Testing
import UserNotifications

/// The opt-in that lets a test reach the real notification center — and so show the
/// authorization prompt and post real notifications. Off by default, and never set by
/// `just test-local`: a prompt needs a person to answer it, and a click a person to make.
enum NotificationCenterTests {
    static let optInVariable = "RUN_NOTIFICATION_PROMPT_TESTS"

    /// How long a person has to click the notification the contract posts, in seconds.
    static let clickWindowSeconds = 120
}

/// The adapter half of the port's contract suite: `RunNotifyingContract`, the same
/// function `AgentCronCoreTests` runs against the fake, run against the real center — the
/// real prompt (answered by a person), real delivery, and REQ-006's real click.
///
/// Two conditions, both reported as a skip when unmet: the opt-in above, and a host that
/// is an app bundle, since the center ends any other process (see
/// `UserNotificationPosterTests`). `swift test`'s host is never one, so today this suite
/// documents the check the running app owes rather than running it.
@Suite(
    "UserNotificationPoster against the real notification center",
    .requiresLocalMachine,
    .enabled(
        if: LocalMachineTests.isOptedIn(to: NotificationCenterTests.optInVariable),
        "shows the notification prompt: set \(NotificationCenterTests.optInVariable)=1 to run it",
    ),
    .enabled(
        if: Bundle.main.bundleIdentifier != nil,
        "needs an app-bundle host: UNUserNotificationCenter ends a bundle-less process such as swift test's",
    ),
)
struct UserNotificationPosterCenterTests {
    @Test
    func `keeps the RunNotifying contract the fake is held to`() async {
        let contents = RunNotifyingContract.sampleContents()
        await RunNotifyingContract.check(
            UserNotificationPoster(),
            posting: contents,
            delivered: {
                let notifications = await UNUserNotificationCenter.current()
                    .deliveredNotifications()
                return notifications.compactMap { UUID(uuidString: $0.request.identifier) }
            },
            click: { runID in
                print(
                    "Click the notification \"RunNotifyingContract: the first of two notifications\".",
                )
                // A click removes the notification from Notification Center: wait for that.
                let deadline = ContinuousClock
                    .now + .seconds(NotificationCenterTests.clickWindowSeconds)
                while ContinuousClock.now < deadline {
                    let delivered = await UNUserNotificationCenter.current()
                        .deliveredNotifications()
                    if !delivered.contains(where: { $0.request.identifier == runID.uuidString }) {
                        return
                    }
                    try? await Task.sleep(for: .seconds(1))
                }
            },
        )
        let identifiers = contents.map(\.runID.uuidString)
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}
